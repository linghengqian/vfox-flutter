local http = require("http")
local json = require("json")

local MARKER = "-ohos-"
local REPO = "CPF-Flutter/flutter_flutter"
local RELEASES_URL = "https://gitcode.com/api/v5/repos/%s/releases?per_page=100"
local ARCHIVE_URL = "https://raw.gitcode.com/%s/archive/refs/heads/%s.tar.gz"
local NOTE = "OpenHarmony"
local GIT_NAME = "vfox"
local GIT_EMAIL = "vfox@version-fox.local"

local PINS = {
    "bin/internal/engine.version",
    "bin/internal/engine.ohos.version",
    "bin/internal/engine.ohos.har.version"
}

local M = {}

function M.isOhosVersion(version)
    return type(version) == "string" and version:find(MARKER, 1, true) ~= nil
end

local function releases()
    local resp, err = http.get({ url = RELEASES_URL:format(REPO) })
    if err ~= nil or resp.status_code ~= 200 then
        return nil
    end
    local body = json.decode(resp.body)
    if type(body) ~= "table" then
        return nil
    end
    return body
end

function M.list()
    local result = {}
    for _, info in ipairs(releases() or {}) do
        local version = info.tag_name
        if M.isOhosVersion(version) then
            table.insert(result, {
                version = version,
                url = ARCHIVE_URL:format(REPO, version),
                key = version,
                note = NOTE
            })
        end
    end
    return result
end

function M.archive(version, requestedArch)
    if requestedArch ~= nil then
        return nil
    end
    for _, info in ipairs(releases() or {}) do
        if info.tag_name == version then
            return {
                version = version,
                url = ARCHIVE_URL:format(REPO, version),
                note = NOTE
            }
        end
    end
    return nil
end

local function quote(value)
    if RUNTIME.osType == "windows" then
        return '"' .. value:gsub('"', '""') .. '"'
    end
    return "'" .. value:gsub("'", "'\\''") .. "'"
end

local function run(command)
    local result = os.execute(command)
    return result == 0 or result == true
end

local function git(root, args)
    return run("git -C " .. quote(root) .. " " .. args)
end

function M.bootstrap(root, version)
    local pins = {}
    for _, pin in ipairs(PINS) do
        local file = io.open(root .. "/" .. pin, "r")
        if file ~= nil then
            file:close()
            table.insert(pins, pin)
        end
    end
    if #pins == 0 then
        error("no engine version pins found in " .. root)
    end
    if not git(root, "init -q") then
        error("failed to initialize git in " .. root .. " (is git installed?)")
    end
    if not git(root, "add -f " .. table.concat(pins, " ")) then
        error("failed to track engine version pins in " .. root)
    end
    if not git(root, "-c user.name=" .. GIT_NAME .. " -c user.email=" .. GIT_EMAIL ..
        " commit -q -m " .. quote("vfox install " .. version)) then
        error("failed to commit engine version pins in " .. root)
    end
    if not git(root, "tag -f " .. quote(version)) then
        error("failed to tag " .. version .. " in " .. root)
    end
end

return M

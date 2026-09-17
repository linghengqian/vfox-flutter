package.path = "./lib/?.lua;" .. package.path

local fixture, ohosFixture, requests, ohosStatus
package.preload.http = function()
    return { get = function(request)
        table.insert(requests, request.url)
        if request.url:find("gitcode.com", 1, true) then
            return { status_code = ohosStatus, body = "ohos" }, nil
        end
        return { status_code = 200, body = "official" }, nil
    end }
end
package.preload.json = function()
    return { decode = function(body)
        if body == "ohos" then return ohosFixture end
        return fixture
    end }
end
local ohos = require("ohos")

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function ohosRelease(tag)
    return { tag_name = tag }
end

local function officialRelease(arch)
    return {
        version = "3.44.0", dart_sdk_arch = arch, channel = "stable", hash = "stable",
        archive = "sdk/3.44.0-" .. arch .. ".zip",
        sha256 = "3.44.0:" .. arch, dart_sdk_version = "3.12.0"
    }
end

local function setup(osType, archType)
    requests, ohosStatus = {}, 200
    RUNTIME = { osType = osType, archType = archType }
    ohosFixture = {
        ohosRelease("3.41.10-ohos-1.0.0"),
        ohosRelease("3.41.10-ohos-0.0.1-canary1"),
        ohosRelease("3.35.8-ohos-1.0.3"),
        ohosRelease("3.27.5-ohos-1.0.7"),
        ohosRelease("3.22.1-ohos-1.0.1"),
        ohosRelease("3.7.12-ohos-1.0.6")
    }
    fixture = {
        current_release = { stable = "stable" },
        releases = { officialRelease("x64"), officialRelease("arm64") }
    }
    package.loaded.util = nil
    dofile("metadata.lua")
    dofile("hooks/available.lua")
    dofile("hooks/pre_install.lua")
end

local function postInstall(path, version)
    local commands = {}
    local originalExecute, originalOpen = os.execute, io.open
    os.execute = function(command)
        table.insert(commands, command)
        return 0
    end
    io.open = function(file)
        if file:find("engine.version", 1, true) or file:find("engine.ohos.version", 1, true) then
            return { close = function() end }
        end
        return nil
    end
    local ok, err = pcall(function()
        PLUGIN:PostInstall({ sdkInfo = { flutter = { path = path, version = version } } })
    end)
    os.execute, io.open = originalExecute, originalOpen
    return commands, ok, err
end

local tests = {}
tests[#tests + 1] = { "OpenHarmony builds sort after official releases and never win @latest", function()
    setup("darwin", "arm64")
    table.insert(ohosFixture, ohosRelease("3.99.0-ohos-1.0.0"))
    local versions = PLUGIN:Available({})
    equal(#versions, 9)
    equal(versions[1].version, "3.44.0-arm64")
    assert(not ohos.isOhosVersion(versions[1].version), versions[1].version)
    local lastOfficial
    for i = #versions, 1, -1 do
        if not ohos.isOhosVersion(versions[i].version) then
            lastOfficial = i
            break
        end
    end
    assert(lastOfficial ~= nil and lastOfficial < #versions)
    for i = lastOfficial + 1, #versions do
        assert(ohos.isOhosVersion(versions[i].version), versions[i].version)
    end
end }
tests[#tests + 1] = { "OpenHarmony versions install from gitcode.com without a checksum", function()
    setup("linux", "amd64")
    local result = PLUGIN:PreInstall({ version = "3.41.10-ohos-1.0.0" })
    assert(result)
    equal(result.version, "3.41.10-ohos-1.0.0")
    equal(result.url,
        "https://raw.gitcode.com/CPF-Flutter/flutter_flutter/archive/refs/heads/3.41.10-ohos-1.0.0.tar.gz")
    equal(result.sha256, nil)
    equal(result.note, "OpenHarmony")
    equal(#requests, 1)
    assert(requests[1]:find("gitcode.com", 1, true), requests[1])
    equal(PLUGIN:PreInstall({ version = "3.41.10-ohos-1.0.0-x64" }), nil)
    equal(PLUGIN:PreInstall({ version = "3.40.0-ohos-1.0.0" }), nil)
end }
tests[#tests + 1] = { "OpenHarmony installs bootstrap a git repository", function()
    setup("linux", "amd64")
    local commands = postInstall("/tmp/sdk", "3.41.10-ohos-1.0.0")
    local joined = table.concat(commands, "\n")
    for _, expected in ipairs({
        "git -C '/tmp/sdk' init -q",
        "git -C '/tmp/sdk' add -f bin/internal/engine.version bin/internal/engine.ohos.version",
        "-c user.name=vfox -c user.email=vfox@version-fox.local commit -q -m 'vfox install 3.41.10-ohos-1.0.0'",
        "git -C '/tmp/sdk' tag -f '3.41.10-ohos-1.0.0'"
    }) do
        assert(joined:find(expected, 1, true), "missing " .. expected .. "\n" .. joined)
    end
    local spaced = table.concat(postInstall("/tmp/oh my sdk", "3.41.10-ohos-1.0.0"), "\n")
    assert(spaced:find("git -C '/tmp/oh my sdk' init -q", 1, true), spaced)
end }
tests[#tests + 1] = { "official installs never touch git", function()
    for _, version in ipairs({ "3.44.0", "3.44.0-x64" }) do
        setup("linux", "amd64")
        local commands, ok = postInstall("/tmp/sdk", version)
        assert(ok, "official install should not fail: " .. version)
        equal(#commands, 0)
    end
end }
tests[#tests + 1] = { "official releases survive an unreachable gitcode.com", function()
    setup("linux", "amd64")
    ohosStatus = 503
    local versions = PLUGIN:Available({})
    equal(#versions, 2)
    equal(versions[1].version, "3.44.0-x64")
    equal(PLUGIN:PreInstall({ version = "3.41.10-ohos-1.0.0" }), nil)
end }

local failures = 0
for _, test in ipairs(tests) do
    local ok, err = pcall(test[2])
    if ok then
        print("PASS " .. test[1])
    else
        failures = failures + 1
        print("FAIL " .. test[1] .. ": " .. tostring(err))
    end
end
assert(failures == 0, tostring(failures) .. " test groups failed")

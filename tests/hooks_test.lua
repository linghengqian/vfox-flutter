package.path = "./lib/?.lua;" .. package.path

local fixture, requests, mirror, executed
local originalGetenv = os.getenv
os.getenv = function(name)
    if name == "FLUTTER_STORAGE_BASE_URL" then return mirror end
    return originalGetenv(name)
end
package.preload.http = function()
    return { get = function(request)
        table.insert(requests, request.url)
        return { status_code = 200, body = "fixture" }, nil
    end }
end
package.preload.json = function()
    return { decode = function() return fixture end }
end

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function release(version, arch, channel, hash)
    return {
        version = version, dart_sdk_arch = arch, channel = channel, hash = hash,
        archive = "sdk/" .. version .. "-" .. (arch or "legacy") .. ".zip",
        sha256 = version .. ":" .. (arch or "legacy"), dart_sdk_version = "3.12.0"
    }
end

local function setup(osType, archType, storage)
    mirror, requests, executed = storage, {}, {}
    RUNTIME = { osType = osType, archType = archType }
    -- Both architectures share the same Flutter commit. Put x64 first to catch
    -- channel selection that relies on the upstream array's order.
    fixture = {
        current_release = { stable = "stable", beta = "beta", dev = "dev" },
        base_url = "https://upstream.example/releases",
        releases = {
            release("3.44.0", "x64", "stable", "stable"),
            release("3.44.0", "arm64", "stable", "stable"),
            release("3.44.0-0.1.pre", "x64", "beta", "beta"),
            release("3.44.0-0.1.pre", "arm64", "beta", "beta"),
            release("3.43.0-0.1.pre", "x64", "dev", "dev"),
            release("3.43.0-0.1.pre", "arm64", "dev", "dev"),
            release("2.10.0", nil, "stable", "legacy")
        }
    }
    package.loaded.util = nil
    dofile("metadata.lua")
    dofile("hooks/available.lua")
    dofile("hooks/pre_install.lua")
end

local function installed(request, version, arch)
    local result = PLUGIN:PreInstall({ version = request })
    assert(result, "no package selected for " .. request)
    equal(result.version, version)
    assert(result.url:find("-" .. arch .. ".zip", 1, true), result.url)
    assert(result.sha256:find(":" .. arch, 1, true), result.sha256)
    return result
end

local tests = {}
tests[#tests + 1] = { "all variants are listed with native architecture first", function()
    for _, arch in ipairs({ "arm64", "amd64" }) do
        setup("darwin", arch)
        local versions = PLUGIN:Available({})
        equal(#versions, 7)
        equal(versions[1].version, "3.44.0-" .. (arch == "amd64" and "x64" or arch))
        local found = {}
        for _, version in ipairs(versions) do found[version.version] = true end
        assert(found["3.44.0-x64"] and found["3.44.0-arm64"] and found["2.10.0"])
        equal(versions[1].addition[1].version, "3.12.0")
    end
end }
tests[#tests + 1] = { "explicit architectures select matching archives", function()
    setup("darwin", "arm64")
    installed("3.44.0-x64", "3.44.0-x64", "x64")
    installed("3.44.0-arm64", "3.44.0-arm64", "arm64")
end }
tests[#tests + 1] = { "latest keeps the default architecture when a foreign build is newer", function()
    setup("darwin", "arm64")
    table.insert(fixture.releases, 1, release("3.45.0", "x64", "beta", "newer"))
    local versions = PLUGIN:Available({})
    equal(versions[1].version, "3.44.0-arm64")
    installed(versions[1].version, "3.44.0-arm64", "arm64")
end }
tests[#tests + 1] = { "existing version commands retain native selection and version names", function()
    for _, platform in ipairs({ "darwin", "linux", "windows" }) do
        for _, arch in ipairs({ "arm64", "amd64" }) do
            setup(platform, arch)
            installed("3.44.0", "3.44.0", arch == "amd64" and "x64" or arch)
        end
    end
end }
tests[#tests + 1] = { "channels use the native architecture even when hashes are shared", function()
    for _, arch in ipairs({ "arm64", "amd64" }) do
        setup("darwin", arch)
        for channel, version in pairs({ stable = "3.44.0", beta = "3.44.0-0.1.pre", dev = "3.43.0-0.1.pre" }) do
            installed(channel, version, arch == "amd64" and "x64" or arch)
            installed(channel .. "-x64", version .. "-x64", "x64")
            installed(channel .. "-arm64", version .. "-arm64", "arm64")
        end
    end
end }
tests[#tests + 1] = { "pre-release versions retain their full version strings", function()
    setup("darwin", "arm64")
    installed("3.44.0-0.1.pre", "3.44.0-0.1.pre", "arm64")
    installed("3.44.0-0.1.pre-x64", "3.44.0-0.1.pre-x64", "x64")
end }
tests[#tests + 1] = { "architecture suffixes do not change version ordering", function()
    setup("darwin", "arm64")
    equal(compare_versions("3.44.0-arm64", "3.44.0-x64"), 0)
    equal(compare_versions("3.44.0", "3.44.0-arm64"), 0)
    assert(compare_versions("3.44.0-arm64", "3.44.0-0.1.pre-x64") > 0)
    assert(compare_versions("3.44.0-0.2.pre-x64", "3.44.0-0.1.pre-arm64") > 0)
end }
tests[#tests + 1] = { "mirror is used for index and every architecture's archive", function()
    setup("darwin", "arm64", "https://mirror.example/flutter/")
    local result = installed("3.44.0-x64", "3.44.0-x64", "x64")
    equal(requests[1], "https://mirror.example/flutter/flutter_infra_release/releases/releases_macos.json")
    equal(result.url, "https://mirror.example/flutter/flutter_infra_release/releases/sdk/3.44.0-x64.zip")
end }
tests[#tests + 1] = { "legacy releases remain installable without inventing architecture variants", function()
    setup("darwin", "arm64")
    installed("2.10.0", "2.10.0", "legacy")
    equal(PLUGIN:PreInstall({ version = "2.10.0-arm64" }), nil)
end }
tests[#tests + 1] = { "missing architecture never falls back to an incompatible archive", function()
    setup("darwin", "arm64")
    fixture.releases = { release("3.44.0", "x64", "stable", "stable") }
    equal(PLUGIN:PreInstall({ version = "3.44.0" }), nil)
    equal(PLUGIN:PreInstall({ version = "stable" }), nil)
    equal(PLUGIN:PreInstall({ version = "stable-arm64" }), nil)
    installed("stable-x64", "3.44.0-x64", "x64")
end }

tests[#tests + 1] = { "the OpenHarmony checkout keeps one path separator per platform", function()
    local originalExecute = os.execute
    local originalOpen = io.open
    local originalGetenv = os.getenv
    local platforms = {
        { "linux", "/root" },
        { "darwin", "/Users/developer" },
        { "windows", "C:\\Users\\ContainerAdministrator" }
    }
    for _, platform in ipairs(platforms) do
        setup(platform[1], "amd64")
        fixture = { { tag_name = "3.41.10-ohos-1.0.0", target_commitish = "244a0e8abb" } }
        os.getenv = function(name)
            if name == "VFOX_HOME" then return platform[2] end
            return originalGetenv(name)
        end
        local opened = {}
        os.execute = function(command)
            table.insert(executed, command)
            return true
        end
        io.open = function(path)
            table.insert(opened, path)
            return { close = function() end }
        end
        local result = PLUGIN:PreInstall({ version = "3.41.10-ohos-1.0.0" })
        os.execute = originalExecute
        io.open = originalOpen
        os.getenv = originalGetenv
        assert(result, "no package selected for the OpenHarmony version")
        equal(#executed, 5)
        local join = platform[1] == "windows" and "\\" or "/"
        local parent = platform[2] .. join .. ".vfox" .. join .. "tmp"
        for _, command in ipairs(executed) do
            assert(command:find('\"', 1, true) == nil, "a quote leaked into: " .. command)
        end
        local mkdirIndex, initIndex
        for index, command in ipairs(executed) do
            if command:sub(1, 5) == "mkdir" and command:find(parent, 1, true) ~= nil then
                mkdirIndex = index
            end
            if command:find("git init", 1, true) ~= nil then
                initIndex = index
            end
        end
        assert(mkdirIndex ~= nil, "the work directory parent is never created")
        assert(initIndex ~= nil, "git init is never run")
        assert(mkdirIndex < initIndex, "the work directory parent is created after git init")
        for _, path in ipairs({ result.url, opened[1] }) do
            local forward = path:find("/", 1, true)
            local backslash = path:find("\\", 1, true)
            assert(forward == nil or backslash == nil, "mixed separators in " .. path)
            assert(path:find('\"', 1, true) == nil, "a quote leaked into " .. path)
            if platform[1] == "windows" then
                assert(backslash ~= nil, path)
            else
                assert(forward ~= nil, path)
            end
        end
    end
end }

tests[#tests + 1] = { "the OpenHarmony checkout closes the engine pin handle", function()
    local originalGetenv, originalOpen, originalExecute = os.getenv, io.open, os.execute
    local opened, closed = 0, 0
    setup("windows", "amd64")
    fixture = { { tag_name = "3.41.10-ohos-1.0.0", target_commitish = "244a0e8abb" } }
    os.getenv = function(name)
        if name == "VFOX_HOME" then return "C:\\Users\\ContainerAdministrator" end
        return originalGetenv(name)
    end
    os.execute = function() return true end
    io.open = function()
        opened = opened + 1
        return { close = function() closed = closed + 1 end }
    end
    local result = PLUGIN:PreInstall({ version = "3.41.10-ohos-1.0.0" })
    os.getenv, io.open, os.execute = originalGetenv, originalOpen, originalExecute
    assert(result, "no package selected for the OpenHarmony version")
    equal(opened, 1)
    equal(closed, 1)
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

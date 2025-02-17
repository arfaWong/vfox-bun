local http = require("http")
local json = require("json")
local util = {}

util.__index = util
local utilSingleton = setmetatable({}, util)
utilSingleton.SOURCE_URL = "https://api.github.com/repos/oven-sh/bun/releases"
utilSingleton.RELEASES ={}

function util:compare_versions(v1o, v2o)
    local v1 = v1o.version
    local v2 = v2o.version
    local v1_parts = {}
    for part in string.gmatch(v1, "[^.]+") do
        table.insert(v1_parts, tonumber(part))
    end

    local v2_parts = {}
    for part in string.gmatch(v2, "[^.]+") do
        table.insert(v2_parts, tonumber(part))
    end

    for i = 1, math.max(#v1_parts, #v2_parts) do
        local v1_part = v1_parts[i] or 0
        local v2_part = v2_parts[i] or 0
        if v1_part > v2_part then
            return true
        elseif v1_part < v2_part then
            return false
        end
    end

    return false
end

function util:getInfo()
    local platform = string.lower(RUNTIME.osType .. "-" .. RUNTIME.archType)
    local platform_map = {
        ["windows-amd64"] = "bun-windows-x64.zip",
        ["linux-amd64"] = "bun-linux-x64.zip",
        ["linux-arm64"] = "bun-linux-aarch64.zip",
        ["darwin-amd64"] = "bun-darwin-x64.zip",
        ["darwin-arm64"] = "bun-darwin-aarch64.zip"
    }
    local target = platform_map[platform] or ""
    local result = {}
    local resp, err = http.get({
        url = utilSingleton.SOURCE_URL
    })
    if err ~= nil then
        error("Failed to get information: " .. err)
    end
    if resp.status_code ~= 200 then
        error("Failed to get information: status_code =>" .. resp.status_code)
    end
    local releases = json.decode(resp.body)
    for _, release in ipairs(releases) do
        local version = release.tag_name:gsub("bun%-v", ""):gsub("^v", "")
        local assets = release.assets
        local url = ""
        for _, asset in ipairs(assets) do
            if asset.name == target then
                url = asset.browser_download_url
                break
            end
        end

        if url ~= "" then
            table.insert(result, {version = version, note = "" or ""})
            table.insert(utilSingleton.RELEASES, {version = version, url = url})
        end
    end
    table.sort(result, function(a, b)
        return util:compare_versions(a,b)
    end)
    return result
end

return utilSingleton

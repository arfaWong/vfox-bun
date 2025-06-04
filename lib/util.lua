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

-- 解析 GitHub API 响应中的 Link 头部，提取下一页 URL
function util:parseLinkHeader(linkHeader)
    if not linkHeader then
        return nil
    end

    -- 匹配 rel="next" 的链接
    local nextUrl = linkHeader:match('<([^>]+)>%s*;%s*rel="next"')
    return nextUrl
end

function util:getInfo()
    local platform = string.lower(RUNTIME.osType .. "-" .. RUNTIME.archType)

    -- 检测 CPU 是否支持 AVX2 指令集，如果不支持则添加 -baseline 后缀
    if platform == "darwin-amd64" then
        local handle = io.popen("sysctl -a | grep machdep.cpu | grep AVX2")
        local result = handle:read("*a")
        handle:close()
        if result == "" then
            platform = platform .. "-baseline"
        end
    elseif platform == "linux-amd64" then
        local handle = io.popen("cat /proc/cpuinfo | grep avx2")
        local result = handle:read("*a")
        handle:close()
        if result == "" then
            platform = platform .. "-baseline"
        end
    end

    local platform_map = {
        ["windows-amd64"] = "bun-windows-x64.zip",
        ["linux-amd64"] = "bun-linux-x64.zip",
        ["linux-amd64-baseline"] = "bun-linux-x64-baseline.zip",
        ["linux-arm64"] = "bun-linux-aarch64.zip",
        ["darwin-amd64"] = "bun-darwin-x64.zip",
        ["darwin-amd64-baseline"] = "bun-darwin-x64-baseline.zip",
        ["darwin-arm64"] = "bun-darwin-aarch64.zip"
    }
    local target = platform_map[platform] or ""
    local result = {}
    local allReleases = {}

    -- 获取所有分页的 releases 数据
    local currentUrl = utilSingleton.SOURCE_URL
    while currentUrl do
        local resp, err = http.get({
            url = currentUrl
        })
        if err ~= nil then
            error("Failed to get information: " .. err)
        end
        if resp.status_code ~= 200 then
            error("Failed to get information: status_code =>" .. resp.status_code)
        end

        local releases = json.decode(resp.body)
        -- 将当前页的 releases 添加到总列表中
        for _, release in ipairs(releases) do
            table.insert(allReleases, release)
        end

        -- 检查是否有下一页
        local linkHeader = resp.headers["Link"] or resp.headers["link"]
        currentUrl = util:parseLinkHeader(linkHeader)
    end

    -- 处理所有获取到的 releases
    for _, release in ipairs(allReleases) do
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

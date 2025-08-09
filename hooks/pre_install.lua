local util = require("util")
--- Returns some pre-installed information, such as version number, download address, local files, etc.
--- If checksum is provided, vfox will automatically check it for you.
--- @param ctx table
--- @field ctx.version string User-input version
--- @return table Version information
function PLUGIN:PreInstall(ctx)
    if #util.RELEASES == 0 then
        util:getInfo()
    end
    local releases = util.RELEASES
    table.sort(releases, function(a, b)
        return util:compare_versions(a, b)
    end)
    if ctx.version == "latest" then
        return releases[1]
    end
    for _, release in ipairs(releases) do
        if release.version == ctx.version then
            return release
        end
    end

    -- Match `major` OR `major.minor`
    local ctx_version_parts = util:split_versions(ctx.version)
    for _, release in ipairs(releases) do
        local release_version_parts = util:split_versions(release.version)
        if #ctx_version_parts == 1 then
            -- major
            if ctx_version_parts[1] == release_version_parts[1] then
                return release
            end
        elseif #ctx_version_parts == 2 then
            -- major.minor
            if ctx_version_parts[1] == release_version_parts[1] and ctx_version_parts[2] == release_version_parts[2] then
                return release
            end
        end
    end

    return {}
end

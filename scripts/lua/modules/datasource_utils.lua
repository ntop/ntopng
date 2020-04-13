--
-- (C) 2020 - ntop.org
--
local datasources_utils = {}

require ("lua_utils")
local json = require("dkjson")

local REDIS_BASE_KEY = "ntopng.datasources"

local function create_hash_source(alias, data_retention, origin)
    return ntop.md5(alias .. origin .. tostring(data_retention))
end

local function is_source_valid(alias, data_retention, scope, origin)

    if (isEmptyString(alias))           then return false end
    if (isEmptyString(scope))           then return false end
    if (isEmptyString(origin))          then return false end

    if (data_retention == nil)          then return false end
    if (data_retention <= 0)            then return false end

    if (scope ~= "public" and scope ~= "private") then return false end

    return true
end

local function alias_exists(alias)

    local sources = ntop.getHashAllCache(REDIS_BASE_KEY)
    if (sources == nil) then return false end

    for key, source_json in pairs(sources) do
        local source = json.decode(source_json)
        if (source.alias == alias) then
            return true
        end
    end

    return false
end

-- Check if the passed hash is saved inside redis.
-- @return True if the hash is contained, false otherwise
function datasources_utils.is_hash_valid(hash)

    local ds_json = ntop.getHashCache(REDIS_BASE_KEY, hash)
    if (isEmptyString(ds_json)) then return false end

    return true

end

-------------------------------------------------------------------------------
-- Create a new data source and save it to redis.
-- @param alias The human name for data source (not nil)
-- @param data_retention How many seconds the data is valid (not nil, > 0)
-- @param scope The data source scope, it can be public|private (not nil)
-- @param origin The lua script that will execute the data fetch (not nil)
-- @return The function returns `true` if the passed
--         arguments meet the precondition, otherwise `false`
-------------------------------------------------------------------------------
function datasources_utils.add_source(alias, data_retention, scope, origin)

    if (not is_source_valid(alias, data_retention, scope, origin)) then
        return false, "The provided arguments are not valid"
    end
    if (alias_exists(alias)) then
        return false, "There is a data source with that alias name"
    end

    local ds_hash = create_hash_source(alias, data_retention, origin)
    local new_datasource = {
        hash = ds_hash,
        alias = alias,
        data_retention = data_retention,
        scope = scope,
        origin = origin
    }

    ntop.setHashCache(REDIS_BASE_KEY, ds_hash, json.encode(new_datasource))
    return true, ds_hash
end

-------------------------------------------------------------------------------
-- Edit the data source
-- @param hash_source the hash of the source to be edit (not nil)
-- @param alias The human name for data source (not nil)
-- @param data_retention How many seconds the data is valid (not nil, > 0)
-- @param scope The data source scope, it can be public|private (not nil)
-- @param origin The lua script that will execute the data fetch (not nil)
-- @return True if the edit was successful, false otherwise
-------------------------------------------------------------------------------
function datasources_utils.edit_source(hash_source, alias, data_retention, scope, origin)

    if (isEmptyString(hash_source)) then
        return false
    end
    if (not is_source_valid(alias, data_retention, scope, origin)) then
        return false
    end

    local json_source = ntop.getHashCache(REDIS_BASE_KEY, hash_source)

    if (isEmptyString(json_source)) then
        return false
    end

    local source = json.decode(json_source)
    source.alias = alias
    source.data_retention = data_retention
    source.scope = scope
    source.origin = origin

    ntop.setHashCache(REDIS_BASE_KEY, hash_source, json.encode(source))

    return true
end

-------------------------------------------------------------------------------
-- Delete the data source from redis
-- @param hash_source The hash of the source to be removed (not nil)
-- @return True if the delete was successful, false otherwise
-------------------------------------------------------------------------------
function datasources_utils.delete_source(hash_source)

    if (isEmptyString(hash_source)) then
        return false
    end

    if (isEmptyString(ntop.getHashCache(REDIS_BASE_KEY, hash_source))) then
        return false
    end

    ntop.delHashCache(REDIS_BASE_KEY, hash_source)

    return true
end

-------------------------------------------------------------------------------
-- Get all datasources stored in redis
-- @return An array of datasources stored in redis, if no any sources was found
-- it returns an empty array
-------------------------------------------------------------------------------
function datasources_utils.get_all_sources()

    local sources = ntop.getHashAllCache(REDIS_BASE_KEY)
    if (sources == nil) then
        return {}
    end

    local all_sources = {}

    for _, json_source in pairs(sources) do
        all_sources[#all_sources + 1] = json.decode(json_source)
    end

    return all_sources
end

function datasources_utils.prepareResponse(datasets, timestamps, unit)

    local response = {}
    if (datasets == nil) then return {} end

    if (timestamps ~= nil) then
        response.timestamps = timestamps
    end
    if (unit ~= nil) then
        response.unit = unit
    end

    response.data = datasets

    return response
end

return datasources_utils
--
-- (C) 2021 - ntop.org
--

-- ##############################################

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/rest/v2/get/datasource/?.lua;" .. package.path

if ntop.isPro() then
   -- Add Pro datasources
   package.path = dirs.installdir .. "/pro/scripts/lua/rest/v2/get/datasource/?.lua;" .. package.path
end

local os_utils = require "os_utils"
require ("lua_utils")
local json = require("dkjson")

local REDIS_BASE_KEY = "ntopng.datasources"

local datasources_utils = {}

-- ##############################################

local function create_hash_source(alias, data_retention, origin)
    return ntop.md5(alias .. origin .. tostring(data_retention))
end

-- ##############################################

local function is_source_valid(alias, data_retention, scope, origin)

    if (isEmptyString(alias))           then return false end
    if (isEmptyString(scope))           then return false end
    if (isEmptyString(origin))          then return false end

    if (data_retention == nil)          then return false end
    if (data_retention <= 0)            then return false end

    if (scope ~= "public" and scope ~= "private") then return false end

    return true
end

-- ##############################################

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

-- ##############################################

-- Check if the passed hash is saved inside redis.
-- @return True if the hash is contained, false otherwise
function datasources_utils.is_hash_valid(hash)

    local ds_json = ntop.getHashCache(REDIS_BASE_KEY, hash)
    if (isEmptyString(ds_json)) then return false end

    return true

end

-- ##############################################

-------------------------------------------------------------------------------
-- Create a new data source and save it to redis.
-- @param alias The human name for data source (not nil)
-- @param data_retention How many seconds the data is valid (not nil, > 0)
-- @param scope The data source scope, it can be public|private (not nil)
-- @param origin The lua script that will execute the data fetch (not nil)
-- @return The function returns `true` if the passed
--         arguments meet the precondition, otherwise `false`
-------------------------------------------------------------------------------
function datasources_utils.add_source(alias, data_retention, scope, origin, schemas)

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
        origin = origin,
        schemas = schemas
    }

    ntop.setHashCache(REDIS_BASE_KEY, ds_hash, json.encode(new_datasource))
    return true, ds_hash
end

-- ##############################################

-------------------------------------------------------------------------------
-- Edit the data source
-- @param hash_source the hash of the source to be edit (not nil)
-- @param alias The human name for data source (not nil)
-- @param data_retention How many seconds the data is valid (not nil, > 0)
-- @param scope The data source scope, it can be public|private (not nil)
-- @param origin The lua script that will execute the data fetch (not nil)
-- @return True if the edit was successful, false otherwise
-------------------------------------------------------------------------------
function datasources_utils.edit_source(hash_source, alias, data_retention, scope, origin, schemas)

    if (isEmptyString(hash_source)) then
        return false, "The has cannot be empty!"
    end
    if (not is_source_valid(alias, data_retention, scope, origin)) then
        return false, "The sources are not valid!"
    end

    local json_source = ntop.getHashCache(REDIS_BASE_KEY, hash_source)

    if (isEmptyString(json_source)) then
        return false, "Datasource not found!"
    end

    local source = json.decode(json_source)
    source.alias = alias
    source.data_retention = data_retention
    source.scope = scope
    source.origin = origin
    source.schemas = schemas

    ntop.setHashCache(REDIS_BASE_KEY, hash_source, json.encode(source))

    return true
end

-- ##############################################

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

-- ##############################################

-------------------------------------------------------------------------------
-- Get a datasource stored in redis
-- @return The searched datasources stored in redis, or nil in case of error
-------------------------------------------------------------------------------
function datasources_utils.get(ds_hash)
   local ds = ntop.getHashCache(REDIS_BASE_KEY, ds_hash) or "{}"

   return(json.decode(ds))
end

-- ##############################################

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

-- ##############################################

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

-- ##############################################

-- A cache of all the available datasources, keyed by datasource_keys as found in datasource_keys.lua
local source_key_source_type_cache

-- ##############################################

local function cache_source_types(recache)
   if source_key_source_type_cache and not recache then
      -- Already cached
      return
   end

   -- Cache available datasource types
   source_key_source_type_cache = {}

   local datasources_dir = {os_utils.fixPath(dirs.installdir .. "/scripts/lua/rest/v2/get/datasource/")}

   if ntop.isPro() then
      datasources_dir[#datasources_dir + 1] = os_utils.fixPath(dirs.installdir .. "/pro/scripts/lua/rest/v2/get/datasource/")
   end

   -- The base datasources directory
   for _, datasource_path in ipairs(datasources_dir) do
      for datasource_dir in pairs(ntop.readdir(datasource_path)) do
	 -- Datasource sub-directories, e.g., /interface, /host, etc
	 local datasource_dir_path = os_utils.fixPath(string.format("%s/%s", datasource_path, datasource_dir))

	 if ntop.isdir(datasource_dir_path) then
	    for datasource_file in pairs(ntop.readdir(datasource_dir_path)) do
	       -- Load all sub-classes of datasources.lua (and exclude datasources.lua itself)

	       if datasource_file:match("%.lua$") then
		  -- Do the require and return the required module, if successful
		  local req = string.format("%s.%s", datasource_dir, datasource_file:gsub("%.lua$", ""))
		  local datasource = require(req)

		  if datasource then
		     source_key_source_type_cache[req] = datasource
		  end
	       end
	    end
	 end
      end
   end
end

-- ##############################################

-- @brief Returns all the available datasource types, i.e., all possible subclasses of datasource.lua in modules/datasources
function datasources_utils.get_all_source_types()
   local res = {}

   -- Build the cache, if not already built
   cache_source_types()

   for datasource_key, datasource in pairs(source_key_source_type_cache) do
      res[#res + 1] = datasource
   end

   return res
end

-- ##############################################

-- @brief Returns a datasource
-- @return The datasource that can be then instantiated with :new()
function datasources_utils.get_source_type_by_key(datasource_type)
   -- Build the cache (if not already built)
   cache_source_types()

   -- Return the cached datasource
   if datasource_type == "interface_packet_distro" then
      -- TODO: remove when datasources will be identified and requested with URIs
      return source_key_source_type_cache["interface.packet_distro"]
   end
end

-- ##############################################

return datasources_utils

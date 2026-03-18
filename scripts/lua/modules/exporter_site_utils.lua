--
-- (C) 2013-26 - ntop.org
--
-- Required modules for exporter site management
require "ntop_utils"
local json = require("dkjson")
local rest_utils = require "rest_utils"

-- Module definition - this module provides utilities for managing exporter sites
-- Exporter sites represent physical or logical locations of network flow exporters
local exporter_site_utils = {}

-- Redis cache keys configuration for persistent storage
local REDIS_HASH_NAME = "ntopng.prefs.exporter_sites"           -- Stores all exporter sites as hash: id -> JSON
local REDIS_COUNTER_KEY = "ntopng.prefs.exporter_sites_counter" -- Auto-increment counter for site IDs
local flow_dev_exporter_sites_key = "ntopng.prefs.flow_dev_exporter_sites" -- Maps flow device IPs to site IDs

-- Configuration limits for exporter sites
local MAX_DESCRIPTION_SIZE = 256  -- Maximum character length for site descriptions
local MAX_PROFILES_NUM = 1024     -- Maximum number of exporter sites allowed in the system

-- Default site configuration - system reserved site used when no site is assigned
-- This site cannot be modified or deleted and serves as a fallback
local DEFAULT_SITE = {
   id = "0",                      -- System reserved ID (always string "0")
   name = "Default",              -- Display name
   description = "",              -- Optional description
   longitude = 0,                 -- Geographic coordinates (0,0 by default)
   latitude = 0,
   reserved = true                -- Flag indicating this is a system-reserved site
}

-- ##############################################
-- Private Helper Functions
-- ##############################################

local iface_to_exporter = nil
local exporter_to_site  = nil
local exporter_to_name  = nil

--
-- Caches exporters information in memory
--
local function cache_exporters()
   if((iface_to_exporter == nil) and ntop.isPro()) then
	 package.path = dirs.installdir .. "/pro/scripts/lua/modules/?.lua;" .. package.path
	 local snmp_cached_dev = require "snmp_cached_dev"

	 iface_to_exporter = {}
	 exporter_to_site  = {}
	 exporter_to_name  = {}
	 
	 local ifstats = interface.getStats()
	 
	 for interface_id, probe_list in pairs(ifstats.probes or {}) do
	    for probe_ip, probe_info in pairsByKeys(probe_list or {}) do
	       for exporter_ip, exporter_info in pairsByKeys(probe_info.exporters or {}) do
		  local ifaces = snmp_cached_dev:get_interfaces(exporter_ip)
		  local system = snmp_cached_dev:get_system(exporter_ip)
		  local ret = exporter_site_utils.getFlowDevExporterSite(exporter_ip)
		  local site_name = ret.name

		  for _,v in pairs(ifaces.interfaces) do
		     if(v.ip_addr ~= nil) then
			for _,iface_ip in pairs(v.ip_addr) do
			   iface_to_exporter[iface_ip] = exporter_ip
			end
		     end
		  end

		  exporter_to_site[exporter_ip] = site_name
		  exporter_to_name[exporter_ip] = system.system.name or exporter_ip
	       end
	    end
	 end
   end
end


-- Validates all parameters for an exporter site before creation or modification
-- This comprehensive validation ensures data integrity and prevents duplicates
local function validate_site(name, description, latitude, longitude, existing_sites, ignore_name_duplication)
   -- Step 1: Validate site name
   if type(name) ~= "string" then
      return false, "Invalid name"
   end

   -- Check name length constraints (1-16 characters)
   if #name == 0 or #name > 16 then
      return false, "Invalid name, max characters: 16"
   end

    -- Validate name format (alphanumeric only)
    if not name:match("^[%w À-ÖØ-öø-ÿ]+$") then
        return false, "Invalid name, illegal character"
    end

   -- Convert to lowercase for case-insensitive duplicate checking
   local name_lower = name:lower()

   -- Step 2: Validate description
   if type(description) ~= "string" then
      return false, "Invalid description"
   end

   -- Check description length limit
   if #description > MAX_DESCRIPTION_SIZE then
      return false, "Invalid description, max characters: 256"
   end

   -- Step 3: Validate geographic coordinates
   if not tonumber(latitude) or not tonumber(longitude) then
      return false, "Invalid coordinates"
   end

   -- Convert to numbers for range validation
   latitude = tonumber(latitude)
   longitude = tonumber(longitude)

   -- Validate latitude range (-90 to 90 degrees)
   if latitude < -90 or latitude > 90 then
      return false, "Invalid latitude"
   end

   -- Validate longitude range (-180 to 180 degrees)
   if longitude < -180 or longitude > 180 then
      return false, "Invalid longitude"
   end

   -- Step 4: Check for duplicate site names (unless explicitly disabled for edits)
   if not ignore_name_duplication then
      for _, site in pairs(existing_sites) do
         if site.name:lower() == name_lower then
            return false, "Site " .. name .. " already exists"
         end
      end
   end

   -- All validation passed
   return true
end

-- ##############################################

-- Retrieves all exporter sites from Redis cache and prepares them for use
-- This function always includes the default site and merges it with user-defined sites
local function get_sites_from_cache()
   local sites_list = {}

   -- Always include the default site as ID "0"
   sites_list["0"] = exporter_site_utils.get_default_site()

   -- Retrieve all user-defined sites from Redis
   local current_defined_sites = ntop.getHashAllCache(REDIS_HASH_NAME) or {}

   -- Process each site JSON string from Redis
   for _, site in pairs(current_defined_sites) do
      -- Decode JSON string to Lua table
      local uncompressed_json = json.decode(site) or nil
      if uncompressed_json then
         -- Store site using its string ID as key for easy lookup
         sites_list[tostring(uncompressed_json.id)] = uncompressed_json
      end
   end

   return sites_list
end

-- ##############################################
-- Public API Functions
-- ##############################################

-- Returns the system default exporter site
-- Used as fallback when no site is assigned to a flow device
function exporter_site_utils.get_default_site()
   return DEFAULT_SITE
end

-- ##############################################

-- Associates a flow device (exporter) with a specific site
-- Creates or updates the mapping in Redis, or removes it if site_id is invalid
function exporter_site_utils.setFlowDevExporterSite(flowdev_ip, exporter_site_id)
   if (exporter_site_id) and tonumber(exporter_site_id) then
      -- Store the association: flow device IP -> site ID (as string)
      ntop.setHashCache(flow_dev_exporter_sites_key, flowdev_ip, tostring(exporter_site_id))
   else
      -- Remove association if site_id is nil or invalid
      ntop.delHashCache(flow_dev_exporter_sites_key, flowdev_ip)
   end

   -- Refresh the cached site ID in C++ for all interfaces
   local old_ifid = interface.getId()
   for _, ifname in pairs(interface.getIfNames() or {}) do
      interface.select(ifname)
      interface.refreshFlowDeviceSiteId(flowdev_ip)
   end
   interface.select(old_ifid)
end

-- ##############################################

-- Retrieves the exporter site associated with a specific flow device
-- Returns the default site if no association exists or if the association is invalid
function exporter_site_utils.getFlowDevExporterSite(flowdev_ip)
   -- Look up site ID for this flow device from Redis
   local exporter_site_id = ntop.getHashCache(flow_dev_exporter_sites_key, flowdev_ip)

   -- Get all available sites
   local exporter_sites = get_sites_from_cache()

   -- Check if we have a valid site ID for this device
   if not isEmptyString(exporter_site_id) then
      -- Look up the site by its ID
      local site = exporter_sites[tostring(exporter_site_id)]
      if site then
         return site  -- Return the associated site
      end
   end

   -- Fallback: return default site if no valid association exists
   return exporter_site_utils.get_default_site()
end

-- ##############################################

-- Returns all exporter sites as a sorted array for display purposes
-- Sites are sorted by ID in ascending order, with default site always included
function exporter_site_utils.getExporterSites()
   local exporter_sites = get_sites_from_cache()

   local result = {}

   -- Iterate through sites sorted by ID (ascending order)
   for id, site in pairsByKeys(exporter_sites, asc) do
      local record = {}
      record["id"] = tostring(site.id)        -- Ensure ID is string
      record["name"] = site.name              -- Site display name
      record["description"] = site.description -- Optional description
      record["latitude"] = site.latitude      -- Geographic coordinates
      record["longitude"] = site.longitude
      record["reserved"] = site.reserved      -- System-reserved flag

      -- Add to result array
      result[#result + 1] = record
   end

   return result
end

-- ##############################################

-- Edits an existing exporter site with new parameters
-- Performs validation and updates the site in Redis storage
function exporter_site_utils.editExporterSite(id, name, description, latitude, longitude)
   -- Get current sites for validation
   local existing_sites = get_sites_from_cache()

   -- Validate and normalize the site ID
   if id and tonumber(id) then
      id = tostring(id)  -- Convert to string for consistency
   else
      return rest_utils.consts.err.edit_exporter_site_failed, "Invalid ID"
   end

   -- Ensure the site exists
   if not existing_sites[id] then
      return rest_utils.consts.err.edit_exporter_site_failed, "Invalid Site"
   end

   local old_site = existing_sites[id]

   -- Handle empty coordinate values (default to 0)
   if isEmptyString(latitude) then
      latitude = 0
   end
   if isEmptyString(longitude) then
      longitude = 0
   end

   -- Skip duplicate name check if the name hasn't changed (edit vs rename scenario)
   local ignore_name_duplication = old_site.name == name

   -- Validate all input parameters
   local res, msg = validate_site(name, description, latitude, longitude, existing_sites, ignore_name_duplication)

   if res then
      -- Delete old entry first to ensure clean update
      ntop.delHashCache(REDIS_HASH_NAME, id)

      -- Create updated site object
      local site_json = {
         id = tostring(id),
         name = name,
         description = description,
         latitude = latitude,
         longitude = longitude
      }

      -- Store updated site in Redis
      ntop.setHashCache(REDIS_HASH_NAME, id, json.encode(site_json))
   else
      return rest_utils.consts.err.edit_exporter_site_failed, msg  -- Return validation error
   end

   local success_msg = "Site edited successfully"
   return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

-- Creates a new exporter site with auto-generated ID
-- Validates input, checks system limits, and stores in Redis
function exporter_site_utils.addExporterSite(name, description, latitude, longitude)
   -- Get current site counter from Redis (or default to 1)
   local current_count = tonumber(ntop.getCache(REDIS_COUNTER_KEY)) or 1

   -- Check system limit before proceeding
   if current_count + 1 > MAX_PROFILES_NUM then
      return rest_utils.consts.err.add_exporter_site_failed, 
               "Adding a site would exceed maximum limit (" .. MAX_PROFILES_NUM .. "). Current: " .. current_count
   end

   -- Get existing sites for validation
   local existing_sites = get_sites_from_cache()

   -- Handle empty coordinate values
   if isEmptyString(latitude) then
      latitude = 0
   end
   if isEmptyString(longitude) then
      longitude = 0
   end

   -- Validate all input parameters
   local res, msg = validate_site(name, description, latitude, longitude, existing_sites, false)

   if res then
      -- Generate new site ID (use current counter value)
      local site_id = tostring(current_count)

      -- Create site object
      local site_json = {
         id = site_id,
         name = name,
         description = description,
         latitude = latitude,
         longitude = longitude
      }

      -- Store new site in Redis
      ntop.setHashCache(REDIS_HASH_NAME, site_id, json.encode(site_json))

      -- Increment counter for next site
      ntop.setCache(REDIS_COUNTER_KEY, current_count + 1)
   else
      return rest_utils.consts.err.add_exporter_site_failed, msg  -- Return validation error
   end

   local success_msg = "Site added successfully"
   return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

-- Deletes an exporter site by ID
-- Note: Does not check if the site is currently in use by any flow devices
function exporter_site_utils.deleteExporterSite(id)
   -- Get current sites to verify existence
   local existing_sites = get_sites_from_cache()

   -- Validate and normalize ID
   if id then
      id = tostring(id)
   else
      return rest_utils.consts.err.delete_exporter_site_failed, "Invalid ID"
   end

   -- Check if site exists before deletion
   if existing_sites[id] then
      -- Remove site from Redis
      ntop.delHashCache(REDIS_HASH_NAME, id)
   else
      return rest_utils.consts.err.delete_exporter_site_failed, "Invalid Site"
   end

   local success_msg = "Site deleted successfully"
   return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

function exporter_site_utils.map_exporter_ip(exp_ip)
   local site

   if ntop.isPro() then
      cache_exporters()

      site = exporter_to_site[exp_ip]

      if(site == nil) then
	 for k,v in pairs(iface_to_exporter) do
	    if(v == exp_ip) then
	       exp_ip = k
	       site = exporter_to_site(k)
	       break
	    end
	 end
      end
   else
      site = DEFAULT_SITE.name
   end

   return exp_ip, site, exporter_to_name[exp_ip] or exp_ip
end

-- ##############################################

function exporter_site_utils.map_host_to_exporter_ip(host_ip)
   local site
   local exp_ip
   
   if ntop.isPro() then
      cache_exporters()

      -- tprint(iface_to_exporter)
      exp_ip = iface_to_exporter[host_ip]

      if(exp_ip ~= nil) then
	 site = exporter_to_site[exp_ip]
	 
	 if(site == nil) then
	    for k,v in pairs(iface_to_exporter) do
	       if(v == exp_ip) then
		  exp_ip = k
		  site = exporter_to_site(k)
		  break
	       end
	    end
	 end
      else
	 exp_ip = host_ip
      end
   else
      site = DEFAULT_SITE.name
   end

   return exp_ip, site, exporter_to_name[exp_ip] or exp_ip
end

-- ##############################################

-- Export the module for use in other Lua files
return exporter_site_utils

--
-- (C) 2013-26 - ntop.org
--
-- Required modules for site management
require("ntop_utils")
local json = require("dkjson")
local rest_utils = require("rest_utils")

-- Module definition - this module provides utilities for managing sites
local site_utils = {}

-- Redis cache keys configuration for persistent storage
local REDIS_HASH_NAME = "ntopng.prefs.sites" -- Stores all sites as hash: id -> JSON
local REDIS_NETWORKS_SITES_KEY = "ntopng.prefs.networks.sites" -- Stores all sites as hash: id -> JSON
local REDIS_COUNTER_KEY = "ntopng.prefs.sites_counter" -- Auto-increment counter for site IDs

-- Configuration limits for sites
local MAX_DESCRIPTION_SIZE = 256 -- Maximum character length for site descriptions
local MAX_PROFILES_NUM = 1024 -- Maximum number of sites allowed in the system

-- ##############################################
-- Site field schema
local SITE_SCHEMA = {
	{ key = "id", default = "0", exported = false },
	{ key = "name", input_key = "site_name", default = "", exported = true },
	{ key = "description", input_key = "site_description", default = "", exported = true },
	{ key = "latitude", default = 0, exported = true },
	{ key = "longitude", default = 0, exported = true },
	{ key = "parent", input_key = "site_parent", default = nil, exported = false },
	{ key = "reserved", default = false, exported = false },
}

-- Default site configuration - system reserved site used when no site is assigned.
local DEFAULT_SITE = {}
for _, f in ipairs(SITE_SCHEMA) do
	DEFAULT_SITE[f.key] = f.default
end
DEFAULT_SITE.name = "Default"
DEFAULT_SITE.reserved = true 

-- ##############################################
-- Private Helper Functions
-- ##############################################

-- Validates all parameters for a Site before creation or modification
-- This comprehensive validation ensures data integrity and prevents duplicates
local function validate_site(site, existing_sites, ignore_name_duplication)
	if not site then
		return false, "Invalid data"
	end

	-- Step 1: Validate site name
	if type(site.site_name) ~= "string" then
		return false, "Invalid name"
	end

	-- Check name length constraints (1-16 characters)
	if #site.site_name == 0 or #site.site_name > 32 then
		return false, "Invalid name, max characters: 32"
	end

	-- Validate name format (alphanumeric only)
	if not site.site_name:match("^[%w À-ÖØ-öø-ÿ]+$") then
		return false, "Invalid name, illegal character"
	end

	-- Convert to lowercase for case-insensitive duplicate checking
	local name_lower = site.site_name:lower()

	-- Step 2: Validate description
	if type(site.site_description) ~= "string" then
		return false, "Invalid description"
	end

	-- Check description length limit
	if #site.site_description > MAX_DESCRIPTION_SIZE then
		return false, "Invalid description, max characters: 256"
	end

	-- Step 4: Validate geographic coordinates
	if not tonumber(site.latitude) or not tonumber(site.longitude) then
		return false, "Invalid coordinates"
	end

	-- Convert to numbers for range validation
	site.latitude = tonumber(site.latitude)
	site.longitude = tonumber(site.longitude)

	-- Validate latitude range (-90 to 90 degrees)
	if site.latitude < -90 or site.latitude > 90 then
		return false, "Invalid latitude"
	end

	-- Validate longitude range (-180 to 180 degrees)
	if site.longitude < -180 or site.longitude > 180 then
		return false, "Invalid longitude"
	end

   -- A parent of 0 (or empty) is the "no parent" sentinel: normalize it to nil.
   if isEmptyString(site.site_parent) or tostring(site.site_parent) == "0" then
      site.site_parent = nil
   elseif tonumber(site.site_parent) then
      -- A real parent must reference an existing, non-default site.
      -- getSiteInfo() falls back to the Default site (id "0") when the id is
      -- unknown, so a "0" result here means the parent does not exist.
      local parent = site_utils.getSiteInfo(site.site_parent)
      if parent.id == "0" then
         return false, "Invalid Parent Site selected"
      end
      -- Store the parent in the same canonical (string) form as the site ids,
      -- so lookups by id stay consistent (e.g. in the table parent column).
      site.site_parent = parent.id
   else
      return false, "Invalid Parent Site selected"
   end

	-- Step 5: Check for duplicate site names (unless explicitly disabled for edits)
	if not ignore_name_duplication then
		for _, site in pairs(existing_sites) do
			if site.name:lower() == name_lower then
				return false, "Site " .. site.name .. " already exists"
			end
		end
	end

	-- All validation passed
	return true
end

-- ##############################################

local sites_list_cache = nil

-- Retrieves all Sites from Redis cache and prepares them for use
-- This function always includes the default site and merges it with user-defined sites
local function get_sites_from_cache()
	if sites_list_cache == nil then
		local sites_list = {}

		-- Always include the default site as ID "0"
		sites_list["0"] = site_utils.get_default_site()

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

		sites_list_cache = sites_list
		return sites_list
	else
		return sites_list_cache
	end
end

-- ##############################################

-- Builds the persisted (Redis) representation of a Site from an input table
-- (as accepted by addSite()/editSite()) using SITE_SCHEMA. The id is supplied
-- explicitly by the caller, since it is generated/looked-up separately. Any
-- new attribute added to SITE_SCHEMA is persisted here automatically.
local function build_site_record(input, id)
	local record = { id = tostring(id) }

	for _, f in ipairs(SITE_SCHEMA) do
		if f.key ~= "id" then
			local v = input[f.input_key or f.key]
			if v == nil then
				v = f.default
			end
			record[f.key] = v
		end
	end

	return record
end

-- ##############################################
-- Public API Functions
-- ##############################################

-- Returns the system default Site
-- Used as fallback when no site is assigned to a flow device
function site_utils.get_default_site()
	return DEFAULT_SITE
end

-- ##############################################

-- Returns the ordered list of attribute *keys* that take part in import/export
-- (i.e. the SITE_SCHEMA entries flagged as exported). Used to drive the CSV
-- header/column order and the backup export.
function site_utils.get_exported_fields()
	local fields = {}
	for _, f in ipairs(SITE_SCHEMA) do
		if f.exported then
			fields[#fields + 1] = f.key
		end
	end
	return fields
end

-- ##############################################

-- Returns the ordered list of exported attributes as descriptors:
--   { key = <stored name>, input_key = <addSite/editSite input name>, default = <fallback> }
-- Import code uses this to map CSV/backup columns onto addSite() inputs
-- generically, with no hardcoded field names.
function site_utils.get_exported_schema()
	local schema = {}
	for _, f in ipairs(SITE_SCHEMA) do
		if f.exported then
			schema[#schema + 1] = {
				key = f.key,
				input_key = f.input_key or f.key,
				default = f.default,
			}
		end
	end
	return schema
end

-- ##############################################

-- Returns all Sites as a sorted array for display purposes
-- Sites are sorted by ID in ascending order, with default site always included
function site_utils.getSites()
	local sites = get_sites_from_cache()

	local result = {}

	-- Iterate through sites sorted by ID (ascending order)
	for id, site in pairsByKeys(sites, asc) do
		-- Build the record generically from SITE_SCHEMA so that any attribute
		-- added to the schema is automatically returned here as well.
		local record = {}
		for _, f in ipairs(SITE_SCHEMA) do
			record[f.key] = site[f.key]
		end
		record["id"] = tostring(site.id) -- Ensure ID is always a string

		-- Add to result array
		result[#result + 1] = record
	end

	return result
end

-- ##############################################

-- Edits an existing Site with new parameters
-- Performs validation and updates the site in Redis storage
function site_utils.editSite(site)
	-- Get current sites for validation
	local existing_sites = get_sites_from_cache()

	-- Validate and normalize the site ID
	if site.site_id and tonumber(site.site_id) then
		site.site_id = tostring(site.site_id) -- Convert to string for consistency
	else
		return rest_utils.consts.err.edit_site_failed, "Invalid ID"
	end

	-- Ensure the site exists
	if not existing_sites[site.site_id] then
		return rest_utils.consts.err.edit_site_failed, "Invalid Site"
	end

	local old_site = existing_sites[site.site_id]

	-- A site cannot be its own parent
	if site.site_parent and tostring(site.site_parent) == tostring(site.site_id) then
		return rest_utils.consts.err.edit_site_failed, "A site cannot be its own parent"
	end

	-- Handle empty coordinate values (default to 0)
	if isEmptyString(site.latitude) then
		site.latitude = 0
	end
	if isEmptyString(site.longitude) then
		site.longitude = 0
	end

	-- Skip duplicate name check if the name hasn't changed (edit vs rename scenario)
	local ignore_name_duplication = old_site.name == site.site_name

	-- Validate all input parameters
	local res, msg = validate_site(site, existing_sites, ignore_name_duplication)

	if res then
		-- Delete old entry first to ensure clean update
		ntop.delHashCache(REDIS_HASH_NAME, site.site_id)

		-- Create the updated site object generically from SITE_SCHEMA
		local site_json = build_site_record(site, site.site_id)

		-- Store updated site in Redis
		ntop.setHashCache(REDIS_HASH_NAME, site.site_id, json.encode(site_json))

		-- Invalidate the in-memory cache so subsequent reads see the update
		sites_list_cache = nil
	else
		return rest_utils.consts.err.edit_site_failed, msg -- Return validation error
	end

	local success_msg = "Site edited successfully"
	return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

-- Creates a new Site with auto-generated ID
-- Validates input, checks system limits, and stores in Redis
function site_utils.addSite(site)
	-- Get current site counter from Redis (or default to 1)
	local current_count = tonumber(ntop.getCache(REDIS_COUNTER_KEY)) or 1

	-- Check system limit before proceeding
	if current_count + 1 > MAX_PROFILES_NUM then
		return rest_utils.consts.err.add_site_failed,
			"Adding a site would exceed maximum limit (" .. MAX_PROFILES_NUM .. "). Current: " .. current_count
	end

	-- Get existing sites for validation
	local existing_sites = get_sites_from_cache()

	-- Handle empty coordinate values
	if isEmptyString(site.latitude) then
		site.latitude = 0
	end
	if isEmptyString(site.longitude) then
		site.longitude = 0
	end

	-- Validate all input parameters
	local res, msg = validate_site(site, existing_sites, false)

	if res then
		-- Generate new site ID (use current counter value)
		local site_id = tostring(current_count)

		-- Create the site object generically from SITE_SCHEMA
		local site_json = build_site_record(site, site_id)

		-- Store new site in Redis
		ntop.setHashCache(REDIS_HASH_NAME, site_id, json.encode(site_json))

		-- Increment counter for next site
		ntop.setCache(REDIS_COUNTER_KEY, current_count + 1)

		-- Invalidate the in-memory cache so subsequent reads (and the
		-- duplicate check of the next addSite in a batch) see this site
		sites_list_cache = nil
	else
		return rest_utils.consts.err.add_site_failed, msg -- Return validation error
	end

	local success_msg = "Site added successfully"
	return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

-- Deletes an Site by ID
-- Note: Does not check if the site is currently in use by any flow devices
function site_utils.deleteSite(id)
	-- Get current sites to verify existence
	local existing_sites = get_sites_from_cache()

	-- Validate and normalize ID
	if id then
		id = tostring(id)
	else
		return rest_utils.consts.err.delete_site_failed, "Invalid ID"
	end

	-- Check if site exists before deletion
	if existing_sites[id] then
		-- Remove site from Redis
		ntop.delHashCache(REDIS_HASH_NAME, id)

		-- Invalidate the in-memory cache so subsequent reads see the removal
		sites_list_cache = nil
	else
		return rest_utils.consts.err.delete_site_failed, "Invalid Site"
	end

	local success_msg = "Site deleted successfully"
	return rest_utils.consts.success.ok, success_msg
end

-- ##############################################

function site_utils.mapHostToSite(ip)
	if isEmptyString(ip) then
		return site_utils.get_default_site()
	end
	local network_id = interface.getIPNetworkId(ip)
	return site_utils.getNetworkSite(network_id)
end

-- ##############################################

function site_utils.getSiteInfo(site_id)
	local sites = site_utils.getSites()
	local default_site = site_utils.get_default_site()

	if isEmptyString(site_id) or (site_id == default_site.id) then
		return default_site
	end

	-- Check the existence of the site, otherwise skip it
	for _, site in pairsByKeys(sites, asc) do
		if tostring(site_id) == site.id then
			return site
		end
	end

	return default_site
end

-- ##############################################

function site_utils.getNetworkSite(network_id)
	if not tonumber(network_id) or not interface.getNetworkStats(tonumber(network_id)) then
		-- Not a network, return
		return site_utils.get_default_site()
	end

	local site = ntop.getHashCache(REDIS_NETWORKS_SITES_KEY, tostring(network_id))

	return site_utils.getSiteInfo(site)
end

-- ##############################################

function site_utils.mapNetworkToSite(network_id, site_id)
	-- Given a network_id, maps the network_id to the site_id
	local sites = site_utils.getSites()
	local skip = true

	if not interface.getNetworkStats(tonumber(network_id)) then
		-- Not a network, return
		return site_utils.get_default_site()
	end

	-- Check the existence of the site, otherwise skip it
	for _, site in pairsByKeys(sites, asc) do
		if tostring(site_id) == site.id then
			-- OK, site found
			skip = false
			break
		end
	end

	-- Site found, update the network + site key
	if not skip then
		ntop.setHashCache(REDIS_NETWORKS_SITES_KEY, tostring(network_id), tostring(site_id))
	end
end

-- ##############################################

function site_utils.getAllNetworksToSite()
	require("label_utils")
	local associations = ntop.getHashAllCache(REDIS_NETWORKS_SITES_KEY) or {}
	local active_networks = interface.getNetworksStats() or {}
	local list = {}

	for net_cidr, info in pairsByKeys(active_networks) do
		local site_id_associated = associations[tostring(info.network_id)]
		if not site_id_associated then
			site_id_associated = tostring(DEFAULT_SITE.id)
		end
		if not list[site_id_associated] then
			list[site_id_associated] = {}
		end

		list[site_id_associated][#list[site_id_associated] + 1] = {
			network_cidr = net_cidr,
			network_name = getLocalNetworkLabel(net_cidr) or net_cidr,
		}
	end

	return list
end

-- ##############################################
-- Configuration backup/restore support
-- Returns the full Sites configuration as a Lua table:
--   { sites = { <user-defined sites> } }
-- The system-reserved Default site is intentionally excluded.
function site_utils.export()
	local conf = {
		sites = {}
	}

	local exported_fields = site_utils.get_exported_fields()

	local sites = get_sites_from_cache()
	for _, site in pairsByKeys(sites, asc) do
		if not site.reserved then
			-- The id is kept for reference even though it is not a schema-driven
			-- exported field; everything else is built generically so a new
			-- exported attribute is included here with no change.
			local entry = { id = tostring(site.id) }
			for _, key in ipairs(exported_fields) do
				entry[key] = site[key]
			end
			conf.sites[#conf.sites + 1] = entry
		end
	end

	return conf
end

-- ##############################################

-- Removes every user-defined Site and the network->site associations,
-- resetting the auto-increment counter. The Default site is virtual and
-- is therefore not affected.
function site_utils.remove_all_sites()
	ntop.delCache(REDIS_HASH_NAME)
	ntop.delCache(REDIS_NETWORKS_SITES_KEY)
	ntop.delCache(REDIS_COUNTER_KEY)

	sites_list_cache = nil
end

-- ##############################################

-- Imports a Sites configuration previously produced by site_utils.export()
-- using *additive* (merge) semantics, exactly like the CSV import.
-- The original Site IDs in the file are NOT preserved. Since network ->
-- site associations are machine-local and not part of import/export, this is
-- safe: existing Sites (and their associations) keep their IDs untouched, and
-- only brand new Sites - which have no associations yet - receive a new ID.
function site_utils.restore(conf)
	if type(conf) ~= "table" then
		return rest_utils.consts.err.add_site_failed
	end

	local added = 0
	local duplicates = 0
	local skipped = 0

	-- Names already present (case-insensitive). Updated as new Sites are added
	-- so that duplicates *within* the same file are skipped too.
	local existing_names = {}
	for _, s in ipairs(site_utils.getSites()) do
		existing_names[tostring(s.name):lower()] = true
	end

	for _, site in ipairs(conf.sites or {}) do
		-- Never import the reserved Default site (id 0)
		if tostring(site.id or "") ~= tostring(DEFAULT_SITE.id) then
			local name = trimSpace(tostring(site.name or ""))

			-- Silently ignore entries without a name
			if not isEmptyString(name) then
				local name_key = name:lower()

				if existing_names[name_key] then
					-- Site already present (in Redis or added earlier in this
					-- batch): not an error, just skip it silently
					duplicates = duplicates + 1
				else
					-- Build the addSite() input generically from SITE_SCHEMA so any
					-- new exported attribute is forwarded automatically.
					local input = {}
					for _, f in ipairs(site_utils.get_exported_schema()) do
						local v = site[f.key]
						if v == nil then
							v = f.default
						end
						input[f.input_key] = v
					end
					-- `name` was already extracted and trimmed above.
					input.site_name = name

					local rc = site_utils.addSite(input)

					if rc == rest_utils.consts.success.ok then
						added = added + 1
						existing_names[name_key] = true
					else
						-- Real validation error (invalid coordinates,
						-- illegal name, limit reached, ...): skip it
						skipped = skipped + 1
					end
				end
			end
		end
	end

	-- Re-importing an already-present configuration (all duplicates) is a
	-- no-op, not a failure. Treat the import as a failure only if nothing was
	-- added AND there was nothing to skip as a duplicate, i.e. the file had no
	-- usable Site at all.
	if added == 0 and duplicates == 0 then
		return rest_utils.consts.err.add_site_failed
	end

	-- success
	return nil
end

-- ##############################################

function site_utils.formatSite(site_id)
	if isEmptyString(site_id) then
		return DEFAULT_SITE.name
	end

	local site_info = site_utils.getSiteInfo(site_id)
	return site_info.name
end

-- ##############################################

-- Export the module for use in other Lua files
return site_utils

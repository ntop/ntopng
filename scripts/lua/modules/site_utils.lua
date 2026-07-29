--
-- (C) 2013-26 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
package.path = dirs.installdir .. "/scripts/lua/pro/modules/?.lua;" .. package.path

-- Required modules for site management
require("ntop_utils")
local json = require("dkjson")
local rest_utils = require("rest_utils")
local exporters_utils = require("exporters_utils")

-- Module definition - this module provides utilities for managing sites
local site_utils = {}

-- Redis cache keys configuration for persistent storage
local REDIS_HASH_NAME = "ntopng.prefs.sites" -- Stores all sites as hash: id -> JSON
local REDIS_NETWORKS_SITES_KEY = "ntopng.prefs.networks.sites" -- Stores all sites as hash: id -> JSON
local REDIS_COUNTER_KEY = "ntopng.prefs.sites_counter" -- Auto-increment counter for site IDs

-- Configuration limits for sites
local MAX_NAME_SIZE = 32 -- Maximum character length for site names
local MAX_DESCRIPTION_SIZE = 256 -- Maximum character length for site descriptions
local MAX_PROFILES_NUM = 1024 -- Maximum number of sites allowed in the system
local MAX_HIERARCHY_DEPTH = MAX_PROFILES_NUM -- Safety bound when walking up the parent chain

-- ##############################################
-- Site name character policy
local SITE_NAME_PATTERN = "^[%w _&À-ÖØ-öø-ÿ]+$"

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

-- Forward declarations. The sites caches are defined further down, next to
-- get_sites_from_cache(), but the lookup helpers are already needed by the
-- validation code above them.
local get_sites_by_name

-- Checks whether making parent_id the parent of site_id would create a
-- circular hierarchy. Sites form a tree: a site has one parent and may have
-- many children, so a site can never be an ancestor of itself

local function creates_parent_loop(site_id, parent_id, sites)
	if isEmptyString(site_id) or isEmptyString(parent_id) then
		return false
	end

	site_id = tostring(site_id)

	local visited = {}
	local current = tostring(parent_id)

	for _ = 1, MAX_HIERARCHY_DEPTH do
		-- Root reached ("0"/empty is the "no parent" sentinel): no loop
		if isEmptyString(current) or current == "0" then
			return false
		end

		-- Walking up from the candidate parent we got back to the site being
		-- edited: it would become an ancestor of itself
		if current == site_id then
			return true
		end

		-- Pre-existing loop among other sites: not caused by this assignment
		if visited[current] then
			return false
		end
		visited[current] = true

		local ancestor = sites[current]
		if not ancestor then
			-- Unknown ancestor: the chain is broken, nothing else to check
			return false
		end

		current = ancestor.parent and tostring(ancestor.parent) or nil
	end

	-- Depth limit reached: play safe and refuse the assignment
	return true
end

-- ##############################################

-- Number of characters (not bytes) of an UTF-8 string: continuation bytes
-- (10xxxxxx) are not counted, so an accented name such as "Città" is 5
-- characters long and not 6 as "#" would report.
local function utf8_len(str)
	local _, count = str:gsub("[^\128-\191]", "")
	return count
end

-- ##############################################

-- Validates a Site name against the character policy defined above.
-- Returns true on success, false plus an error message otherwise.
--
function site_utils.validateSiteName(site_name)
	if type(site_name) ~= "string" then
		return false, "Invalid name"
	end

	if #site_name == 0 then
		return false, "Invalid name"
	end

	if utf8_len(site_name) > MAX_NAME_SIZE then
		return false, "Invalid name, max characters: " .. MAX_NAME_SIZE
	end

	-- Alphanumeric characters, spaces, "_", "&" and accented letters
	if not site_name:match(SITE_NAME_PATTERN) then
		return false, "Invalid name, illegal character"
	end

	return true
end

-- ##############################################

-- Validates all parameters for a Site before creation or modification
-- This comprehensive validation ensures data integrity and prevents duplicates
local function validate_site(site, existing_sites, ignore_name_duplication)
	if not site then
		return false, "Invalid data"
	end

	-- Step 1: Validate site name (length + character policy)
	local name_ok, name_err = site_utils.validateSiteName(site.site_name)

	if not name_ok then
		return false, name_err
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

	-- Make sure the parent assignment keeps the hierarchy acyclic.
	-- Only relevant on edit: a brand new site has no children yet, so it cannot
	-- close a loop (site.site_id is nil in addSite()).
	if site.site_parent and site.site_id then
		if tostring(site.site_parent) == tostring(site.site_id) then
			return false, "A site cannot be its own parent"
		end
		if creates_parent_loop(site.site_id, site.site_parent, existing_sites) then
			local parent_name = site_utils.getSiteInfo(site.site_parent).name
			return false,
				"Invalid Parent Site: "
					.. parent_name
					.. " is a descendant of "
					.. site.site_name
					.. ", this would create a circular hierarchy"
		end
	end

	-- Check for duplicate site names (unless explicitly disabled for edits)
	if not ignore_name_duplication then
		local duplicate = get_sites_by_name()[name_lower]
		if duplicate then
			return false, "Site " .. duplicate.name .. " already exists"
		end
	end

	-- All validation passed
	return true
end

-- ##############################################

local sites_list_cache = nil
local sites_by_name_cache = nil

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

-- Lazily builds (and returns) the name -> site index. Assigned to the local
-- forward-declared at the top of the file.
get_sites_by_name = function()
	if sites_by_name_cache == nil then
		local by_name = {}

		for _, site in pairs(get_sites_from_cache()) do
			by_name[tostring(site.name):lower()] = site
		end

		sites_by_name_cache = by_name
	end

	return sites_by_name_cache
end

-- ##############################################

-- Drops every in-memory cache: the next read reloads them from Redis
local function invalidate_sites_cache()
	sites_list_cache = nil
	sites_by_name_cache = nil
end

-- ##############################################

-- Adds an already persisted site to the in-memory caches, when they are
-- populated.
local function cache_site_record(site_id, site_record)
	if sites_list_cache ~= nil then
		sites_list_cache[tostring(site_id)] = site_record
	end

	if sites_by_name_cache ~= nil then
		sites_by_name_cache[tostring(site_record.name):lower()] = site_record
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

		-- Invalidate the in-memory caches so subsequent reads see the update.
		-- A full invalidation is used here because an edit can rename a site,
		-- i.e. change its key in the by-name index.
		invalidate_sites_cache()
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

		-- Keep the in-memory caches coherent so that subsequent reads (and the
		-- duplicate check of the next addSite in a batch) see this site
		-- without paying a full reload of the Redis hash
		cache_site_record(site_id, site_json)
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

		-- Invalidate the in-memory caches so subsequent reads see the removal
		invalidate_sites_cache()
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
	local default_site = site_utils.get_default_site()

	if isEmptyString(site_id) or (tostring(site_id) == tostring(default_site.id)) then
		return default_site
	end

	-- Check the existence of the site, otherwise skip it.
	local site = get_sites_from_cache()[tostring(site_id)]

	if not site then
		return default_site
	end

	-- Return a schema-driven copy, so that callers cannot alter the cache
	local record = {}
	for _, f in ipairs(SITE_SCHEMA) do
		record[f.key] = site[f.key]
	end
	record["id"] = tostring(site.id)

	return record
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
	if not interface.getNetworkStats(tonumber(network_id)) then
		-- Not a network, return
		return false
	end

	-- Check the existence of the site, otherwise skip it.
	if get_sites_from_cache()[tostring(site_id)] then
		-- Site found, update the network + site key
		ntop.setHashCache(REDIS_NETWORKS_SITES_KEY, tostring(network_id), tostring(site_id))
		return true
	end

	return false
end

-- ##############################################

-- Network -> Sites hierarchy mapping
--
-- Entries have the "<network CIDR>=<site>/<site>/.../<network name>" form,
-- e.g. "192.168.1.0/24=Italia/Toscana/Firenze/Home": every component but the last
-- one is a Site of the hierarchy (Firenze child of Toscana, child of Italia),
-- while the last one is the name (alias) of the network itself.
--
local SITE_PATH_SEPARATOR = "/"

-- Splits an entry into the network CIDR (nil when the "=" is missing, i.e.
-- when only the path is supplied) and the array of its components.
-- Note: the split is done on the FIRST "=" only, as the CIDR contains "/"
-- itself and must not be confused with a path separator.
local function parseSitePath(entry)
	if type(entry) ~= "string" then
		return nil, {}
	end

	local network_cidr, path = entry:match("^([^=]*)=(.*)$")

	if not path then
		-- No "=": the whole string is the hierarchy path
		network_cidr, path = nil, entry
	else
		network_cidr = trimSpace(network_cidr)

		if isEmptyString(network_cidr) then
			network_cidr = nil
		end
	end

	local components = {}

	-- Empty components are skipped
	for component in path:gmatch("[^" .. SITE_PATH_SEPARATOR .. "]+") do
		component = trimSpace(component)

		if not isEmptyString(component) then
			components[#components + 1] = component
		end
	end

	return network_cidr, components
end

-- ##############################################

-- Returns the id of the site named site_name, creating it as a child of
-- parent_id (nil for a root site) when it does not exist yet.
-- Returns nil plus an error message on failure.
local function resolveOrCreateSite(site_name, parent_id)
	local name_ok, name_err = site_utils.validateSiteName(site_name)

	if not name_ok then
		return nil, name_err .. " (" .. site_name .. ")"
	end

	local existing = get_sites_by_name()[site_name:lower()]

	if existing then
		-- Already there: the site is reused as-is and its current parent is
		-- deliberately NOT modified, so that a hierarchy edited from the GUI
		-- is not silently rearranged by a reload of the networks file.
		-- Site names being unique system-wide, this is also what makes the
		-- import idempotent when the same path is shared by many networks.
		return tostring(existing.id)
	end

	local rc, msg = site_utils.addSite({
		site_name = site_name,
		site_description = "",
		site_parent = parent_id,
		latitude = 0,
		longitude = 0,
	})

	if rc ~= rest_utils.consts.success.ok then
		return nil, msg
	end

	-- addSite() keeps the caches coherent, hence the site just created is
	-- already in the index: no Redis round trip to read its id back
	local created = get_sites_by_name()[site_name:lower()]

	if not created then
		return nil, "Unable to create site " .. site_name
	end

	return tostring(created.id)
end

-- ##############################################

-- Creates the (missing) sites of the hierarchy described by entry and maps
-- network_id to the innermost one.
function site_utils.mapNetworkToSitePath(network_id, entry)
	-- setLocalNetworkAlias() and trimSpace(); required here, and not at the
	-- top of the file, to keep site_utils loadable on its own
	require("lua_utils")

	if not tonumber(network_id) then
		return false, "Invalid network id"
	end

	local network_cidr, components = parseSitePath(entry)

	if table.len(components) == 0 then
		return false, "Empty site path"
	end
	-- The last component is the name of the network, not a site
	local network_name = table.remove(components)

	-- Walk the path top-down, creating only what is missing.
	local site_id = nil

	for _, site_name in ipairs(components) do
		local id, err = resolveOrCreateSite(site_name, site_id)

		if not id then
			return false, err
		end

		site_id = id
	end

	-- Map the network to the innermost site of the path
	if site_id then
		site_utils.mapNetworkToSite(network_id, site_id)
		ntop.refreshNetworkSiteId(tonumber(network_id))
	end

	return true, site_id
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
		sites = {},
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
-- Drops every network -> Site association, so that all the networks fall
-- back to the Default Site.
-- The site id is also cached C-side by NetworkStats, hence every network is
-- explicitly refreshed: without it the change would only become visible on
-- the next restart
function site_utils.unmapAllNetworks()
	local networks = ntop.getNetworks() or {}

	ntop.delCache(REDIS_NETWORKS_SITES_KEY)

	for _, network_id in pairs(networks) do
		ntop.refreshNetworkSiteId(tonumber(network_id))
	end
end

-- ##############################################
-- Removes every user-defined Site and the network->site associations,
-- resetting the auto-increment counter. The Default site is virtual and
-- is therefore not affected.
function site_utils.remove_all_sites()
	ntop.delCache(REDIS_HASH_NAME)
	ntop.delCache(REDIS_COUNTER_KEY)
	site_utils.unmapAllNetworks()
	invalidate_sites_cache()
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

-- ################################################
-- Per-request cache: network_id -> resolved Site name.
-- The IP influences the result ONLY through its network_id, so two exporters
-- on the same network always map to the same Site. Many exporters share a
-- network, therefore caching by network_id lets us resolve each
-- distinct network at most once per request instead of once per exporter
local _site_by_network = {}

function site_utils.resolveExporterSite(exporter_ip)
	if isEmptyString(exporter_ip) then
		return site_utils.get_default_site()
	end

	-- In-memory lookup
	local network_id = interface.getIPNetworkId(exporter_ip)
	if network_id == nil then
		return site_utils.get_default_site()
	end

	local cached = _site_by_network[network_id]
	if cached ~= nil then
		return cached
	end

	-- Cache miss: this is the only branch that performs Redis reads.
	local site = site_utils.getNetworkSite(network_id)
	_site_by_network[network_id] = site

	return site
end

-- ##############################################

-- Returns the list of parents sites
local function getRootSite()
	local all_sites = site_utils.getSites()
	local parents_sites = {}
	local list_of_child_parents = {}
	for _, info in pairsByField(all_sites, "name", asc) do
		-- If empty or null, it's the one we are searching for, a parent site
		if isEmptyString(info.parent) then
			parents_sites[tostring(info.id)] = info
		end
	end

	return { sites = parents_sites }
end

-- ################################################
-- Per-request cache: network_id -> array of SNMP devices.
local _snmp_devices_by_network = nil

local function getSNMPDevicesByNetwork()
	if _snmp_devices_by_network ~= nil then
		return _snmp_devices_by_network
	end

	_snmp_devices_by_network = {}

	if not (ntop.isPro and ntop.isPro()) then
		return _snmp_devices_by_network
	end

	local snmp_config = require("snmp_config")

	for ip_device, info in pairs(snmp_config.get_all_configured_devices() or {}) do
		local network_id = tonumber(info.network_id) or interface.getIPNetworkId(ip_device)
		local name = ip_device
		local is_active = false

		if info.stats then
			name = info.stats.name or ip_device
			is_active = not info.stats.is_unreachable
		end

		local bucket = _snmp_devices_by_network[network_id]
		if not bucket then
			bucket = {}
			_snmp_devices_by_network[network_id] = bucket
		end

		bucket[#bucket + 1] = {
			network_id = network_id,
			name = name,
			is_active = is_active,
			ip = ip_device,
		}
	end

	return _snmp_devices_by_network
end

-- ##############################################

-- Shallow-copies a flat table.
local function shallowCopy(t)
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = v
	end
	return copy
end

-- Appends the owner site name to a component display name, e.g.
-- "x.x.x.x" + "Roma" -> "x.x.x.x (Roma)".
local function withOriginSuffix(name, origin_name)
	return tostring(name) .. " (" .. tostring(origin_name) .. ")"
end

-- Returns a COPY of an inherited component, labelled with the site it comes
-- from. The copy is mandatory: the source tables are not allocated here (they
-- belong to the exporters list, to the SNMP configuration and to the
-- per-request caches above) and are therefore shared.
local function withOrigin(component, fallback_name_key, origin_id, origin_name)
	local copy = shallowCopy(component)
	copy.name = withOriginSuffix(component.name or component[fallback_name_key], origin_name)
	copy.origin_site_id = origin_id
	copy.origin_site_name = origin_name
	return copy
end

-- ##############################################

-- Builds a map (site_id -> array of exporters) by resolving each exporter's
-- owning site exactly once.
local function getExportersBySite()
	local exporters_by_site = {}
	local exporters_list = exporters_utils.getAllExportersList()

	for _, exporter_info in pairs(exporters_list or {}) do
		local exporter_site = site_utils.resolveExporterSite(exporter_info.id)
		local sid = tostring(exporter_site.id)
		exporter_info.network_id = interface.getIPNetworkId(exporter_info.id)
		local bucket = exporters_by_site[sid]
		if not bucket then
			bucket = {}
			exporters_by_site[sid] = bucket
		end
		bucket[#bucket + 1] = exporter_info
	end

	return exporters_by_site
end

-- ##############################################

-- Returns the components (networks + their SNMP devices, and exporters) that
-- belong DIRECTLY to site_id, i.e. not inherited from any descendant site.
-- The precomputed maps are passed in by the caller: this function is invoked
-- once per site of the subtree and must not rebuild them.
local function getDirectSiteComponents(site_id, exporters_by_site, devices_by_network)
	local networks_to_add = {}
	local devices = {}

	local networks = interface.getSiteNetworks(tonumber(site_id))
	for _, network_id in pairs(networks or {}) do
		local network_cidr = ntop.getNetworkNameById(tonumber(network_id))

		networks_to_add[#networks_to_add + 1] = {
			id = network_id,
			name = getLocalNetworkAliasById(network_id),
			short_name = getLocalNetworkAliasById(network_id, true),
			cidr = network_cidr,
			alias = network_cidr and getLocalNetworkAlias(network_cidr) or nil,
		}

		-- Linear append: table.merge() allocated a new table and re-copied the
		-- accumulator on every network, i.e. O(networks^2).
		for _, dev in ipairs(devices_by_network[tonumber(network_id)] or {}) do
			devices[#devices + 1] = dev
		end
	end

	return {
		networks = networks_to_add,
		-- WARNING: this is an alias of the map bucket, never append to it
		-- (see getSiteLeaves).
		exporters = exporters_by_site[tostring(site_id)] or {},
		snmp_devices = devices,
	}
end

-- ##############################################

-- Index parent_id -> { child_site, ... }, built once and reused both for the
-- direct children and for the BFS over the descendants.
local function buildChildrenIndex(all_sites)
	local children_by_parent = {}

	for _, info in ipairs(all_sites) do
		if not isEmptyString(info.parent) then
			local pid = tostring(info.parent)
			local bucket = children_by_parent[pid]
			if not bucket then
				bucket = {}
				children_by_parent[pid] = bucket
			end
			bucket[#bucket + 1] = info
		end
	end

	return children_by_parent
end

-- Returns the descendant sites of site_id (children, grandchildren, ...), each
-- as a site record { id, name, parent, ... }. The visited set already makes a
-- cycle impossible: the bound is only a safety net on the NUMBER of visited
-- nodes (at most the number of sites in the system).
local function getDescendantSites(site_id, children_by_parent)
	local descendants = {}
	local visited = { [tostring(site_id)] = true }
	local queue = { tostring(site_id) }
	local head = 1

	while queue[head] and #descendants <= MAX_PROFILES_NUM do
		local current = queue[head]
		head = head + 1

		for _, child in ipairs(children_by_parent[current] or {}) do
			local cid = tostring(child.id)
			if not visited[cid] then
				visited[cid] = true
				descendants[#descendants + 1] = child
				queue[#queue + 1] = cid
			end
		end
	end

	return descendants
end

-- ##############################################

-- How much of a site has to be returned by getSiteComponents()/getSiteLeaves().
site_utils.components_scope = {
	-- sub-sites only
	none = "none",
	-- sub-sites and components owned directly by the site
	direct = "direct",
	-- also components inherited from the descendant sites
	all = "all",
}

-- Normalizes an externally supplied scope, falling back to the default one on
-- anything unrecognized.
function site_utils.parseComponentsScope(scope)
	return site_utils.components_scope[tostring(scope or "")] or site_utils.components_scope.direct
end

-- Returns the sub-sites of site_id together with its components: the ones it
-- owns directly and, when the "all" scope is requested, the ones inherited
-- from its descendant sites.
local function getSiteLeaves(site_id, scope)
	local site = tostring(site_id)
	scope = scope or site_utils.components_scope.direct

	local all_sites = site_utils.getSites()
	local children_by_parent = buildChildrenIndex(all_sites)

	-- Direct child sites (shown as sub-sites), resolved with an O(1) lookup on
	-- the index instead of a full scan. Only DIRECT children are listed here:
	-- deeper levels of the hierarchy are reached by expanding each child.
	local sites_to_add = children_by_parent[site] or {}

	if scope == site_utils.components_scope.none then
		return {
			sites = sites_to_add,
			networks = {},
			exporters = {},
			snmp_devices = {},
		}
	end

	-- Expensive lookups: performed once per request, and only when at least
	-- the directly owned components have been asked for.
	local exporters_by_site = getExportersBySite()
	local devices_by_network = getSNMPDevicesByNetwork()

	-- Components owned DIRECTLY by this site: shown without any origin suffix.
	local own = getDirectSiteComponents(site_id, exporters_by_site, devices_by_network)
	local networks_to_add = own.networks
	local devices = own.snmp_devices

	local exporters_to_add = {}
	for _, exp in ipairs(own.exporters) do
		exporters_to_add[#exporters_to_add + 1] = exp
	end

	-- Components INHERITED from descendant sites.
	-- Each inherited item is labelled with the name of the site it belongs to.
	local descendants = {}
	if scope == site_utils.components_scope.all then
		descendants = getDescendantSites(site_id, children_by_parent)
	end

	for _, descendant in ipairs(descendants) do
		local origin_id = tostring(descendant.id)
		local origin_name = descendant.name
		local sub = getDirectSiteComponents(descendant.id, exporters_by_site, devices_by_network)

		for _, net in ipairs(sub.networks) do
			networks_to_add[#networks_to_add + 1] = withOrigin(net, "id", origin_id, origin_name)
		end

		for _, exp in ipairs(sub.exporters) do
			exporters_to_add[#exporters_to_add + 1] = withOrigin(exp, "id", origin_id, origin_name)
		end

		for _, dev in ipairs(sub.snmp_devices) do
			devices[#devices + 1] = withOrigin(dev, "ip", origin_id, origin_name)
		end
	end

	local children_list = {
		sites = sites_to_add,
		networks = networks_to_add,
		exporters = exporters_to_add,
		snmp_devices = devices,
	}

	return children_list
end

-- ##############################################

function site_utils.getSiteComponents(site_id, scope)
	-- Empty site id, it means that all "parents" sites need to be returned
	if isEmptyString(site_id) then
		local parents_sites = getRootSite()
		--   tprint(parents_sites)
		return parents_sites
	else
		-- site_id available, returns all the childs of the site_id
		local children = getSiteLeaves(site_id, scope)
		--   tprint(children)
		return children
	end
end

-- ##############################################

-- Export the module for use in other Lua files
return site_utils

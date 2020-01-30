--
-- (C) 2013-20 - ntop.org
--

local plugins_consts_utils = {}
local dirs = ntop.getDirs()

-- ##############################################

local AVAILABLE_CONSTS = {
   flow = {
      min_id = 1, max_id = 63, reuse_ids = true,
      reserved_ids = {
	 status_normal = 0,
      },
   },
   alert = {
      min_id = 0, max_id = 255, reuse_ids = false,
   }
}

-- ##############################################

local id_requests = {
   flow = {},
   alert = {}
}

-- ##############################################

local function assigned_ids_hname(const_type)
   return string.format("ntopng.prefs.plugins_consts_utils.assigned_ids.const_type_%s", const_type)
end

-- ##############################################

local function assigned_id_key(const_type, const_key)
   local hname = assigned_ids_hname(const_type)
   return string.format("%s.const_key_%s", hname, const_key)
end

-- ##############################################

local function get_assigned_ids(const_type)
   local hname = assigned_ids_hname(const_type)
   local assigned_ids = ntop.getHashAllCache(hname) or {}
   local cur_id_to_key = {}
   local cur_key_to_id = {}

   for const_id, const_key in pairs(assigned_ids) do
      local const_id_n = tonumber(const_id)

      if const_id_n < AVAILABLE_CONSTS[const_type]["min_id"] or const_id_n > AVAILABLE_CONSTS[const_type]["max_id"] then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Ignoring id %i outside boundaries for '%s'", const_id_n, const_type))
      else
	 cur_id_to_key[const_id_n] = const_key
	 cur_key_to_id[const_key] = const_id_n
      end
   end

   return cur_id_to_key, cur_key_to_id
end

-- ##############################################

local function commit_new_ids(const_type, new_ids)
   local hname = assigned_ids_hname(const_type)

   for const_key, const_id in pairs(new_ids) do
      local const_id_s = string.format("%i", const_id)

      -- Attempt to lookup for the id in the cache. Attempting to commit a new id to an existing
      -- it, causes the old key to be reused the new key. This is used for example when reusing ids
      local existing = ntop.getHashCache(hname, const_id)
      if not isEmptyString(existing) then
	 traceError(TRACE_NORMAL, TRACE_CONSOLE, string.format("Reusing id %i '%s' to '%s'", const_id, existing, const_key))
	 ntop.delHashCache(hname, const_id_s)

	 local existing_kname = assigned_id_key(const_type, existing)
	 ntop.delCache(existing_kname)
      end

      -- Now it's time to set the new id, both in the hash table...
      ntop.setHashCache(hname, const_id, const_key)

      -- ... and as a single key
      local kname = assigned_id_key(const_type, const_key)
      ntop.setPref(kname, const_id_s)
   end
end

-- ##############################################

function plugins_consts_utils.clear_id_requests(const_type)
   id_requests[const_type] = {}
end

-- ##############################################

function plugins_consts_utils.request_id(const_type, const_key)
   if not AVAILABLE_CONSTS[const_type] then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unknown const type '%s'", const_type))
      return
   end

   id_requests[const_type][#id_requests[const_type] + 1] = const_key
end

-- ##############################################

function plugins_consts_utils.assign_requested_ids(const_type)
   if not AVAILABLE_CONSTS[const_type] then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unknown const type '%s'", const_type))
      return
   end

   local cur_id_to_key, cur_key_to_id = get_assigned_ids(const_type)
   local available_ids = {}
   local used_ids = {}
   local new_ids = {}
   local found_ids = {}
   local deferred_requests = {}
   local reused_ids = {}

   -- Prepare used and available ids by iterating the current existing ids (i.e., those
   -- that have already been assigned)
   for i = AVAILABLE_CONSTS[const_type]["min_id"], AVAILABLE_CONSTS[const_type]["max_id"] do
      if cur_id_to_key[i] then
	 used_ids[#used_ids + 1] = i
      else
	 available_ids[#available_ids + 1] = i
      end
   end

   for _, req in ipairs(id_requests[const_type]) do
      if AVAILABLE_CONSTS[const_type]["reserved_ids"] and AVAILABLE_CONSTS[const_type]["reserved_ids"][req] then
	 -- Id among those reserved, so id is already assigned and there is nothing to do
      elseif cur_key_to_id[req] then
	 -- Id found: already assigned, nothing to do
	 found_ids[#found_ids + 1] = cur_key_to_id[req]
      elseif #available_ids > 0 then
	 -- At least an id is available in the pool of available ids
	 new_ids[req] = table.remove(available_ids, 1)
      elseif AVAILABLE_CONSTS[const_type]["reuse_ids"] then
	 -- No ids available but reuse of old ids is enabled
	 deferred_requests[#deferred_requests + 1] = req
      else
	 -- No ids available and reuse not allowed, unable to assign.
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unable to assign an id to '%s' for const type '%s'. No more ids available", req, const_type))
      end
   end

   commit_new_ids(const_type, new_ids)

   if #deferred_requests > 0 then
      for _, used_id in ipairs(used_ids) do
	 local used_id_found = false

	 for _, found_id in ipairs(found_ids) do
	    if used_id == found_id then
	       -- Used id found during this run, cannot reuse it
	       used_id_found = true
	       break
	    end
	 end

	 if not used_id_found then
	    -- This id is used but not found so it means no plugin is using it (during this run) and it can be reused
	    reused_ids[table.remove(deferred_requests, 1)] = used_id
	 end

	 if #deferred_requests == 0 then
	    -- No more work to do
	    break
	 end
      end

      commit_new_ids(const_type, reused_ids)

      if #deferred_requests > 0 then
	 for _, req in ipairs(deferred_requests) do
	    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unable to reuse any id for '%s' with const type '%s'.", req, const_type))
	 end
      end
   end
end

-- ##############################################

function plugins_consts_utils.get_assigned_id(const_type, const_key)
   if not AVAILABLE_CONSTS[const_type] then
      traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Unknown const type '%s'", const_type))
      return
   end

   if AVAILABLE_CONSTS[const_type]["reserved_ids"] and AVAILABLE_CONSTS[const_type]["reserved_ids"][const_key] then
      return AVAILABLE_CONSTS[const_type]["reserved_ids"][const_key]
   end

   -- Avoid reading the whole hash, just read the single key to re-use also ntopng internal caching mechanism
   local kname = assigned_id_key(const_type, const_key)
   local assigned_id = tonumber(ntop.getPref(kname))

   if assigned_id == nil then
     -- Not found in the internal cache, check the hash
     local cur_id_to_key, cur_key_to_id = get_assigned_ids(const_type)
     if cur_key_to_id[const_key] ~= nil then
        return cur_key_to_id[const_key]
     end
   end

   -- Make sure the index is within the configured bounds
   if assigned_id then
      if assigned_id < AVAILABLE_CONSTS[const_type]["min_id"] or assigned_id > AVAILABLE_CONSTS[const_type]["max_id"] then
	 traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("Ignoring id %i outside boundaries for '%s'", assigned_id, const_type))
	 -- Clear it as it should have that value
	 assigned_id = nil
      end
   end

   return assigned_id
end

return plugins_consts_utils

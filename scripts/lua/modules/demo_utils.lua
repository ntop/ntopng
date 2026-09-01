--
-- (C) 2013-26 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path

local json = require "dkjson"
local os_utils = require "os_utils"
require "check_redis_prefs"

local demo_utils = {}

local DEMO_CONFIG_DIR = os_utils.fixPath(dirs.installdir .. "/httpdocs/demo_config")
local REGISTRY_FILE = os_utils.fixPath(DEMO_CONFIG_DIR .. "/demo_registry.json")
local REGISTRY_FILENAME = "demo_registry.json"

-- Default anti-spam grace period before a tour is allowed to show, per
-- trigger type.
local DEFAULT_DELAY_SECONDS = {
   first_login = 0, -- 2 minutes: let them get their bearings first
   new_feature = 20,
}

-- Named visibility conditions a demo can require via "visibility_condition"
-- in demo_registry.json (or the demo's own JSON file).
local VISIBILITY_CONDITIONS = {
   has_nanalyst = function()
      return isnAnalystAvailable()
   end,
}

-- ##############################################

local function read_json_file(path)
   local f = io.open(path, "r")
   if f == nil then
      return nil
   end

   local content = f:read("*all")
   f:close()

   local decoded = json.decode(content)
   return decoded
end

-- ##############################################

-- Auto-discovers every demo JSON file in httpdocs/demo_config/ (any *.json
-- except demo_registry.json itself) and registers it using its own top-level
-- id/title/trigger/version 
function demo_utils.get_registry()
   local manual = read_json_file(REGISTRY_FILE) or { demos = {} }
   local manual_by_id = {}
   for _, d in ipairs(manual.demos or {}) do
      manual_by_id[d.id] = d
   end

   local demos = {}
   local seen_ids = {}
   local files = ntop.readdir(DEMO_CONFIG_DIR) or {}

   for fname in pairs(files) do
      if fname:match("%.json$") and fname ~= REGISTRY_FILENAME then
         local config = read_json_file(os_utils.fixPath(DEMO_CONFIG_DIR .. "/" .. fname))

         if config and config.id and not seen_ids[config.id] then
            seen_ids[config.id] = true
            local override = manual_by_id[config.id] or {}

            demos[#demos + 1] = {
               id = config.id,
               file = fname,
               title = override.title or config.title,
               description = override.description,
               trigger = override.trigger or config.trigger,
               delay_seconds = override.delay_seconds
                  or DEFAULT_DELAY_SECONDS[override.trigger or config.trigger] or 0,
               enabled = (override.enabled ~= false),
               visibility_condition = override.visibility_condition or config.visibility_condition,
            }
         end
      end
   end

   -- Manual entries whose file wasn't found by the scan (e.g. bad filename)
   -- still surface, so a misconfiguration is visible via the status list
   -- rather than silently disappearing.
   for id, d in pairs(manual_by_id) do
      if not seen_ids[id] then
         demos[#demos + 1] = {
            id = d.id,
            file = d.file,
            title = d.title,
            description = d.description,
            trigger = d.trigger,
            delay_seconds = d.delay_seconds or DEFAULT_DELAY_SECONDS[d.trigger] or 0,
            enabled = (d.enabled ~= false),
            visibility_condition = d.visibility_condition,
         }
      end
   end

   return { demos = demos }
end

-- ##############################################

-- Evaluates a demo's "visibility_condition" (nil/unknown name => always visible)
function demo_utils.is_visible(demo)
   if isEmptyString(demo.visibility_condition) then
      return true
   end

   local check = VISIBILITY_CONDITIONS[demo.visibility_condition]
   return check == nil or check() == true
end

-- ##############################################

-- Returns the full step config for a given demo id, nil if not found/disabled
function demo_utils.get_demo_config(demo_id)
   local registry = demo_utils.get_registry()

   for _, demo in ipairs(registry.demos or {}) do
      if demo.id == demo_id and demo.enabled ~= false and demo.file and demo_utils.is_visible(demo) then
         local path = os_utils.fixPath(DEMO_CONFIG_DIR .. "/" .. demo.file)
         local config = read_json_file(path)

         if config then
            -- merge registry metadata (title/trigger) into the config response
            config.trigger = config.trigger or demo.trigger
            config.title = config.title or demo.title
         end

         return config
      end
   end

   return nil
end

-- ##############################################

local function progress_key(username, demo_id)
   return string.format("ntopng.user.%s.demo_tour.%s", username, demo_id)
end

-- ##############################################

-- Returns the progress table for a demo/user, or nil if never started
function demo_utils.get_progress(username, demo_id)
   local raw = ntop.getCache(progress_key(username, demo_id))

   if isEmptyString(raw) then
      return nil
   end

   return json.decode(raw)
end

-- ##############################################

-- Persists a progress table for a demo/user
function demo_utils.save_progress(username, demo_id, progress)
   ntop.setCache(progress_key(username, demo_id), json.encode(progress))
   return true
end

-- ##############################################

-- Records the current step index reached by the user
function demo_utils.set_step(username, demo_id, step_index)
   local progress = demo_utils.get_progress(username, demo_id) or {}

   progress.step_index = step_index
   progress.updated_at = os.time()

   return demo_utils.save_progress(username, demo_id, progress)
end

-- ##############################################

-- Marks a demo as fully completed. `version` is the config version the user
-- just finished, so a later version bump can re-trigger the tour.
function demo_utils.mark_complete(username, demo_id, version)
   local progress = demo_utils.get_progress(username, demo_id) or {}

   progress.completed_at = os.time()
   progress.seen_version = version
   progress.dismissed = false

   return demo_utils.save_progress(username, demo_id, progress)
end

-- ##############################################

-- Marks a demo as dismissed ("never show again")
function demo_utils.dismiss(username, demo_id)
   local progress = demo_utils.get_progress(username, demo_id) or {}

   progress.dismissed = true
   progress.dismissed_at = os.time()

   return demo_utils.save_progress(username, demo_id, progress)
end

-- ##############################################

-- Decides whether a demo should be shown to this user right now.
-- Re-shows automatically when the JSON config `version` is bumped.
-- `delay_seconds` is an anti-spam grace period: the first time a user is
-- ever eligible for this demo, we just record the timestamp and say no —
-- nothing pops up on the very first page they land on.
function demo_utils.should_show(username, demo_id, demo_version, delay_seconds)
   delay_seconds = delay_seconds or 0
   local progress = demo_utils.get_progress(username, demo_id)

   if progress == nil then
      demo_utils.save_progress(username, demo_id, { first_seen_at = os.time() })
      return delay_seconds <= 0
   end

   if progress.dismissed then
      return false
   end

   if progress.completed_at ~= nil then
      if demo_version and (progress.seen_version == nil or progress.seen_version < demo_version) then
         return true -- version bump: re-show immediately, user is already engaged
      end
      return false
   end

   if progress.first_seen_at == nil then
      progress.first_seen_at = os.time()
      demo_utils.save_progress(username, demo_id, progress)
      return delay_seconds <= 0
   end

   return (os.time() - progress.first_seen_at) >= delay_seconds
end

-- ##############################################

-- Seeds first_seen_at for every existing user x registered demo that has no
-- progress key yet. Run once at ntopng startup so users who existed before a
-- demo was added (fresh install upgrade)
function demo_utils.seed_missing_progress()
   local registry = demo_utils.get_registry()
   local users = ntop.getUsers and ntop.getUsers() or {}

   for username, _ in pairs(users) do
      for _, demo in ipairs(registry.demos or {}) do
         if demo.enabled ~= false and demo_utils.get_progress(username, demo.id) == nil then
            demo_utils.save_progress(username, demo.id, { first_seen_at = os.time() })
         end
      end
   end
end

-- ##############################################

-- Convenience: full status list (should_show flag) for every registered demo
function demo_utils.get_status_for_user(username)
   local registry = demo_utils.get_registry()
   local out = {}

   for _, demo in ipairs(registry.demos or {}) do
      if demo.enabled ~= false and demo_utils.is_visible(demo) then
         local config = demo_utils.get_demo_config(demo.id)
         local version = config and config.version or 1

         out[#out + 1] = {
            id = demo.id,
            title = demo.title,
            trigger = demo.trigger,
            version = version,
            should_show = demo_utils.should_show(username, demo.id, version, demo.delay_seconds),
         }
      end
   end

   return out
end

-- ##############################################

return demo_utils

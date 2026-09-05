--
-- (C) 2013-26 - ntop.org
--

-- Exposes ntopng runtime preferences to the LLM: for every entry declared in
-- prefs_menu_schema.lua that is backed by a Redis key, return the key, its
-- current value (falling back to the schema default), the widget type and the
-- section it belongs to. Gives the model context on how the instance is tuned.

local json = require("dkjson")
local prefs_menu_schema = require("prefs_menu_schema")

return {
   name = "get_preferences",
   description = "Return the ntopng runtime preferences. Each entry contains: section, key, " ..
      "redis_key, current value (from Redis, or the schema default if unset), type " ..
      "('toggle'|'input'|'select'|...), and — for select entries — the list of allowed values. " ..
      "Use this to know how the current ntopng instance is configured (alerts, logging, " ..
      "timeseries, retention, SNMP, etc.). " ..
      "Optional args: section (string, filter to a single section id), " ..
      "search (string, case-insensitive substring match on key or redis_key).",
   handler = function(args)
      local section_filter = args and args.section
      local search = args and args.search
      if search then search = string.lower(search) end

      local ok, flags = pcall(prefs_menu_schema.get_flags)
      if not ok or not flags then
         return nil, "Unable to build preferences flags"
      end

      local ok2, sections = pcall(prefs_menu_schema.get_sections, flags)
      if not ok2 or not sections then
         return nil, "Unable to load preferences schema"
      end

      local out = {}

      for _, section in ipairs(sections) do
         if not section.hidden and (not section_filter or section.id == section_filter) then
            for _, entry in ipairs(section.entries or {}) do
               local rkey = entry.redis_key
               if rkey and not entry.hidden then
                  local matches = true
                  if search then
                     matches = (string.find(string.lower(rkey), search, 1, true) ~= nil) or
                               (entry.key and string.find(string.lower(entry.key), search, 1, true) ~= nil)
                  end

                  if matches then
                     local resolved_key = rkey:gsub("__SESSION_USER__", _SESSION and _SESSION["user"] or "")
                     local value = ntop.getPref(resolved_key)
                     if isEmptyString(value) then
                        value = entry.default
                     end

                     -- Never expose secrets: passwords, tokens, secrets, api keys
                     local lkey = string.lower(entry.key or "")
                     local is_secret = entry.input_type == "password" or
                        lkey:find("token", 1, true) or lkey:find("secret", 1, true) or
                        lkey:find("password", 1, true) or lkey:find("passwd", 1, true) or
                        lkey:find("api_key", 1, true) or lkey:find("apikey", 1, true)
                     if is_secret then
                        value = (not isEmptyString(value)) and "<set>" or "<unset>"
                     end

                     local row = {
                        section   = section.id,
                        key       = entry.key,
                        redis_key = rkey,
                        type      = entry.type,
                        value     = value,
                     }

                     if entry.type == "select" and entry.options then
                        local allowed = {}
                        for _, v in ipairs(entry.options) do
                           allowed[#allowed + 1] = v.value ~= nil and v.value or v
                        end
                        row.allowed_values = allowed
                     end

                     if entry.unit then row.unit = entry.unit end

                     out[#out + 1] = row
                  end
               end
            end
         end
      end

      if #out == 0 then
         return "No matching preferences found.", nil
      end

      return json.encode(out), nil
   end,
   opts = { read_only = true }
}

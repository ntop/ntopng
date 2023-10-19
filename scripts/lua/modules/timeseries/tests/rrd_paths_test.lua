--
-- (C) 2021 - ntop.org
--

local ts_utils = require("ts_utils")
local test_utils = require("test_utils")
local rrd = require("rrd")

-- ##############################################

local test_tag_values = {
  "1", "1.2.3.4", "abcd", "11:22:33:44:55:66", "99"
}
local replacement_tag = "some_other_tag"

local prefixes_to_skip = {
  test = true,
  mac = true,                 -- Collides with host, but a MAC address is different from an IP address
  influxdb = true,
}

local suffixes_to_skip = {
}

-- ##############################################

local function skipSchema(schema_name)
  local parts = string.split(schema_name, ":") or {}
  if #parts ~= 2 then
    return(true)
  end

  if prefixes_to_skip[parts[1]] or suffixes_to_skip[parts[2]] then
    return(true)
  end

  return(false)
end

-- Ensure that we do not have collisions on RRD file paths
function test_unique_paths(test)
  local schemas = ts_utils.getLoadedSchemas()
  local unique_paths = {}

  for _, schema in pairs(schemas) do
    if skipSchema(schema.name) then
      goto continue
    end

    -- build the tags
    local tags1 = {}
    for tag_idx, tag_key in ipairs(schema._tags) do
      tags1[tag_key] = test_tag_values[tag_idx]
    end

    local fpath = rrd.schema_get_full_path(schema, tags1)
    if not (unique_paths[fpath] == nil) then
      return test:assertion_failed("unique_paths[" .. fpath .. "] == nil: schema=".. schema.name ..", existing_schema=" .. unique_paths[fpath])
    end
    unique_paths[fpath] = schema.name

    -- double check changing the last tag
    if #schema._tags >= 1 then
      local last_tag = schema._tags[#schema._tags]
      local tags2 = table.clone(tags1)
      tags2[last_tag] = replacement_tag

      local fpath = rrd.schema_get_full_path(schema, tags2)
      if not (unique_paths[fpath] == nil) then
        return test:assertion_failed("(while chaning last tag) unique_paths[" .. fpath .. "] == nil: schema=".. schema.name ..", existing_schema=" .. unique_paths[fpath])
      end
      unique_paths[fpath] = schema.name
    end

    ::continue::
  end

  return test:success()
end

-- ##############################################

function run(tester)
  local rv = tester.run_test("rrd_paths:unique", test_unique_paths)

  return rv
end

return {
  run = run
}

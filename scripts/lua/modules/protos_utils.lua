--
-- (C) 2021 - ntop.org
--

local os_utils = require("os_utils")
local http_lint = require "http_lint"
local protos_utils = {}

-- ##############################################

local function getProtosFile()
  return os_utils.fixPath(ntop.getPrefs().ndpi_proto_file)
end

-- ##############################################

local function parsePortBasedRule(filter, value, line)
  local parts

  if((filter == "tcp") or (filter == "udp")) then
    -- single port or port range
    local lower, upper
    parts = string.split(value, "-")

    if((parts ~= nil) and (#parts == 2)) then
      -- port range
      lower = tonumber(parts[1])
      upper = tonumber(parts[2])
    else
      lower = tonumber(value)
      upper = lower
    end

    if((lower ~= nil) and (upper ~= nil)) then
      return true, {
        match = "port",
        proto = filter,
        port_lower = lower,
        port_upper = upper,
        value = string.format("%s:%s", filter, value),
      }
    else
      traceError(TRACE_WARNING, TRACE_CONSOLE,
        string.format("[protos.txt] Ignoring bad %s port range '%s' in rule: %s", filter, value, line))
      return true, nil
    end
  end

  return false, nil
end

-- ##############################################

-- Parses a nDPI protos.txt file and returns an a key-based table
-- with the mappings app->rules mappings. Also an index based tabled of the
-- defined protocols is returned to ensure that the protocols are always appended to the
-- end of the file as nDPI assigns the custom protocol IDs sequentially.
function protos_utils.parseProtosTxt()
  local path = getProtosFile()

  if not ntop.exists(path) then
    return {}, {}
  end

  local f = io.open(path, "r")
  local defined_protos = {}
  local rules = {}

  local function addRule(proto, rule)
    if(rules[proto] == nil) then
      rules[proto] = {}
      defined_protos[#defined_protos + 1] = proto
    end

    rules[proto][#rules[proto] + 1] = rule
  end

  if f == nil then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("[protos.txt] Could not open '%s' (invalid permissions?)", path))
    return {}, {}
  end

  for full_line in f:lines() do
    local line = trimString(full_line)
    local parts = string.split(line, "@")

    if((line == "") or starts(line, "#")) then
      -- comment or empty line
    elseif((parts ~= nil) and (#parts == 2)) then
      local proto = parts[2]
      local rules = parts[1]
      rules = string.split(rules, ",") or {rules}

      for _, rule in ipairs(rules) do
        parts = string.split(rule, ":")

        if((parts ~= nil) and (#parts == 2 or #parts == 3)) then
          local filter = parts[1]
          local value = rule:gsub(filter..":", "")
          local is_port_based, port_based_rule = parsePortBasedRule(filter, value, line)

          if is_port_based then
            addRule(proto, port_based_rule)
          elseif(filter == "host") then
            -- possibly remove quotas
            value = value:gsub("^\"*(.-)\"*$", "%1")

            if not isEmptyString(value) then
              addRule(proto, {
                match = "host",
                value = value,
              })
            else
              traceError(TRACE_WARNING, TRACE_CONSOLE,
                string.format("[protos.txt] Ignoring bad host '%s' in rule: %s", value, line))
            end
          elseif(filter == "ip") then
            addRule(proto, {
              match = "ip",
              value = value,
            })
          else
            traceError(TRACE_WARNING, TRACE_CONSOLE,
              string.format("[protos.txt] Ignoring unknown filter '%s' in rule: %s", filter, line))
          end
        else
          traceError(TRACE_WARNING, TRACE_CONSOLE,
            string.format("[protos.txt] Ignoring bad rule: %s", line))
        end
      end
    else
      traceError(TRACE_WARNING, TRACE_CONSOLE,
        string.format("[protos.txt] Ignoring bad rule: %s", line))
    end
  end

  f:close()

  return rules, defined_protos
end

-- ##############################################

function protos_utils.hasProtosFile()
  return(not isEmptyString(getProtosFile()))
end

-- ##############################################

function protos_utils.getProtosTxtRule(line)
  line = trimString(line)

  if isIPv4(line) or http_lint.validateNetwork(line) then
     return {
	match = "ip",
	value = line
     }
  else
    local parts = string.split(line, ":")

    if((parts ~= nil) and (#parts == 2)) then
      local filter = parts[1]
      local value = parts[2]

      if tonumber(value) then
	 if isIPv4(filter) or http_lint.validateNetwork(filter) then
	    -- e.g., 8.248.73.247:443
	    -- e.g., 213.75.170.11/32:443
	    return {
	       match = "ip",
	       value = line
	    }
	 end
      end

      local is_port_based, port_based_rule = parsePortBasedRule(filter, value, line)

      if is_port_based then
        return port_based_rule
      end
    elseif not isEmptyString(line) then
      return {
        match = "host",
        value = line,
      }
    end
  end
end

-- ##############################################

function protos_utils.overwriteAppRules(app, rules)
  local current_rules, defined_protos = protos_utils.parseProtosTxt()

  if(current_rules == nil) or (type("app") ~= "string") then
    return false
  end

  if(not current_rules[app]) then
    -- This is a new app, append it to the end
    defined_protos[#defined_protos + 1] = app
  end

  current_rules[app] = rules
  return protos_utils.generateProtosTxt(current_rules, defined_protos)
end

-- ##############################################

function protos_utils.addAppRule(app, rule)
  local current_rules, defined_protos = protos_utils.parseProtosTxt()
  local app_rules

  if(current_rules == nil) or (type("app") ~= "string") then
    return false
  end

  app_rules = current_rules[app] or {}

  -- Uniqueness Check
  for _, existing_rule in pairs(app_rules) do
    if((existing_rule.match == rule.match) and (existing_rule.value == rule.value)) then
      return false
    end
  end

  if(not current_rules[app]) then
    -- This is a new app, append it to the end
    defined_protos[#defined_protos + 1] = app
  end

  app_rules[#app_rules + 1] = rule
  current_rules[app] = app_rules
  return protos_utils.generateProtosTxt(current_rules, defined_protos)
end

-- ##############################################

function protos_utils.deleteAppRules(app)
  local current_rules, defined_protos = protos_utils.parseProtosTxt()

  if(not current_rules[app]) then
    -- App does not exist
    return false
  end

  current_rules[app] = nil
  return protos_utils.generateProtosTxt(current_rules, defined_protos)
end

-- ##############################################

-- Generates a protos.txt file based on the supplied rules
-- The defined_protos is used to ensure that the protocols are written
-- in the specified order as nDPI assigns IDs sequentially and existing
-- IDs must not be changed.
function protos_utils.generateProtosTxt(rules, defined_protos)
  local path = getProtosFile()
  local backup_file = path .. ".bak"

  if(ntop.exists(path) and (not ntop.exists(backup_file))) then
    traceError(TRACE_INFO, TRACE_CONSOLE, string.format("Backing up '%s' to '%s'", path, backup_file))
    os.rename(path, backup_file)
  end

  local f = io.open(path, "w")

  if f == nil then
    traceError(TRACE_ERROR, TRACE_CONSOLE, string.format("[protos.txt] Could not open '%s' for write", path))
    return false
  end

  local function writeRule(rule)
    f:write(string.format("%s\n", rule))
  end

  -- Important: iterate by index to ensure that new protocols are always appended
  for _, proto in ipairs(defined_protos) do
    local proto_rules = rules[proto]

    if proto_rules then
      writeRule(string.format("# %s", proto))

      for _, rule in ipairs(proto_rules) do
        if rule.match == "port" then
          writeRule(string.format("%s@%s", rule.value, proto))
        elseif rule.match == "host" then
          writeRule(string.format("host:\"%s\"@%s", rule.value, proto))
        elseif rule.match == "ip" then
          writeRule(string.format("ip:%s@%s", rule.value, proto))
        end
      end

      writeRule("")
    end
  end

  f:close()
  return true
end

-- ##############################################

return(protos_utils)

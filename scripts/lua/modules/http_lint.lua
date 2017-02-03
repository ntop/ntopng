--
-- (C) 2017 - ntop.org
--

local pragma_once = 1

-- #################################################################

-- UTILITY FUNCTIONS

function validateChoiceByKeys(defaults, v)
   if defaults[v] ~= nil then
      return true
   else
      return false
   end
end

function validateChoice(defaults, v)
   for _,d in pairs(defaults) do
      if d == v then
         return true
      end
   end

   return false
end

function validateSingleWord(w)
   if ((string.find(w, "%=") ~= nil) or
       (string.find(w, "% ") ~= nil)) then
      return false
   else
      return true
   end
end

-- #################################################################

-- FRONT-END VALIDATORS

function validateNumber(p)
   if tonumber(p) ~= nil then
      return true
   else
      return false
   end
end

function validateUnchecked(p)
   -- base validation is already performed by C side.
   -- you should use this function as last resort
   return true
end

-- #################################################################

function validateMode(mode)
   local modes = {"all", "local", "remote"}

   return validateChoice(modes, mode)
end

function validateHttpMode(mode)
   local modes = {"responses", "queries"}

   return validateChoice(modes, mode)
end

function validatePidMode(mode)
   local modes = {"l4", "l7", "host", "apps"}

   return validateChoice(modes, mode)
end

function validateNdpiStatsMode(mode)
   local modes = {"sinceStartup", "count", "host"}

   return validateChoice(modes, mode)
end

function validateSflowDistroMode(mode)
   local modes = {"host", "process", "user"}

   return validateChoice(modes, mode)
end

function validateIfaceLocalStatsMode(mode)
   local modes = {"distribution"}

   return validateChoice(modes, mode)
end

function validateProcessesStatsMode(mode)
   local modes = {"table", "timeline"}

   return validateChoice(modes, mode)
end

function validateDirection(mode)
   local modes = {"sent", "recv"}

   return validateChoice(modes, mode)
end

function validateClientOrServer(mode)
   local modes = {"client", "server"}

   return validateChoice(modes, mode)
end

-- #################################################################

function validateIPv4IPv6Mac(p)
   -- TODO stricter checks
   if(isIPv4(p) or isIPv6(p) or isMacAddress(p)) then
      return true
   else
      return false
   end
end

function validateBool(p)
   if((p == "true") or (p == "false")) then
      return true
   else
      return false
   end
end

function validateSortOrder(p)
   local defaults = {"asc", "desc"}
   
   return validateChoice(defaults, p)
end

function validateApplication(app)
   local ndpi_protos = interface.getnDPIProtocols()

   return validateChoiceByKeys(ndpi_protos, app)
end

function validateSortColumn(p)
   if((validateSingleWord(p)) and (string.starts(p, "column_"))) then
      return true
   else
      return false
   end
end

function validateCountry(p)
   if string.len(p) == 2 then
      return true
   else
      return false
   end
end

function validateInterface(i)
   return validateNumber(i)
end

function validateIfFilter(i)
   if validateNumber(i) or i == "all" then
      return true
   else
      return false
   end
end

function validateTopModule(m)
   -- TODO check for existance
   return validateSingleWord(m)
end

-- #################################################################

-- NOTE: Put here al the parameters to validate

local known_parameters = {
-- FILTERING & STATUS
   ["application"]      =  validateApplication,           -- An nDPI application protocol name
   --~ ["mode"]         =  validateMode,                  -- Remote or Local users
   ["country"]          =  validateCountry,               -- Country code
   ["flow_key"]         =  validateNumber,                -- The ID of a flow hash
   ["pool"]             =  validateNumber,                -- A pool ID
   ["vlan"]             =  validateNumber,                -- A VLAN id
   ["host"]             =  validateIPv4IPv6Mac,           -- an IPv4 (optional @vlan), IPv6 (optional @vlan), or MAC address
   ["network"]          =  validateNumber,                -- A network ID
   ["ifid"]             =  validateInterface,             -- An ntopng interface ID
   --~ ["ifname"]       =  validateNumber,                -- NOTE: obsolete, but some scripts still depend on it (see et_host_info_ntopng.sh, read_metrics.lua)
   ["ifIdx"]            =  validateNumber,                -- A switch port id
   ["iffilter"]         =  validateIfFilter,              -- A network ID or 'all'
   ["epoch"]            =  validateNumber,                -- A timestamp value
   ["epoch_begin"]      =  validateNumber,                -- A timestamp value to indicate start time
   ["epoch_end"]        =  validateNumber,                -- A timestamp value to indicate end time
   ["http_mode"]        =  validateHttpMode,              -- HTTP mode for host_http_breakdown.lua
   ["pid_mode"]         =  validatePidMode,               -- pid mode for pid_stats.lua
   ["pid_name"]         =  validateSingleWord,            -- A process name
   ["pid"]              =  validateNumber,                -- A process ID
   ["breed"]            =  validateBool,                  -- True if nDPI breed should be shown
   ["ndpistats_mode"]   =  validateNdpiStatsMode,         -- A mode for iface_ndpi_stats.lua
   ["user"]             =  validateSingleWord,            -- A ntopng user name
   ["sflowdistro_mode"] =  validateSflowDistroMode,       -- A mode for host_sflow_distro
   ["iflocalstat_mode"] =  validateIfaceLocalStatsMode,   -- A mode for iface_local_stats.lua
   ["procstats_mode"]   =  validateProcessesStatsMode,    -- A mode for processes_stats.lua
   ["direction"]        =  validateDirection,             -- Sent or Received direction
   ["clisrv"]           =  validateClientOrServer,        -- Client or Server filter

-- PAGINATION
   ["perPage"]          =  validateNumber,                -- Number of results per page (used for pagination)
   ["sortOrder"]        =  validateSortOrder,             -- A sort order
   ["sortColumn"]       =  validateSortColumn,            -- A sort column
   ["currentPage"]      =  validateNumber,                -- The currently displayed page number (used for pagination)

-- AGGREGATION
   ["grouped_by"]       =  validateSingleWord,            -- A group criteria

-- NAVIGATION
   ["page"]             =  validateSingleWord,            -- Currently active subpage tab
   ["tab"]              =  validateSingleWord,            -- Currently active tab, handled by javascript

-- OTHER
   ["_"]                =  validateNumber,                -- jQuery nonce in ajax requests used to prevent browser caching
   ["referer"]          =  validateUnchecked,             -- An URL referer
   ["module"]           =  validateTopModule,             -- A top script module
   ["addvlan"]          =  validateBool,                  -- True if VLAN must be added to the result

--
   --~ ["id"]           =  validateNumber,                -- NOTE: obsolete modify to ifid in all scripts
   
   
   
   --~ ["num_minutes"]  =  validateNumber,                --
   --~ ["long_names"]   =  validateNumber,                -- 
   --~ ["period_begin"] =  validateNumber,                --
   --~ ["period_end"]   =  validateNumber,                --
   --~ ["period_mins"]  =  validateNumber,                --
   --~ ["label"]        =  validateUnchecked,             --
   
   
   --~ ["group_by"]     =  validateUnchecked,             --
   --~ ["distr"]        =  validateUnchecked,             --
   --~ ["format"]       =  validateUnchecked,             --
   --~ ["criteria"]     =  validateUnchecked,             --
   
   --~ ["host_type"]    =  validateUnchecked,             -- 
   --~ ["hosts_type"]   =  validateUnchecked,             --
   
}

-- #################################################################

function validateParameter(k, v)
   if(known_parameters[k] == nil) then
      io.write("[LINT] Missing validation for ["..k.."]["..v.."]\n")
      return false
   else
      return known_parameters[k](v)
   end
end

-- #################################################################

function lintParams()
   local params_to_validate = { _GET, _POST }
   local id, p, k, v
   local debug = false
   local disableValidation = true -- <<<=== ENABLE HERE
   
   for id,p in pairs(params_to_validate) do
      for k,v in pairs(p) do
         if(debug) then io.write("[LINT] Validating ["..k.."]["..p[k].."]\n") end

         if not(disableValidation) then
            if not validateParameter(k, v) then
               -- TODO gracefull error
               error("BAD parameter " .. k .. " [" .. v .. "]")
            end
         end
      end
   end
end

-- #################################################################

if(pragma_once) then
   lintParams()
   pragma_once = 0
end

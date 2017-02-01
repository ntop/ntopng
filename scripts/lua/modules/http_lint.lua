--
-- (C) 2017 - ntop.org
--

local pragma_once = 1

-- #################################################################

function validateNumber(p)
   return(tonumber(p))
end

-- Remove all chars after % (if any)
function validateString(p)
   local percent = string.find(p, "%%")

   if(percent == nil) then
      return(p)
   else
      return(string.sub(p, 1, percent-1))
   end
end

function validateMode(p)
   -- some code
   return p
end

function validateNumberAsString(p)
   return(tostring(tonumber(p)).."")
end

function validateIPv4IPv6Mac(p)
   if(isIPv4(p) or isIPv6(p) or isMacAddress(p)) then
      return(p)
   else
      return("")
   end
end

function validateBool(p)
   if(p == "true") then
      return(p)
   else      
      return("false")
   end
end

function validateSortOrder(p)
   local defaults = { "asc", "desc" }
   
   return(validateDefaultValue(defaults, p))
end

function validateDefaultValue(defaults, v)
   if(defaults[v] ~= nil) then
      return(v)
   else
      return(defaults[1])
   end
end

function validateSortColumn(p)
   if(string.starts(p, "column_")) then
      return(p)
   else
      io.write("*** validateSortColumn() = "..p.."\n")
      return("column_ip")
   end
end

function validateCountry(p)
   return(string.sub(validateString(p), 1, 2))
end

-- #################################################################

-- NOTE: Put here al the parameters to validate

local known_parameters = {
   ["ifname"]       =  validateNumber, -- NOTE: obsolete modify to ifid in all scripts
   ["ifid"]         =  validateNumber,
   ["id"]           =  validateNumber,
   ["epoch"]        =  validateNumber,
   ["network"]      =  validateNumber,
   ["ifname"]       =  validateNumberAsString,
   ["perPage"]      =  validateNumber,
   ["flow_key"]     =  validateNumber,
   ["num_minutes"]  =  validateNumber,
   ["pool"]         =  validateNumber,
   ["long_names"]   =  validateNumber,
   ["period_begin"] =  validateNumber,
   ["period_end"]   =  validateNumber,
   ["period_mins"]  =  validateNumber,   
   ["host"]         =  validateIPv4IPv6Mac,
   ["_"]            =  validateNumber,
   ["vlan"]         =  validateNumber,
   ["sortOrder"]    =  validateSortOrder,
   ["sortColumn"]   =  validateSortColumn,
   ["currentPage"]  =  validateNumber,
   ["mode"]         =  validateMode,
   ["country"]      =  validateCountry,
   ["breed"]        =  validateBool,
   ["label"]        =  validateString,
   ["page"]         =  validateString,
   ["grouped_by"]   =  validateString,
   ["page"]         =  validateString,
   ["distr"]        =  validateString,
   ["format"]       =  validateString,
   ["criteria"]     =  validateString,
   ["member"]       =  validateString,
   ["status"]       =  validateString,
   ["tab"]          =  validateString,
   ["host_type"]    =  validateString,
   ["group_by"]     =  validateString,
   ["hosts_type"]   =  validateString,
}

-- #################################################################

local function validateParameter(k, v)
   if(known_parameters[k] == nil) then      
      io.write("Missing validation for ["..k.."]["..v.."]\n")
      return(v)
   else
      return(known_parameters[k](v))
   end
end

-- #################################################################

local function lintParams()
   local params_to_validate = { _GET, _POST }
   local id, p, k, v
   local debug = false
   local disableValidation = true -- <<<=== ENABLE HERE
   
   for id,p in pairs(params_to_validate) do
      for k,v in pairs(p) do
	 if(debug) then io.write("[LINT] Validating ["..k.."]["..p[k].."]\n") end
	 if(not(disableValidation)) then p[k] = validateParameter(k, v) end
	 if(debug) then io.write("[LINT] ["..k.."]["..p[k].."]\n") end
      end
   end
end

-- #################################################################

if(pragma_once) then
   lintParams()
   pragma_once = 0
end

--
-- (C) 2013 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

if(isAdministratorOrPrintErr()) then
local currentPage     = _GET["currentPage"]
local perPage         = _GET["perPage"]
local sortColumn      = _GET["sortColumn"]
local sortOrder       = _GET["sortOrder"]
local captivePortal   = _GET["captive_portal_users"]

local logged_user = _SESSION["user"]

local host_pools_nedge = nil
local pool_names = nil
if captivePortal then
   local host_pools_nedge = require "host_pools_nedge"
   local names = host_pools_nedge.getPoolsList(false)
   pool_names = {}
   for _, p in pairs(names) do
      pool_names[tonumber(p["id"])] = p["name"]
   end
end

if(sortColumn == nil) then
  sortColumn = "column_"
end

if(currentPage == nil) then
   currentPage = 1
else
   currentPage = tonumber(currentPage)
end

if(perPage == nil) then
   perPage = 5
else
   perPage = tonumber(perPage)
end

local users_list = ntop.getUsers()

print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
local num = 0
local total = 0
local to_skip = (currentPage-1) * perPage

local vals = {}
for key, value in pairs(users_list) do
   if captivePortal and ((value["group"] ~= "captive_portal") or (value["allowed_ifname"] ~= ifname)) then
      goto continue
   elseif not captivePortal and value["group"] == "captive_portal" then
      goto continue
   end

   if(sortColumn == "column_full_name") then
      vals[key] = value["full_name"]
   elseif(sortColumn == "column_group") then
      vals[key] = value["group"]
   elseif(pool_names and sortColumn == "column_host_pool_name") then
      local pool_n = pool_names[tonumber(value["host_pool_id"])]
      vals[key] = pool_n
   else -- if(sortColumn == "column_username") then
      vals[key] = key
   end
   ::continue::
end

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

local num = 0
for _key, _value in pairsByValues(vals, funct) do
   local key = _key
   local value = users_list[_key]
   local js_key = _key:gsub("%.", "\\\\\\\\.")

   if(to_skip > 0) then
      to_skip = to_skip-1
   else
      if(num < perPage) then
	 if(num > 0) then
	    print ",\n"
	 end

	 print ("{")
	 print ("  \"column_username\"  : \"" .. key .. "\", ")
	 print ("  \"column_full_name\" : \"" .. value["full_name"] .. "\", ")

	 if pool_names and value["host_pool_id"] then
	    print ("  \"column_host_pool_id\" : \"" .. value["host_pool_id"] .. "\", ")
	    print ("  \"column_host_pool_name\" : \"" .. pool_names[value["host_pool_id"]].. "\", ")
	 end

local group_label

if value["group"] == "administrator" then
   group_label = i18n("manage_users.administrator")
elseif value["group"] == "unprivileged" then
   group_label = i18n("manage_users.non_privileged_user")
else
   group_label = value["group"]
end

	 print ("  \"column_group\"     : \"" .. group_label .. "\", ")
	 print ("  \"column_edit\"      : \"<a href='#password_dialog' class='btn btn-sm btn-info' data-bs-toggle='modal' onclick='return(reset_pwd_dialog(\\\"".. js_key.."\\\"));'><i class='fas fa-edit'></i></a> ")
   
    local can_be_deleted = (key ~= "admin" and key ~= logged_user)

    print ("<a href='#delete_user_dialog' role='button' class='add-on btn btn-sm btn-danger ".. (not can_be_deleted and 'disabled' or '') .."' data-bs-toggle='modal' id='delete_btn_" .. key .. "'><i class='fas fa-trash'></i></a><script> $('#delete_btn_" .. js_key .. "').on('mouseenter', function() { delete_user_alert.warning('" .. i18n("manage_users.confirm_delete_user", {user=key}) .. "'); $('#delete_dialog_username').val('" .. key .. "'); }); </script>")

	 print ("\"}")
	 num = num + 1
      end
   end

   total = total + 1
end -- for


print ("\n], \"perPage\" : " .. perPage .. ",\n")

if(sortColumn == nil) then
   sortColumn = ""
end

if(sortOrder == nil) then
   sortOrder = ""
end

print ("\"sort\" : [ [ \"" .. sortColumn .. "\", \"" .. sortOrder .."\" ] ],\n")

print ("\"totalRows\" : " .. total .. " \n}")
end

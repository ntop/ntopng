--
-- (C) 2013 - ntop.org
--

dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"

sendHTTPHeader('application/json')

if(haveAdminPrivileges()) then
currentPage     = _GET["currentPage"]
perPage         = _GET["perPage"]
sortColumn      = _GET["sortColumn"]
sortOrder       = _GET["sortOrder"]

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

users_list = ntop.getUsers()

print ("{ \"currentPage\" : " .. currentPage .. ",\n \"data\" : [\n")
num = 0
total = 0
to_skip = (currentPage-1) * perPage

vals = {}
num = 0
for key, value in pairs(users_list) do
    num = num + 1
    postfix = string.format("0.%04u", num)

    if(sortColumn == "column_full_name") then
      vals[users_list[key]["full_name"]..postfix] = key
    elseif(sortColumn == "column_group") then
      vals[users_list[key]["group"]..postfix] = key
    else -- if(sortColumn == "column_username") then
      vals[key] = key
   end
end

table.sort(vals)

if(sortOrder == "asc") then
   funct = asc
else
   funct = rev
end

num = 0
for _key, _value in pairsByKeys(vals, funct) do
   key = vals[_key]   
   value = users_list[key]

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
	 print ("  \"column_group\"     : \"" .. value["group"] .. "\", ")
	 print ("  \"column_edit\"      : \"<a href='#password_dialog' data-toggle='modal' onclick='return(reset_pwd_dialog(\\\"".. key.."\\\"));'><span class='label label-info'>Manage</span></a> ")

  if(key ~= "admin") then
	    print ("<a href='#delete_user_dialog' role='button' class='add-on' data-toggle='modal' id='delete_btn_" .. key .. "'><span class='label label-danger'>Delete</span></a><script> $('#delete_btn_" .. key .. "').on('mouseenter', function() { delete_user_alert.warning('Are you sure you want to delete " .. key .. "?'); $('#delete_dialog_username').val('" .. key .. "'); }); </script>")
	 end
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
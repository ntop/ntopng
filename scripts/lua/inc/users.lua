local captive_portal_btn = ""

local get_users_url = ntop.getHttpPrefix().."/lua/admin/get_users.lua"
local users_type = {ntopng=ternary(ntop.isnEdge(), i18n("nedge.system_users"), i18n("login.web_users")), captive_portal=i18n("bridge_wizard.captive_portal_users")}

local title = users_type["ntopng"]
local captive_portal_users = false
if is_captive_portal_active then
   if _GET["captive_portal_users"] ~= nil then
      captive_portal_users = true
      title = users_type["captive_portal"]
      get_users_url = get_users_url.."?captive_portal_users=1"
   end

   local url = ntop.getHttpPrefix().."/lua/admin/users.lua"
   -- prepare a button to manage captive portal users
   captive_portal_btn = "<div class='btn-group'><button class='btn btn-link dropdown-toggle' data-toggle='dropdown'>" .. i18n("manage_users.web_captive_users") .. "<span class='caret'></span></button> <ul class='dropdown-menu' role='menu'>"
   captive_portal_btn = captive_portal_btn.."<li><a href='"..url.."'>"..users_type["ntopng"].."</a></li>"
   captive_portal_btn = captive_portal_btn.."<li><a href='"..url.."?captive_portal_users=1'>"..users_type["captive_portal"].."</a></li>"
   captive_portal_btn = captive_portal_btn.."</ul></div>"
end

print [[

      <hr>

      <div id="table-users"></div>
	 <script>
	 $("#table-users").datatable({
		url: "]]
print (get_users_url)
print [[",
		showPagination: true,
		title: "]] print(title) print[[",
		buttons: [
			"]] print(captive_portal_btn) print[[<a href='#add_user_dialog' role='button' class='add-on btn' data-toggle='modal'><i class='fa fa-user-plus fa-sm'></i></a>"
		],
		columns: [
			{
				title: "]] print(i18n("login.username")) print[[",
				field: "column_username",
				sortable: true,
				css: {
					textAlign: 'left'
				}
			},
			{
				title: "]] print(i18n("users.full_name")) print[[",
				field: "column_full_name",
				sortable: true,
				css: {
					textAlign: 'left'
				}

			},
]]

if captive_portal_users == false then

print[[
			{
				title: "]] print(i18n("manage_users.group")) print[[",
				field: "column_group",
				sortable: true,
				css: {
					textAlign: 'center'
				}
			},
]]

else
print[[
			{
				title: "]] print(i18n("manage_users.host_pool_id")) print[[",
				field: "column_host_pool_id",
				hidden: true
			},
			{
				title: "]] print(i18n("host_config.host_pool")) print[[",
				field: "column_host_pool_name",
				sortable: true,
				css: {
					textAlign: 'center'
				}
			},
]]

end

print[[
			{
				title: "]] print(i18n("users.edit")) print[[",
				field: "column_edit",
				css: {
					textAlign: 'center'
				}
			},
		]
	 });
	 </script>

   ]]

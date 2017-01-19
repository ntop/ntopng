local captive_portal_btn = ""

local get_users_url = ntop.getHttpPrefix().."/lua/admin/get_users.lua"
local users_type = {ntopng="ntopng Users", captive_portal="Captive Portal Users"}

local title = users_type["ntopng"]
if is_bridge_iface and is_captive_portal_enabled then
   if _GET["captive_portal_users"] ~= nil then
      title = users_type["captive_portal"]
      get_users_url = get_users_url.."?captive_portal_users=1"
   end

   local url = ntop.getHttpPrefix().."/lua/admin/users.lua"
   -- prepare a button to manage captive portal users
   captive_portal_btn = "<div class='btn-group'><button class='btn btn-link dropdown-toggle' data-toggle='dropdown'>Users Type<span class='caret'></span></button> <ul class='dropdown-menu' role='menu'>"
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
				title: "Username",
				field: "column_username",
				sortable: true,
	 	        	css: { 
					textAlign: 'left'
				}
			},
			{
				title: "Full Name",
				field: "column_full_name",
				sortable: true,
	 	        	css: { 
					textAlign: 'left'
				}

			},			     
			{
				title: "Group",
				field: "column_group",
				sortable: true,
	 	        	css: { 
					textAlign: 'center'
				}
			},
                        {
                        	title: "Edit",
                        	field: "column_edit",
                        	css: {
                        		textAlign: 'center'
                        	}
                       	},
		]
	 });
         </script>

   ]]

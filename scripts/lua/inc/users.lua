local page_utils = require("page_utils")
local get_users_url = ntop.getHttpPrefix().."/lua/admin/get_users.lua"
local users_type = {ntopng=ternary(ntop.isnEdge(), i18n("nedge.system_users"), i18n("login.web_users"))}

local title = users_type["ntopng"]

page_utils.print_page_title(title)


print [[
    <div id="table-users"></div>
	 <script>
	 $("#table-users").datatable({
		url: "]]
print (get_users_url)
print [[",
		showPagination: true,
		title: "",
		buttons: [
			"<a href='#add_user_dialog' role='button' class='add-on btn' data-bs-toggle='modal'><i class='fas fa-plus fa-sm'></i></a>"
		],
		tableCallback: function() {

			// if there is `user` get param then open the user's modal
			let user = "]] print(_GET["user"]) print [[";
			if (user !== "nil" && isAdministrator) {

				reset_pwd_dialog(user);
				// set the preference tab
				$(`#change-password-dialog`).removeClass('active');
				$(`a[href='#change-password-dialog']`).removeClass('active');
				$(`#li_change_prefs > a`).addClass('active');
				$(`#change-prefs-dialog`).tab('show');
				// show the modal
				$(`#password_dialog`).modal('show');
			}

		},
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
			{
				title: "]] print(i18n("manage_users.group")) print[[",
				field: "column_group",
				sortable: true,
				css: {
					textAlign: 'center'
				}
			},
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

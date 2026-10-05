local page_utils = require("page_utils")
local get_users_url = ntop.getHttpPrefix().."/lua/admin/get_users.lua"
local users_type = {ntopng=ternary(ntop.isnEdge and ntop.isnEdge(), i18n("nedge.system_users"), i18n("login.web_users"))}
local is_admin = isAdministrator()

-- Non administrators only get their own profile back (see admin/get_users.lua)
local title = ternary(is_admin, users_type["ntopng"], i18n("manage_users.manage_user_x", {user = _SESSION["user"]}))

page_utils.print_page_title(title)


print [[
    <div id="table-users"></div>
	 <script>
   $(document).ready(async function() {
    $("#table-users").datatable({
      url: "]]
  print (get_users_url)
  print [[",
      showPagination: true,
      title: "",
      buttons: []]
  if is_admin then
     print [["<a href='#add_user_dialog' role='button' class='add-on btn' data-bs-toggle='modal'><i class='fas fa-plus fa-sm'></i></a>"]]
  end
  print [[],
      tableCallback: function() {
  
        // if there is `user` get param then open the user's modal
        let user = "]] print(js_str(_GET["user"] or "")) print [[";
        if (user !== "") {
  
          reset_pwd_dialog(user);
          // select the preferences tab (must be done on the tab link, Bootstrap
          // throws when the API is used on the pane itself)
          $(`a[href='#change-prefs-dialog']`).tab('show');
          // show the modal
          $(`#password_dialog`).modal('show');
        }
  
      },
      columns: [
        {
          title: "]] print(js_str(i18n("login.username"))) print[[",
          field: "column_username",
          sortable: true,
          css: {
            textAlign: 'left'
          }
        },
        {
          title: "]] print(js_str(i18n("users.full_name"))) print[[",
          field: "column_full_name",
          sortable: true,
          css: {
            textAlign: 'left'
          }
  
        },
        {
          title: "]] print(js_str(i18n("manage_users.group"))) print[[",
          field: "column_group",
          sortable: true,
          css: {
            textAlign: 'center'
          }
        },
        {
          title: "]] print(js_str(i18n("users.edit"))) print[[",
          field: "column_edit",
          css: {
            textAlign: 'center'
          }
        },
      ]
     });  
   })
	 	 </script>

   ]]

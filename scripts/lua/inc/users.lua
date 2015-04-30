
print [[

      <hr>

      <div id="table-users"></div>
	 <script>
	 $("#table-users").datatable({
	 	url: "]]
print (ntop.getHttpPrefix())
print [[/lua/admin/get_users.lua",
	 	showPagination: true,
	 	title: "Users",
		buttons: [
			"<a href='#add_user_dialog' role='button' class='add-on btn' data-toggle='modal'><i class='fa fa-user-plus fa-lg'></i></a>"
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

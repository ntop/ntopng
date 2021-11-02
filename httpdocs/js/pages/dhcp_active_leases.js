// 2021 - ntop.org

/* ******************************************************* */

$(function () {
    // initialize script table
    const $script_table = $("#dhcp-active-leases").DataTable({
	dom: "Bfrtip",
	pagingType: 'full_numbers',
	language: {
	    info: i18n.showing_x_to_y_rows,
	    search: i18n.script_search,
	    infoFiltered: "",
	    paginate: {
		previous: '&lt;',
		next: '&gt;',
		first: '«',
		last: '»'
	    }
	},
	lengthChange: false,
	ajax: {
	    url: `${http_prefix}/lua/pro/rest/v2/get/nedge/dhcp_active_leases.lua`,
	    type: 'get',
	    dataSrc: 'rsp',
	    data: {},
	},
	stateSave: true,
	initComplete: function (settings, json) {
	},
	order: [[0, "asc"]],
	buttons: {
	    buttons: [
		{
		    text: '<i class="fas fa-sync"></i>',
		    className: 'btn-link',
		    action: function (e, dt, node, config) {
			$script_table.ajax.reload(function () {
			}, false);
		    }
		}
	    ],
	    dom: {
		button: {
		    className: 'btn btn-link'
		},
		container: {
		    className: 'border-start ms-1 float-end'
		}
	    }
	},
	columns: [
	    {
		data: 'mac',
	    },
	    {
		data: 'mac_manufacturer',
	    },
	    {
		data: 'leased_ip',
		type: 'ip-address',
		width: '20%',
	    },
	    {
		data: 'leased_ip_name',
		sortable: true,
		searchable: true,
		width: '20%',
	    },
	]
    });
});

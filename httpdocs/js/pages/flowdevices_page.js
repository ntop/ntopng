$(function () {
    const TABLE_DATA_REFRESH = 15000;

    let dtConfig = DataTableUtils.getStdDatatableConfig([
		{
			text: '<i class="fas fa-sync"></i>',
            className: 'btn-link',
			action: () => {
				$flowdevicesList.ajax.reload();
			}
		}
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/pro/rest/v2/get/flowdevices/stats.lua`, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
	columns: [
	    {
		data: 'column_ip'
	    },
	    {
		data: 'column_chart',
		className: "text-center",
		width: "15%",
	    },
	    {
		data: 'column_name'
	    },
	    {
		data: 'column_descr'
	    },
	    {
		data: 'column_location'
	    },
	],
	initComplete: function (settings, json) {
	}
    });

    const $flowdevicesList = $(`table#flowdevices-list`).DataTable(dtConfig);
});

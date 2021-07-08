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
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/pro/rest/v2/get/observation_points/stats.lua`, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
	columns: [
	    {
			data: 'column_name'
	    },
	    {
			data: 'column_chart',
			className: "text-center",
			width: "15%",
	    },
	    {
			data: 'column_tot_flows'
	    },
	    {
			data: 'column_tot_bytes'
	    },
	],
	initComplete: function (settings, json) {
	}
    });

    const $flowdevicesList = $(`table#observation_points-list`).DataTable(dtConfig);
});

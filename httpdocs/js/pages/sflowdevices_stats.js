$(document).ready(function () {
    const TABLE_DATA_REFRESH = 15000;

    let dtConfig = DataTableUtils.getStdDatatableConfig([
	{
	}
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/pro/rest/v1/get/sflowdevices/stats.lua`);
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

    const $recipientsTable = $(`table#sflowdevices-list`).DataTable(dtConfig);
});

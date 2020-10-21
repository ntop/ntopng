$(document).ready(function () {
    const TABLE_DATA_REFRESH = 15000;

    let dtConfig = DataTableUtils.getStdDatatableConfig([
	{
	}
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/pro/rest/v1/get/flowdevice/stats.lua?ip=${flow_device_ip}`);
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
	columns: [
	    {
		data: 'ifindex'
	    },
	    {
		data: 'name'
	    },
	    {
		data: 'chart'
	    },
	    {
		data: 'in_bytes'
	    },
	    {
		data: 'out_bytes'
	    },
	    {
		data: 'ratio'
	    },
	],
	initComplete: function (settings, json) {
	}
    });

    const $flowdeviceTable = $(`table#flowdevice-list`).DataTable(dtConfig);
});

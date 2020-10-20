$(document).ready(function () {
    const TABLE_DATA_REFRESH = 15000;

    let dtConfig = DataTableUtils.getStdDatatableConfig([
	{
	}
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/pro/rest/v1/get/sflowdevice/stats.lua?ip=${flow_device_ip}`);
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
		data: 'iftype'
	    },
	    {
		data: 'speed'
	    },
	    {
		data: 'duplex'
	    },
	    {
		data: 'status'
	    },
	    {
		data: 'promisc'
	    },
	    {
		data: 'in_bytes'
	    },
	    {
		data: 'out_bytes'
	    },
	    {
		data: 'in_errors'
	    },
	    {
		data: 'out_errors'
	    },
	    {
		data: 'snmp_ratio'
	    },
	],
	initComplete: function (settings, json) {
	}
    });

    const $sflowdeviceTable = $(`table#sflowdevice-list`).DataTable(dtConfig);
});

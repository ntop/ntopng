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
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/pro/rest/v2/get/interface/observation_points/stats.lua`, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
	columns: [
	    {
			data: 'column_name'
	    },
	    {
			data: 'column_chart',
			className: "text-center",
			orderable: false,
			width: "15%",
	    },
	    {
			data: 'column_curr_hosts'
	    },
	    {
			data: 'column_curr_througput',
			render: (througput, type) => {
	        if (type !== 'display') return througput;
	        if (througput !== undefined) {
	          return NtopUtils.fbits(througput);
	      }},
		},
	    {
			data: 'column_tot_bytes',
			render: (bytes, type) => {
	        if (type !== 'display') return bytes;
	        if (bytes !== undefined) {
	          return NtopUtils.bytesToSize(bytes);
	      }},
	    },
	],
	initComplete: function (settings, json) {
	}
    });

    const $flowdevicesList = $(`table#observation_points-list`).DataTable(dtConfig);
});

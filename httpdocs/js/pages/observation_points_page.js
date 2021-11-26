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
			width: "10%"
	    },
	    {
			data: 'column_curr_hosts',
			className: "text-center",
			orderable: true,
			width: "10%",
			render: (cur_hosts, type) => {
			    if (type !== 'display') return cur_hosts;
			    if (cur_hosts !== undefined && cur_hosts > 0) {
				return NtopUtils.fint(cur_hosts);
			    }
			},
	    },
	    {
			data: 'column_curr_througput',
			className: "text-center",
			orderable: true,
			width: "15%",
			render: (througput, type) => {
			    if (type !== 'display') return througput;
			    if (througput !== undefined && througput > 0) {
				return NtopUtils.fbits(througput * 8);
			    }
			},
		},
	    {
			data: 'column_tot_bytes',
			className: "text-center",
			orderable: true,
			width: "15%",
			render: (bytes, type) => {
			    if (type !== 'display') return bytes;
			    if (bytes !== undefined && bytes > 0) {
				return NtopUtils.bytesToSize(bytes);
			    }
			},
	    },
	],
	initComplete: function (settings, json) {
	}
    });

    const $flowdevicesList = $(`table#observation_points-list`).DataTable(dtConfig);
});

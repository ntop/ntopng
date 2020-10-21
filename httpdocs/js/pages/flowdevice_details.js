$(document).ready(function () {

    const TABLE_DATA_REFRESH = 15000;

	const generateColumns = () => {

		const columns = [
			{
				data: 'ifindex',
				width: '10%',
				render: (ifindex, type) => {
					if (type == "display") {
						return `<a href='${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${flowDeviceIP}&snmp_port_idx=${ifindex}'>${ifindex}</a>`;
					}
					return ifindex;
				}
			},
			{
				data: 'name'
			},
			{
				data: 'chart',
				width: '10%',
				className: 'text-center',
			},
			{
				data: 'in_bytes',
				className: 'text-right',
				width: '15%',
				render: jQuery.fn.dataTableExt.sortBytes,
			},
			{
				data: 'out_bytes',
				className: 'text-right',
				width: '15%',
				render: jQuery.fn.dataTableExt.sortBytes,
			},
		]

		// if ratio is available then add the ratio column
		if (isRatioAvailable) {
			columns.push({
				data: 'ratio',
				className: 'text-center',
				width: '15%',
				render: (ratio, type) => {
					
					const THRESHOLD_VALUE = 0.8;

					if (type == "display" && ratio == -1) {
						return i18n.flow_devices.ratio_not_ready;
					}

					if (type == "display") {
						
						const pctg = (ratio * 100).toFixed(2);
						const pbClass = (ratio <= THRESHOLD_VALUE) ? 'bg-danger' : 'bg-success';

						return `
							<div class='progress position-relative'>
								<div style='width: ${pctg}%' role='progressbar' class='progress-bar ${pbClass}'>
								</div>
								<span class="justify-content-center d-flex position-absolute w-100">${(pctg > 100) ? "> 100" : pctg}%</span>
							</div>
						`;
					}

					return ratio;
				}
			});
		}

		return columns;
	}

    let dtConfig = DataTableUtils.getStdDatatableConfig();
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/pro/rest/v1/get/flowdevice/stats.lua?ip=${flowDeviceIP}`);
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
	columns: generateColumns(),
	initComplete: function (settings, json) {
		setInterval(() => {
			$flowdeviceTable.ajax.reload();
		}, TABLE_DATA_REFRESH);
	}
    });

    const $flowdeviceTable = $(`table#flowdevice-list`).DataTable(dtConfig);
});

/**
 * (C) ntop.org - 2021
 */
/**
 * (C) 2020 - ntop.org
 *
 * This script implements the logic for the overview tab inside snmpdevice_stats.lua page.
 */
$(function () {
    let dtConfig = DataTableUtils.getStdDatatableConfig([
	{
	    text: '<i class="fas fa-sync"></i>',
	    className: 'btn-link',
	    action: () => {
		$nProbesTable.ajax.reload();
	    }
	}
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/rest/v2/get/interface/nprobes/data.lua?ifid=${ifid}`, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
	columns: [
	    {
		data: "column_nprobe_probe_ip",
		width: '15%', className: 'text-nowrap',
		render: function (data, type, row) {
		    if (type == "sort" || type == "type") {
			return $.fn.dataTableExt.oSort["ip-address-pre"](data);
		    }

		    return data;
		}
	    },
	    {
		data: "column_nprobe_probe_public_ip",
		width: '10%', className: 'text-nowrap',
		render: function (data, type, row) {
		    if (type == "sort" || type == "type") {
			return $.fn.dataTableExt.oSort["ip-address-pre"](data);
		    }

		    return data;
		}
	    },
	    {
		data: "column_nprobe_interface",
		width: '15%', className: 'text-nowrap'
	    },
	    {
		data: "column_nprobe_version",
		width: '15%', className: 'text-nowrap'
	    },
	    {
		data: "column_nprobe_edition",
		width: '15%', className: 'text-nowrap'
	    },
	    {
		data: "column_nprobe_license",
		width: '15%', className: 'text-nowrap'
	    },
	    {
		data: "column_nprobe_maintenance",
		width: '15%', className: 'text-nowrap',
		orderable: false,
	    },
	],
	stateSave: true,
	hasFilters: true,
	initComplete: function(settings, json) {
	}
    });

    // initialize the DataTable with the created config
    const $nProbesTable = $(`#table-interface-probes`).DataTable(dtConfig);
    DataTableUtils.addToggleColumnsDropdown($nProbesTable);
});

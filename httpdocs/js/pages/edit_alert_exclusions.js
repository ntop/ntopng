// 2022 - ntop.org

/* ******************************************************* */

/* Modal handling the delete action on a single exclusion */
const $deleteAlertExclusion = $('#modal-script form').modalHandler({
    method: 'post',
    csrf: pageCsrf,
    endpoint: `${http_prefix}/lua/pro/rest/v2/delete/alert/exclude_alert.lua`,
    beforeSumbit: function (exclusionData) {
		const subdir = exclusionData.subdir;
		const alert_addr = $('#alert_addr').val();
		const alert_key = $('#alert_key').val();

        return { ifid: "{{ ifid }}", alert_addr: alert_addr, alert_key: alert_key, subdir: subdir };
    },
    onModalInit: function (exclusionData) {
		const alert_key = exclusionData.alert_key;
		const script_title = exclusionData.title;
		const excluded_host = exclusionData.excluded_host;

		// change title to modal
		$("#script-name").html(script_title);
		$('#script-description').html(excluded_host);

		// Add alert key and excluded host as hidden values
		$('#alert_key').val(alert_key);
		$('#alert_addr').val(excluded_host);
    },
    onSubmitSuccess: function (response, dataSent) {
		location.reload();
	}
});

/* ******************************************************* */

$(function () {    
	// initialize script table
    const datatableButton = [];

	/* Manage the buttons close to the search box */
	datatableButton.push({
		text: '<i class="fas fa-plus"></i>',
		className: 'btn-link',
		action: function (e, dt, node, config) {
			$(`#add-exclusion-modal`).modal('show');
		}
	});

    datatableButton.push({
		text: '<i class="fas fa-sync"></i>',
		className: 'btn-link',
		action: function (e, dt, node, config) {
			$script_table.ajax.reload(function () {}, false);
		}
	});

	/* Create a datatable with the buttons */
	let config = DataTableUtils.getStdDatatableConfig(datatableButton);
	
	/* Extend the configuration with the desired options */
    config = DataTableUtils.extendConfig(config, {
        serverSide: false,
        searching: true,
		order: [[0, "asc"]],
        pagingType: 'full_numbers',
		columnDefs: {},
		ajax: {
			method: 'get',
			url: `${http_prefix}/lua/pro/rest/v2/get/alert/exclusions.lua`,
			dataSrc: 'rsp',
            beforeSend: function() {
                showOverlays();
            },
            complete: function() {
                hideOverlays();
            }
        },
        columns: [
			{
				width: '100%',
				data: 'title',
				responsivePriority: 1,
				render: function (data, type, row) {
					if (type == 'display') return `<b>${data}</b>`;
					return data;
				},
			},{
				sortable: true,
				searchable: true,
				visible: true,
				className: 'text-center text-nowrap',
				data: 'subdir',
				responsivePriority: 2,
				render: function (data, type, row) {
					return `${i18n[row.subdir]}`;
				}
			},{
				data: null,
				sortable: true,
				searchable: true,
				className: 'text-center text-nowrap',
				responsivePriority: 2,
				render: function (data, type, row) {
					const icon = (!row.category_icon) ? '' : `<i class='fa ${row.category_icon}'></i>`;
					if (type == "display") return `${icon}`;
					return row.category_title;
				}
			},{
				sortable: false,
				searchable: false,
				visible: false,
				data: 'excluded_host',
				type: 'ip-address',
				responsivePriority: 2,
			},{
				data: 'excluded_host_label',
				type: 'ip-address',
				className: 'text-nowrap',
				responsivePriority: 2,
			},{
				data: 'excluded_host_name',
				sortable: true,
				searchable: true,
				className: 'text-nowrap',
				responsivePriority: 2,
			},{
				targets: -1,
				data: null,
				name: 'actions',
				className: 'text-center text-nowrap',
				sortable: false,
				responsivePriority: 1,
				render: function (data, type, script) {
					return DataTableUtils.createActionButtons([
						{ class: `btn-danger`, modal: '#modal-script', icon: 'fa-trash', title: `${i18n.delete}` },
					]);
				},
			}
		],
    });

	const $script_table = $("#scripts-config").DataTable(config);

    // initialize are you sure
    $("#edit-form").areYouSure({ message: i18n.are_you_sure });

    // handle modal-script close event
    $("#modal-script").on("hide.bs.modal", function (e) {

	// if the forms is dirty then ask to the user
	// if he wants save edits
	if ($('#edit-form').hasClass('dirty')) {

	    // ask to user if he REALLY wants close modal
	    const result = confirm(`${i18n.are_you_sure}`);
	    if (!result) e.preventDefault();

	    // remove dirty class from form
	    $('#edit-form').removeClass('dirty');
	}
    })
	.on("shown.bs.modal", function (e) {
	    // add focus to btn apply to enable focusing on the modal hence user can press escape button to
	    // close the modal
	    $("#btn-apply").trigger('focus');
	});

    /* Remove a single exclusion */
    $('#scripts-config').on('click', '[href="#modal-script"],[data-bs-target="#modal-script"]', function (e) {
		const exclusionData = $script_table.row($(this).parent().parent().parent().parent()).data();
		$deleteAlertExclusion.invokeModalInit(exclusionData);
    });

	$('.alert-select').on('change', null, function() {
		const host_alert_key = $(`#host-alert-select`).val() === "0" ? null : $(`#host-alert-select`).val();
		const flow_alert_key = $(`#flow-alert-select`).val() === "0" ? null : $(`#flow-alert-select`).val();
		if(!host_alert_key && !flow_alert_key)
			$(`#add-modal-feedback`).html(i18n.select_an_alert).show();
		else
			$(`#add-modal-feedback`).hide();
	});

    $(`#btn-confirm-action_delete-all-modal`).click(async function () {
	$(this).attr("disabled", "disabled");
	$.post(`${http_prefix}/lua/pro/rest/v2/delete/all/alert/exclusions.lua`, {
	    csrf: pageCsrf,
	    host: host, // Can be empty, when no host is selected
	})
	    .then((result) => {
		if (result.rc == 0) location.reload();
	    })
	    .catch((error) => {
		console.error(error);
	    })
		.always(() => {
		    $(`#btn-delete-all`).removeAttr("disabled");
		})
    })

	/* ******************************************************* */

	$(`#add-exclusion-modal`).modalHandler({
		method: 'post',
		csrf: pageCsrf,
		resetAfterSubmit: false,
		endpoint: `${http_prefix}/lua/pro/rest/v2/edit/check/filter.lua`,
		onModalInit: function (_, modalHandler) {
			// hide the fields and select default type entry
			const NetworkFields = "#add-exclusion-modal .network-fields";
			$(NetworkFields).hide();

			$(`#add-exclusion-modal .ip-fields`).show().find(`input,select`).removeAttr("disabled");
			$(`#add-modal-feedback`).hide();

			$(`#add-exclusion-modal [name='member_type']`).removeAttr('checked').parent().removeClass('active');
			// show the default view
			$(`#add-exclusion-modal #ip-radio-add`).attr('checked', '').parent().addClass('active');
			
			// on select member type shows only the fields interested
			$(`#add-exclusion-modal [name='member_type']`).change(function () {
				const value = $(this).val();
				$(`#add-exclusion-modal [name='member_type']`).removeAttr('checked').parent().removeClass('active');
				$(this).attr('checked', '');

				// clean the members and show the selected one
				$(`#add-exclusion-modal [class*='fields']`).hide();
				$(`#add-exclusion-modal [class*='fields'] input, #add-exclusion-modal [class*='fields'] select`).attr("disabled", "disabled");

				$(`#add-exclusion-modal [class='${value}-fields']`).show().find('input,select').removeAttr("disabled");
				$(`#add-exclusion-modal [class='host-alert-fields']`).show().find('input,select').removeAttr("disabled");
				$(`#add-exclusion-modal [class='flow-alert-fields']`).show().find('input,select').removeAttr("disabled");

				modalHandler.toggleFormSubmission();
			});
		},
		beforeSumbit: function () {
			let alert_addr;
			const host_alert_key = $(`#host-alert-select`).val() === "0" ? null : $(`#host-alert-select`).val();
			const flow_alert_key = $(`#flow-alert-select`).val() === "0" ? null : $(`#flow-alert-select`).val();
			const typeSelected = $(`#add-exclusion-modal [name='member_type']:checked`).val();

			if (typeSelected == "ip") {
				alert_addr = $(`#add-exclusion-modal input[name='ip_address']`).val();
			} else {
				const network = $(`#add-exclusion-modal input[name='network']`).val();
				const cidr = $(`#add-exclusion-modal input[name='cidr']`).val();

				alert_addr = `${network}/${cidr}`;
			}

			if(!host_alert_key && !flow_alert_key) {
				$(`#add-modal-feedback`).html(i18n.select_an_alert).show();
				return;
			}

			return { alert_addr: alert_addr, host_alert_key: host_alert_key, flow_alert_key: flow_alert_key };
		},
		onSubmitSuccess: function (response, textStatus, modalHandler) {
			if (response.rc < 0) {
				$(`#add-modal-feedback`).html(i18n.rest[response.rc_str]).show();
				return;
			}
			location.reload();
		}
	}).invokeModalInit();
});


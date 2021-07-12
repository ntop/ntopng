// 2020 - ntop.org

/* ******************************************************* */

const reloadPageAfterPOST = () => {
    if (location.href.indexOf("check=") > 0) {
	/* Go back to the alerts page */
	//location.href = page_url + location.hash;
	window.history.back();
    } else {
	/* The URL is still the same as before, need to force a reload */
	location.reload();
    }
}

/* ******************************************************* */

const apply_delete_alert_exclusion = (event) => {
    const $apply_btn = $('#btn-apply');
    const $error_label = $("#apply-error");

    // remove dirty class from form
    $('#edit-form').removeClass('dirty')
    $apply_btn.attr('disabled', '');

    $.post(`${http_prefix}/lua/pro/rest/v2/delete/${check_subdir}/alert/exclusions.lua`, {
	alert_addr: $("#alert_addr").val(),
	alert_key: $("#alert_key").val(),
	csrf: pageCsrf,
    })
	.done((d, status, xhr) => {
	    if (NtopUtils.check_status_code(xhr.status, xhr.statusText, $error_label)) return;

	    if (d.rc != 0) {
		$error_label.text(d.error).show();
		// re enable button
		$apply_btn.removeAttr('disabled');
	    }

	    // if the operation was successfull then reload the page
	    if (d.rc == 0) reloadPageAfterPOST();
	})
	.fail(({ status, statusText }, a, b) => {

	    NtopUtils.check_status_code(status, statusText, $error_label);

	    if (status == 200) {
		$error_label.text(`${i18n.expired_csrf}`).show();
	    }

	    $apply_btn.removeAttr('disabled');
	});
}

/* ******************************************************* */

// get script key and script name
const initDeleteAlertExclusionModal = (alert_key, script_title, excluded_host) => {
    // change title to modal
    $("#script-name").html(script_title);
    $('#script-description').html(excluded_host);

    // Add alert key and excluded host as hidden values
    $('#alert_key').val(alert_key);
    $('#alert_addr').val(excluded_host);

    $("#modal-script form").off('submit');
    $("#modal-script").on("submit", "form", function (e) {
	e.preventDefault();

	$('#edit-form').trigger('reinitialize.areYouSure').removeClass('dirty');
	$("#btn-apply").trigger("click");
    });

    // hide previous error
    $("#apply-error").hide();

    // bind on_apply event on apply button
    $("#edit-form").off("submit").on('submit', apply_delete_alert_exclusion);

    // bind are you sure to form
    $('#edit-form').trigger('rescan.areYouSure').trigger('reinitialize.areYouSure');
}

/* ******************************************************* */

$(function () {
    /* Possibly pass an host when requesting datatable data to have results filtered by host */
    let ajax_data = {};
    if(`${host}`)
	ajax_data = {"host": `${host}`};

    // initialize script table
    const $script_table = $("#scripts-config").DataTable({
	dom: "Bfrtip",
	pagingType: 'full_numbers',
	language: {
	    info: i18n.showing_x_to_y_rows,
	    search: i18n.script_search,
	    infoFiltered: "",
	    paginate: {
		previous: '&lt;',
		next: '&gt;',
		first: '«',
		last: '»'
	    }
	},
	lengthChange: false,
	ajax: {
	    url: `${http_prefix}/lua/pro/rest/v2/get/${check_subdir}/alert/exclusions.lua`,
	    type: 'get',
	    dataSrc: 'rsp',
	    data: ajax_data,
	},
	stateSave: true,
	initComplete: function (settings, json) {
	},
	order: [[0, "asc"]],
	buttons: {
	    buttons: [
		{
		    text: '<i class="fas fa-sync"></i>',
		    className: 'btn-link',
		    action: function (e, dt, node, config) {
			$script_table.ajax.reload(function () {
			}, false);
		    }
		}
	    ],
	    dom: {
		button: {
		    className: 'btn btn-link'
		},
		container: {
		    className: 'border-start ms-1 float-end'
		}
	    }
	},
	columns: [
	    {
		data: 'title',
		render: function (data, type, row) {
		    if (type == 'display') return `<b>${data}</b>`;
		    return data;
		},
	    },
	    {
		data: null,
		sortable: true,
		searchable: true,
		className: 'text-center',
		width: '10%',
		render: function (data, type, row) {
		    const icon = (!row.category_icon) ? '' : `<i class='fa ${row.category_icon}'></i>`;
		    if (type == "display") return `${icon}`;
		    return row.category_title;
		}
	    },
	    {
		sortable: false,
		searchable: false,
		visible: false,
		data: 'excluded_host',
		type: 'ip-address',
	    },
	    {
		data: 'excluded_host_label',
		type: 'ip-address',
		width: '20%',
	    },
	    {
		data: 'excluded_host_name',
		sortable: true,
		searchable: true,
		width: '20%',
	    },
	    {
		targets: -1,
		data: null,
		name: 'actions',
		className: 'text-center',
		sortable: false,
		width: '10%',
		render: function (data, type, script) {
		    return DataTableUtils.createActionButtons([
			{ class: `btn-danger`, modal: '#modal-script', icon: 'fa-trash' },
		    ]);
		},
	    }
	]
    });

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

    // load templates for the script
    $('#scripts-config').on('click', '[href="#modal-script"],[data-bs-target="#modal-script"]', function (e) {

	const row_data = $script_table.row($(this).parent().parent()).data();
	const alert_key = row_data.alert_key;
	const script_title = row_data.title;
	const excluded_host = row_data.excluded_host;

	initDeleteAlertExclusionModal(alert_key, script_title, excluded_host);
    });

    $(`#delete-all-modal #btn-confirm-action`).click(async function () {
	$(this).attr("disabled", "disabled");
	$.post(`${http_prefix}/lua/pro/rest/v2/delete/all/alert/exclusions.lua`, {
	    check_subdir: check_subdir,
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

});

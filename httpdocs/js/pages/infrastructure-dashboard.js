$(function() {

    const testAuthentication = async (remoteUrl, token) => {
        
        const response = await fetch(`${http_prefix}/lua/pro/rest/v2/check/infrastructure/config.lua`, {
            method: 'post',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({token: token, url: remoteUrl, csrf: pageCsrf})
        });
        const data = await response.json();
        console.log(data);
        const hasLoggedIn = (data.rc == 0);
        const errorMessage = (data.rc_str);

        return [hasLoggedIn, errorMessage];
    }
    
    const reloadTable = () => {
        $(`[data-toggle='tooltip']`).tooltip();
        $infrastructureTable.ajax.reload();
    }

    let dtConfig = DataTableUtils.getStdDatatableConfig([
        {
            text: '<i class="fas fa-plus"></i>',
            action: () => { $(`#add-instance-modal`).modal('show'); }
        },
        {
            text: '<i class="fas fa-sync"></i>',
            action: () => { reloadTable(); }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/rest/v2/get/infrastructure/instance.lua?stats=true`, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        columns: [
            /* Alias Column */
            { width: '15%', data: 'alias', render: (alias, type, instance) => {
		        return alias;
            }},
            /* URL Column */
            { width: '15%', data: 'url', render: (url, type, instance) => {     
                if (type !== 'display') return url;
                const label = url.replace(/(http(s)?)\:\/\//, '');
                return `<a href='${url}' target='_self'>${label} </a><i class='fas fas fa-external-link-alt'></i>`;
            }},
            /* Chart Column */
            { width: '5%', data: 'chart', className: 'text-center', render: (chart, type, instance) => {
                if (type !== 'display') return chart;
                return `<a href='${chart}'><i class='fas fa-chart-area'></i></a>`;
            }},
            /* Status Column */
            { width: '5%', className: 'text-center', data: 'am_success', render: (am_success, type, instance) => {
                if (type === "display") {
                    const badgeColor = (am_success && !instance.am_error) ? 'success' : (!am_success && instance.error_message !== undefined) ? 'danger' : 'secondary';
                    const badgeText = (am_success && !instance.am_error) ? i18n.up : (!am_success && instance.error_message !== undefined) ? i18n.error : i18n.not_polled_yet;
                    return `<span class='badge bg-${badgeColor}'>${badgeText}</span>`;
                }
                return am_success;
            }},
            /* Throughput Column */
            { width: '10%', className: 'text-center', data: 'am.throughput_bps', render: (throughput, type, instance) => {
                if (type === "display") return `${NtopUtils.fbits(throughput)}`;
                return throughput;
            }},
            /* Hosts Column */
            { width: '10%', className: 'text-center', data: 'am.hosts', render: (hosts, type) => {
                if (type === "display") return NtopUtils.fint(hosts);
                return hosts;
            }},
            /* Flows Column */
            { width: '10%', className: 'text-center', data: 'am.flows', render: (flows, type) => {
                if (type === "display") return NtopUtils.fint(flows);
                return flows;
            } },
            /* Engaged Alerts Column */
            { width: '10%', className: 'text-center', data: 'am.num_alerts_engaged', render: (num_alerts_engaged, type) => {
                if (type === "display") return NtopUtils.fint(num_alerts_engaged);
                return num_alerts_engaged;
            } },
            /* Flow Alerts Column */
            { width: '10%', className: 'text-center', data: 'am.num_alerted_flows', render: (num_alerted_flows, type) => {
                if (type === "display") return NtopUtils.fint(num_alerted_flows);
                return num_alerted_flows;
            } },
            /* Last Update Column */
            { width: '10%', className: 'text-center', data: 'last_update.when', render: $.fn.dataTableExt.absoluteFormatSecondsToHHMMSS },
            /* Action Column */
            {
                targets: -1,
                width: '8%',
                className: 'text-center',
                data: null,
                render: (_, type, instance) => DataTableUtils.createActionButtons([
                    { class: 'btn-info', icon: 'fa-edit', modal: '#edit-instance-modal' },
                    { class: 'btn-danger', icon: 'fa-trash', modal: '#remove-instance-modal' },
                ])
            }
        ],
        initComplete: (dtSettings, {rsp}) => {

            const $table = dtSettings.oInstance.api();
            $(`[data-toggle='tooltip']`).tooltip();
            setInterval(() => reloadTable(), 60000 /* 1 minute */);
        }
    });

    const $infrastructureTable = $(`#infrastructure-table`).DataTable(dtConfig);
    DataTableUtils.addToggleColumnsDropdown($infrastructureTable);

    const STATUS_COLUMN_INDEX = 3;
    const infrastructureDashboardFilterMenu = new DataTableFiltersMenu({
        filterTitle: i18n.status,
        filters: [
           { key: 'up', label: i18n.up, countable: true, regex: true },
           { key: 'error', label: i18n.error, countable: true, regex: false },
        ],
        columnIndex: STATUS_COLUMN_INDEX,
        tableAPI: $infrastructureTable,
        filterMenuKey: 'status',
    }).init();

     /* bind add endpoint event */
     $(`#add-instance-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/rest/v2/add/infrastructure/instance.lua`,
        csrf: pageCsrf,
        resetAfterSubmit: false,
        beforeSumbit: () => {
            const data = {};
            $(`#add-instance-modal form input`).each(function() {
                data[$(this).attr('name')] = $(this).val().trim();
            });
            // clean the url
            data.url = new URL(data.url).origin;
            return data;
        },
        onSubmitSuccess: (response) => {

            if (response.rc < 0) {
                $(`#add-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            reloadTable();
            $(`#add-instance-modal`).modal('hide');

        }
    }).invokeModalInit();

    const $editInstanceModal = $(`#edit-instance-modal form`).modalHandler({
        method: 'post',
        csrf: pageCsrf,
        endpoint: `${http_prefix}/lua/rest/v2/edit/infrastructure/instance.lua`,
        dontDisableSubmit: true,
        onModalInit: (instance) => {
            $(`#edit-instance-modal form input`).each(function() {
                
                const name = $(this).attr('name');
                if (name == "rtt_threshold") {
                    $(this).val(instance[name] / 1000);
                    return;
                }

                $(this).val(instance[name]);
            });
        },
        beforeSumbit: (instance) => {
            const data = {};
            $(`#edit-instance-modal form input`).each(function() {
                data[$(this).attr('name')] = $(this).val().trim();
            });
            data.instance_id = instance.id;
            // clean the url
            data.url = new URL(data.url).origin;
            return data;
        },
        onSubmitSuccess: (response) => {
        
            if (response.rc < 0) {
                $(`#edit-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            reloadTable();
            $(`#edit-instance-modal`).modal('hide');
        }
    });

    const $removeInstanceModal = $(`#remove-instance-modal form`).modalHandler({
        method: 'post',
        csrf: pageCsrf,
        endpoint: `${http_prefix}/lua/rest/v2/delete/infrastructure/instance.lua`,
        dontDisableSubmit: true,
        onModalInit: (instance) => {
            $(`.remove-instance-name`).text(`${instance.alias}`);
        },
        beforeSumbit: (instance) => {
            return {  instance_id: instance.id };
        },
        onSubmitSuccess: (response) => {

            if (response.rc < 0) {
                $(`#remove-modal-feedback`).html(i18n.rest[response.rc_str]).fadeIn();
                return;
            }

            reloadTable();
            $(`#remove-instance-modal`).modal('hide');
        }
    });

    /* bind edit instance event */
    $(`table#infrastructure-table`).on('click', `a[href='#edit-instance-modal']`, function (e) {

        const selectedInstance = $infrastructureTable.row($(this).parent().parent()).data();
        $editInstanceModal.invokeModalInit(selectedInstance);
    });
    /* bind remove instance event */
    $(`table#infrastructure-table`).on('click', `a[href='#remove-instance-modal']`, function (e) {
        const selectedInstance = $infrastructureTable.row($(this).parent().parent()).data();
        $removeInstanceModal.invokeModalInit(selectedInstance);
    });

    $(`.test-auth`).click(async function(e) {
        
        e.preventDefault();

        const $button = $(this);
        const $form = $button.parents('form');

        const $feedbackLabel = $form.find(`.auth-log`);
        $button.attr("disabled", "disabled");
        $button.find('span.spinner-border').fadeIn();
        $feedbackLabel.addClass('alert-info');
        $feedbackLabel.removeClass(`alert-danger alert-success`).text(`${i18n.testing_authentication}...`).show();

        const remoteUrl = $form.find(`[name='url']`).val().trim();
        const token = $form.find(`[name='token']`).val().trim();

        const [success, errorMessage] = await testAuthentication(remoteUrl, token);

        if (!success) {
            $button.find('span.spinner-border').fadeOut(function () {
                // TODO: read from i18n
                $feedbackLabel.removeClass('alert-info').addClass(`alert-danger`).html(i18n.rest[errorMessage]);
            });
            $button.removeAttr("disabled");
            return;
        }

        // show a green label to alert the endpoint message
        $button.find('span.spinner-border').fadeOut(function () {
            $feedbackLabel.removeClass('alert-info').addClass('alert-success').html(i18n.successfull_login).fadeOut(3000, function() {
                $feedbackLabel.removeClass(`alert-success`);
            });
        });
        $button.removeAttr("disabled");

    });

});

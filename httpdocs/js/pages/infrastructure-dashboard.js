$(document).ready(function() {

    const reloadTable = () => {
        $(`[data-toggle='tooltip']`).tooltip();
        $infrastructureTable.ajax.reload();
    }

    const testAuthentication = async (url, token) => {


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
    dtConfig = DataTableUtils.setAjaxConfig(dtConfig, `${http_prefix}/lua/rest/v1/get/infrastructure/instance.lua?stats=true`, 'rsp');
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        responsive: true,
        columns: [
            /* Alias Column */
            { width: '20%', data: 'alias', render: (alias, type, instance) => {
                if ((type !== 'display' || instance.am_success)) return alias;
                if (instance.error_message === undefined) return alias;
                return `<span data-toggle='tooltip' data-placement='bottom' title='${i18n.rest[instance.error_message]}'>${alias} <i class="fas fa-exclamation-triangle" style="color: #f0ad4e;"></i></span>`;
            }},
            /* Status Column */
            { width: '5%', className: 'text-center', data: 'am_success', render: (am_success, type, instance) => {
                if (type === "display") {
                    const badgeColor = (am_success && !instance.am_error) ? 'success' : (!am_success && instance.am_error) ? 'danger' : 'secondary';
                    const badgeText = (am_success && !instance.am_error) ? i18n.up : (!am_success && instance.am_error) ? i18n.unreachable : i18n.not_polled_yet;
                    return `<span class='badge badge-${badgeColor}'>${badgeText}</span>`;
                }
                return am_success;
            }},
            /* Download Column */
            { width: '10%', className: 'text-center', data: 'am.throughput', render: (throughput, type, instance) => {
                if (throughput === undefined) return throughput;
                if (type !== "display") return throughput.download;
                return `<i class='fas fa-arrow-down'></i> ${NtopUtils.fbits(throughput.download.bps)}`
            }},
            /* Upload Column */
            { width: '10%', className: 'text-center', data: 'am.throughput', render: (throughput, type, instance) => {
                if (throughput === undefined) return throughput;
                if (type !== "display") return throughput.upload;
                return `<i class='fas fa-arrow-up'></i> ${NtopUtils.fbits(throughput.upload.bps)}`
            }},
            /* Hosts Column */
            { width: '10%', className: 'text-center', data: 'am.num_hosts' },
            /* Flows Column */
            { width: '10%', className: 'text-center', data: 'am.num_flows' },
            /* Alerts Column */
            { width: '10%', className: 'text-center', data: 'am.engaged_alerts' },
            /* Last Update Column */
            { width: '10%', className: 'text-center', data: 'am.epoch', render: $.fn.dataTableExt.absoluteFormatSecondsToHHMMSS },
            /* Action Column */
            {
                targets: -1,
                width: '10%',
                className: 'text-center',
                data: null,
                render: (_, type, instance) => DataTableUtils.createActionButtons([
                    { class: 'btn-info', icon: 'fa-external-link-square-alt', href: new URL(instance.url).origin, external: true },
                    { class: 'btn-info', icon: 'fa-edit', modal: '#edit-instance-modal' },
                    { class: 'btn-danger', icon: 'fa-trash', modal: '#remove-instance-modal' },
                ])
            }
        ],
        initComplete: (dtSettings, {rsp}) => {

            const $table = dtSettings.oInstance.api();
            $(`[data-toggle='tooltip']`).tooltip();
            setInterval(() => reloadTable(), 300000000 /* 5 minutes */);
        }
    });

    const $infrastructureTable = $(`#infrastructure-table`).DataTable(dtConfig);

    const STATUS_COLUMN_INDEX = 1;
    const infrastructureDashboardFilterMenu = new DataTableFiltersMenu({
        filterTitle: i18n.status,
        filters: [
           { key: 'up', label: i18n.up, countable: true, regex: 'true' },
           { key: 'unreachable', label: i18n.unreachable, countable: true, regex: 'false' },
        ],
        columnIndex: STATUS_COLUMN_INDEX,
        tableAPI: $infrastructureTable,
        filterMenuKey: 'status',
    });

     /* bind add endpoint event */
     $(`#add-instance-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/rest/v1/add/infrastructure/instance.lua`,
        csrf: pageCsrf,
        resetAfterSubmit: false,
        beforeSumbit: () => {
            const data = {};
            $(`#add-instance-modal form input`).each(function() {
                data[$(this).attr('name')] = $(this).val();
            });
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
        endpoint: `${http_prefix}/lua/rest/v1/edit/infrastructure/instance.lua`,
        dontDisableSubmit: true,
        onModalInit: (instance) => {
            $(`#edit-instance-modal form input`).each(function() {
                $(this).val(instance[$(this).attr('name')]);
            });
        },
        beforeSumbit: (instance) => {
            const data = {};
            $(`#edit-instance-modal form input`).each(function() {
                data[$(this).attr('name')] = $(this).val();
            });
            data.instance_id = instance.id;
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
        endpoint: `${http_prefix}/lua/rest/v1/delete/infrastructure/instance.lua`,
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

    $(`.test-auth`).click(function() {

    });

});
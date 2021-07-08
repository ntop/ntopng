$(function() {

    const setImportExportButtonLabels = (key) => {

        $(`#btn-import span, #btn-confirm-import`).text((key == 'all') ? i18n.restore : i18n.import);
        $(`#btn-export span`).text((key == 'all') ? i18n.backup : i18n.export);

        if (key == 'all') {
            $(`.import-title`).hide();
            $(`.restore-title`).show();
        }
        else {
            $(`.import-title`).show();
            $(`.restore-title`).hide();
        }

    }

    const updateExportLink = (key) => {

        if (key === undefined) {
            console.warn("A key must be provided!");
            return;
        }

        // create a filename for the selectec config
        const filename = `${key}_config.json`;
        const href = new URL(`/lua/rest/v2/export/${key}/config.lua`, location.origin);
        href.searchParams.set('download', '1');

        // update the export button link
        $(`#btn-export`)
            .attr("download", filename)
            .attr("href", href.toString());
    }

    $(`input[name='configuration']`).change(function() {

        const key = $(this).val();
        let label = $(this).parent("div").find("label").text();
        if (label.indexOf('(') >= 0) label = label.substr(0, label.indexOf('('));

        $(`.selected-item`).text((key == 'all') ? 'ntopng' : label);

        setImportExportButtonLabels(key);
        updateExportLink(key);
    });

    $(`#reset-modal #btn-confirm-action`).click(async function() {

        $(this).attr("disabled", "disabled");
        const key = $(`input[name='configuration']:checked`).val();

        try {

            const request = await fetch(`${http_prefix}/lua/rest/v2/reset/${key}/config.lua`);
            const response = await request.json();

            // check if the request failed
            if (response.rc < 0) {
                return;
            }

            const body = (key == 'all')
                ? i18n.manage_configurations.messagges.reset_all_success
                : i18n.manage_configurations.messagges.reset_success;

            ToastUtils.showToast({
                id: 'reset-configuration-alert',
                level: 'success',
                title: i18n.success,
                body: body,
                delay: 2000
            });

            $(`#reset-modal`).modal('hide');

        }
        catch (exception) {
        }
        finally {
            $(this).removeAttr("disabled");
        }


    });

    // configure import config modal
    NtopUtils.importModalHelper({
        loadConfigXHR: (jsonConf) => {
            const key = $(`input[name='configuration']:checked`).val();
            return $.post(`${http_prefix}/lua/rest/v2/import/${key}/config.lua`, { JSON: jsonConf, csrf: importCSRF});
        }
    });

});
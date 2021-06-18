// 2020 - ntop.org
const special_characters_regex = /[\@\#\<\>\\\/\?\'\"\`\~\|\.\:\;\,\!\&\*\(\)\{\}\[\]\_\-\+\=\%\$\^]/g;

const get_configuration_data = ($config_table, $button_caller) => {

    // get row data
    const row_data = $config_table.row($button_caller.parent().parent()).data();

    return {
        config_id: row_data.id,
        config_name: row_data.name,
        config_pools: row_data.pools
    }
}

const resetConfig = () => {
    var params = {};
    params.csrf = pageCsrf;
    params.action = "reset_config";

    var form = NtopUtils.paramsToForm('<form method="post"></form>', params);
    form.appendTo('body').submit();
}

$(function() {

    const add_columns = () => {

        const pools_column = {
            data: 'pools',
            render: function(data, type, row) {

                // show pools as a string into display mode
                // if there aren't ant pools then show an alert
                if (type == "display" && data.length > 0) {
                    const flat = data.map((f) => f.label);
                    return flat.join(', ');
                }
                else if (type == 'display' && data.length == 0) {
                    return `<i>${i18n.no_pools_applied}</i>`
                }

                // return pools as a string
                const flat = data.map((f) => f.label);
                return flat.join(', ');
            }
        }

        const name_column = {
            data: 'name',
            defaultContent: '{Config Name}',
            render: (data, type, row) => `<b>${data}</b>`
        }

        const action_column = {
            pools: -1,
            width: '200px',
            data: null,
            className: 'text-center',
            render: function(data, type, row) {

                let rv = `
                    <a class="btn btn-info btn-sm" href='edit_configset.lua?subdir=${subdir}' title='${i18n.edit}'>
                        <i class='fas fa-edit'></i>
                    </a>
                `;

                return `<div>${rv}</div>`;
            }
        }

        if (DEFAULT_CONFIG_ONLY) return [name_column, action_column];

        return [name_column, pools_column, action_column];
    }

    const $config_table = $("#config-list").DataTable({
        lengthChange: false,
        dom: "<'d-flex'<'mr-auto'l><'dt-search'f>B>rtip",
        pagingType: 'full_numbers',
        stateSave: true,
        buttons: {
            buttons: [
                {
                    text: '<i class="fas fa-sync"></i>',
                    className: 'btn-link',
                    action: function (e, dt, node, config) {
                        $config_table.ajax.reload();
                    }
                }
            ],
            dom: {
                button: {
                    className: 'btn btn-link'
                },
                container: {
                    className: 'border-left ml-1 float-right'
                }
            }
        },
        initComplete: function() {
            // clear searchbox datatable
            $(".dataTables_filter").find("input[type='search']").val('').trigger('keyup');
        },
        language: {
            info: i18n.showing_x_to_y_rows,
            search: i18n.config_search,
            infoFiltered: "",
            paginate: {
               previous: '&lt;',
               next: '&gt;',
               first: '«',
                last: '»'
            }
        },
        ajax: {
            url: `${http_prefix}/lua/get_checks_configsets.lua?check_subdir=${subdir}`,
            type: 'GET',
            dataSrc: ''
        },
        columns: add_columns()
    });

});

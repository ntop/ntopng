--
-- (C) 2019 - ntop.org
--
dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local ts_utils = require("ts_utils")
local info = ntop.getInfo() 
local page_utils = require("page_utils")
local format_utils = require("format_utils")
local os_utils = require "os_utils"

sendHTTPContentTypeHeader('text/html')

page_utils.print_header(i18n("about.about_x", { product=info.product }))

active_page = "about"

local subdir = _GET["subdir"]

-- temporary solution
local titles = {
    ["host"] = "Hosts",
    ["snmp_device"] = "SNMP",
    ["system"] = "System",
    ["flow"] = "Flows",
    ["interface"] = "Interfaces",
    ["network"] = "Networks",
    ["syslog"] = "Syslog"
}

if subdir == nil then
    subdir = 'host'
end

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print([[<link href="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.css" rel="stylesheet">]])

print([[
    <div class='container-fluid mt-3'>
        <div class='row'>
            <div class='col-md-12 col-lg-12'>
                <nav aria-label="breadcrumb">
                    <ol class="breadcrumb">
                        <li class="breadcrumb-item">Config List</li>
                        <li class='breadcrumb-item active'>]] .. titles[subdir] .. [[</li>
                    </ol>
                </nav>
                <ul class="nav nav-pills">
                    <li class="nav-item">
                        <a class="nav-link ]] .. (subdir == "host" and "active" or "") .. [[" href="?subdir=host">Hosts</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link ]] .. (subdir == "flow" and "active" or "") .. [[" href="?subdir=flow">Flows</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link ]] .. (subdir == "interface" and "active" or "") .. [[" href="?subdir=interface">Interfaces</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link ]] .. (subdir == "network" and "active" or "") .. [[" href="?subdir=network">Networks</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link ]] .. (subdir == "snmp_device" and "active" or "") .. [[" href="?subdir=snmp_device">SNMP</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link ]] .. (subdir == "system" and "active" or "") .. [[" href="?subdir=system">System</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link ]] .. (subdir == "syslog" and "active" or "") .. [[" href="?subdir=syslog">Syslog</a>
                    </li>
                </ul>
                <table id="config-list" class='table w-100 table-bordered table-striped table-hover mt-3'>
                       <thead>
                            <tr>
                                <th>Configuration Name</th>
                                <th>Applied to</th>
                                <th>Config Settings</th>
                            </tr>
                        </thead>
                        <tbody></tbody>
                </table>
            </div>
        </div>
    </div>
]])

-- rename modal
print([[

    <div class="modal fade" id="rename-modal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Rename Configuration: <span id='config-name'></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <form class='form'>
                    <div class='form-group'>
                        <label class='form-label' for='#rename-input'>Type the new name:</label>
                        <input type='text' id='rename-input' class='form-control' />
                        <div class="invalid-feedback" id='rename-error' >
                            {message}
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" id='btn-confirm-rename' class="btn btn-primary">Apply</button>
            </div>
            </div>
        </div>
    </div>
]])

-- clone modal
print([[

    <div class="modal fade" id="clone-modal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Cloning Configuration: <span id='clone-name'></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <form class='form'>
                    <div class='form-group'>
                        <label class='form-label' for='#clone-input'>Type a name for the clonation:</label>
                        <input type='text' id='clone-input' class='form-control'/>
                        <div class="invalid-feedback" id='clone-error'>
                            {message}
                        </div>
                    </div>
                </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" id='btn-confirm-clone' class="btn btn-primary">Apply</button>
            </div>
            </div>
        </div>
    </div>
]])

-- applied to modal 
print([[
    <div class="modal fade" id="applied-modal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Apply Config: <span id='apply-name'></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
              <form class='form' type='post'>
                <div class='form-group'>
                    <label for='input-applied'>Type targets:</label>
                    <input type='text' id='applied-input' class='form-control'/>
                    <small>Type targets separated by a comma. i.e: 192.168.1.20,192.123.2.0</small>
                    <div class="invalid-feedback" id='apply-error'>
                            {message}
                        </div>
                </div>
              </form>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" id='btn-confirm-apply' class="btn btn-primary">Apply</button>
            </div>
            </div>
        </div>
    </div>
]])

-- delete modal
print([[

    <div class="modal fade" id="delete-modal" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered" role="document">
            <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Deleting Configuration: <span id='delete-name'></span></h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                Do you want really remove this configuration?<br>
                <b>Attention</b>: this process is irreversible! 
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
                <button type="button" id='btn-confirm-delete' class="btn btn-danger">Confirm Deleting</button>
            </div>
            </div>
        </div>
    </div>
]])

-- add datatable script to config list page
print ([[ <script type="text/javascript" src="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.js"></script> ]])

print([[
<script type='text/javascript'>
    $(document).ready(function() {

        $.get(']].. ntop.getHttpPrefix() ..[[/lua/get_scripts_configsets.lua?script_subdir=]].. subdir ..[[', d => console.log(d));

        const $config_table = $("#config-list").DataTable({
            lengthChange: false,
            language: {
                paginate: {
                   previous: '&lt;',
                   next: '&gt;'
                }
            },
            ajax: {
                url: ']].. ntop.getHttpPrefix() ..[[/lua/get_scripts_configsets.lua?script_subdir=]].. subdir ..[[',
                type: 'GET',
                dataSrc: ''
            },
            columns: [
                {
                    data: 'name',
                    render: function(data, type, row) {
                        return `<b>${data}</b>`
                    }
                },
                {
                    data: 'targets',
                    render: function(data, type, row) {
                        return data.join(', ');
                    }
                },
                {
                    targets: -1,
                    width: '10%',
                    data: null,
                    render: function(data, type, row) {
                        return `
                            <div class='btn-group'>
                                <a href='script_list.lua?confset_id=${data.id}&confset_name=${data.name}&subdir=]].. subdir ..[[' title='Edit' class='btn btn-sm btn-info'><i class='fas fa-edit'></i></a>
                                <button title='Clone' data-toggle="modal" data-target="#clone-modal" class='btn btn-sm btn-secondary' type='button'><i class='fas fa-clone'></i></button>
                                <button title='Applied to' data-toggle='modal' data-target='#applied-modal' ${data.name == 'Default' ? 'disabled' : ''} class='btn btn-sm btn-secondary' type='button'><i class='fas fa-server'></i></button>
                                <button title='Rename' data-toggle="modal" data-target="#rename-modal" ${data.name == 'Default' ? 'disabled' : ''} class='btn btn-sm btn-secondary' type='button'><i class='fas fa-i-cursor'></i></button>
                                <button title='Delete' data-toggle="modal" data-target="#delete-modal" ${data.name == 'Default' ? 'disabled' : ''} class='btn btn-sm btn-danger' type='button'><i class='fas fa-times'></i></button>
                            </div>
                        `;
                    }
                }
            ]

        });

        $('#config-list').on('click', 'button[data-target="#clone-modal"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_name = `${row_data.name}`;
            const conf_id = row_data.id;

            $("#clone-name").html(`<b>${conf_name}</b>`)
            $("#clone-input").attr("placeholder", `i.e. ${conf_name} (Clone)`);

            $("#clone-error").hide();

            $("#btn-confirm-clone").off("click");
            $("#clone-modal form").off("submit");

            $("#btn-confirm-clone").click(function(e) {

                const clonation_name = $("#clone-input").val();
                const $button = $(this);

                if (clonation_name == null || clonation_name == "" || clonation_name == undefined) {

                    $("#clone-error").text("The name cannot be empty!").show();
                    return;
                }

                $button.attr("disabled", "");

                $.when(
                    $.post(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                        action: 'clone',
                        confset_id: conf_id,
                        script_subdir: ']].. subdir ..[[',
                        csrf: ']].. ntop.getRandomCSRFValue() ..[[',
                        confset_name: clonation_name    
                    })
                )
                .then((data, status, xhr) => {
                    
                    $button.removeAttr("disabled");

                    if (!data.success) {
                        $("#clone-error").text(data.error).show();
                        return;
                    }

                    // hide errors and clean modal
                    $("#clone-error").hide(); $("#clone-input").val("");
                    // reload table
                    $config_table.ajax.reload();
                    // hide modal
                    $("#clone-modal").modal('hide');
                    location.reload();

                });
            })

            $("#clone-modal").on("submit", "form", function (e) {
                
                e.preventDefault();
                $("#btn-confirm-clone").trigger("click");
            });

        });

        $('#config-list').on('click', 'button[data-target="#applied-modal"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_id = row_data.id;

            $("#applied-input").val(row_data.targets.join(","))

            $("#apply-name").html(`<b>${row_data.name}</b>`);

            $('#btn-confirm-apply').off('click');

            $('#btn-confirm-apply').click(function(e) {

                const $button = $(this);
                const input_value = $("#applied-input").val();

                // show error message if the input is empty
                if (input_value == "" || input_value == null || input_value == undefined) {
                    $("#apply-error").text("The targets cannot be empty!").show();
                    return;
                }

                console.log(input_value)

                $button.attr("disabled");

                $.when(
                    $.post(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                        action: 'set_targets',
                        confset_id: conf_id,
                        confset_targets: input_value,
                        script_subdir: ']].. subdir ..[[',
                        csrf: ']].. ntop.getRandomCSRFValue() ..[['
                    })
                )
                .then((data, status, xhr) => {

                    $button.removeAttr("disabled");

                    if (!data.success) {
                        $("#apply-error").text(data.error).show();
                        return;
                    }

                    // hide errors and clean modal
                    $("#apply-error").hide(); $("#apply-input").val("");
                    // reload table
                    $config_table.ajax.reload();
                    // hide modal
                    $("#applied-modal").modal('hide');
                    location.reload();

                })


            });

        });

        $('#config-list').on('click', 'button[data-target="#rename-modal"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_id = row_data.id;

            $("#config-name").html(`<b>${row_data.name}</b>`);
            $("#rename-input").attr('placeholder', row_data.name);

            // bind rename click event

            $("#btn-confirm-rename").off('click');

            $("#btn-confirm-rename").click(function(e) {

                const $button = $(this);
                const input_value = $("#rename-input").val();


                // show error message if the input is empty
                if (input_value == "" || input_value == null || input_value == undefined) {
                    $("#rename-error").text("The new name cannot be empty!").show();
                    return;
                }

                $button.attr("disabled");

                $.when(
                    $.post(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                        action: 'rename',
                        confset_id: conf_id,
                        csrf: ']].. ntop.getRandomCSRFValue() ..[[',
                        confset_name: input_value
                    })
                )
                .then((data, status, xhr) => {

                    $button.removeAttr("disabled");

                    if (!data.success) {
                        $("#rename-error").text(data.error).show();
                        return;
                    }

                    // hide errors and clean modal
                    $("#rename-error").hide(); $("#rename-input").val("");
                    // reload table
                    $config_table.ajax.reload();
                    // hide modal
                    $("#rename-modal").modal('hide');
                    location.reload();

                })


            })


        });

        $('#config-list').on('click', 'button[data-target="#delete-modal"]', function(e) {

            const row_data = $config_table.row($(this).parent().parent()).data();
            const conf_id = row_data.id;
            $("#delete-name").html(`<b>${row_data.name}</b>`)

            $("#btn-confirm-delete").off("click");
            $("#btn-confirm-delete").click(function(e) {

                const $button = $(this);
                $button.attr("disabled", "");

                $.when(
                    $.post(']].. ntop.getHttpPrefix() ..[[/lua/edit_scripts_configsets.lua', {
                        action: 'delete',
                        csrf: ']].. ntop.getRandomCSRFValue() ..[[',
                        confset_id: conf_id,
                    })
                )
                .then((data, status, xhr) => {
                    
                    $button.removeAttr("disabled");

                    if (!data.success) {
                        $("#delete-error").text(data.error).show();
                        return;
                    }

                    $("#delete-error").hide(); 
                    // reload table
                    $config_table.ajax.reload();
                    // hide modal
                    $("#delete-modal").modal('hide');
    
                    location.reload();

                });

            })

            

        });

    })
</script>
]])


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")

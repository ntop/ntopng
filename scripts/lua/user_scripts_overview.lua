--
-- (C) 2013-20 - ntop.org
--

local dirs = ntop.getDirs()
package.path = dirs.installdir .. "/scripts/lua/modules/?.lua;" .. package.path
require "lua_utils"
local user_scripts = require("user_scripts")
local page_utils = require("page_utils")

sendHTTPContentTypeHeader('text/html')

page_utils.set_active_menu_entry(page_utils.menu_entries.user_scripts_dev)

local ifid = interface.getId()

local function printUserScripts()

    for _, info in ipairs(user_scripts.listSubdirs()) do

        local scripts = user_scripts.load(ifid, user_scripts.getScriptType(info.id), info.id, {return_all = true})

        for name, script in pairsByKeys(scripts.modules) do

            local available = ""
            local filters = {}
            local hooks = {}

            -- Hooks
            for hook in pairsByKeys(script.hooks) do
              hooks[#hooks + 1] = hook
            end
            hooks = table.concat(hooks, ", ")

            -- Filters
            if(script.is_alert) then filters[#filters + 1] = "alerts" end
            if(script.l4_proto) then filters[#filters + 1] = "l4_proto=" .. script.l4_proto end
            if(script.l7_proto) then filters[#filters + 1] = "l7_proto=" .. script.l7_proto end
            if(script.packet_interface_only) then filters[#filters + 1] = "packet_interface" end
            if(script.three_way_handshake_ok) then filters[#filters + 1] = "3wh_completed" end
            if(script.local_only) then filters[#filters + 1] = "local_only" end
            if(script.nedge_only) then filters[#filters + 1] = "nedge=true" end
            if(script.nedge_exclude) then filters[#filters + 1] = "nedge=false" end
            filters = table.concat(filters, ", ")

            if (name == "my_custom_script") then
              goto skip
            end

            -- Availability
            if(script.edition == "enterprise_m") then
              available = "Enterprise M"
            elseif(script.edition == "enterprise_l") then
              available = "Enterprise L"
            elseif(script.edition == "pro") then
              available = "Pro"
            else
              available = "Community"
            end

            local edit_url = user_scripts.getScriptEditorUrl(script)

            if(edit_url) then
              edit_url = ' <a title="'.. i18n("plugins_overview.action_view") ..'" href="'.. edit_url ..'" class="btn btn-sm btn-secondary" ><i class="fas fa-eye"></i></a>'
            end

            print(string.format(([[
                <tr>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td>%s</td>
                    <td class="text-center">%s</td></tr>
                ]]), name, info.label, available, hooks, filters, edit_url or ""))
            ::skip::
          end
    end
end


-- #######################################################

dofile(dirs.installdir .. "/scripts/lua/inc/menu.lua")

print([[
        <div class='row'>
            <div class='col-12'>]])

page_utils.print_page_title('User Scripts')

print([[
            </div>
            <div class='col-12 my-3'>
                <table class='table table-bordered table-striped' id='user-scripts'>
                    <thead>
                        <tr>
                            <th>]].. i18n("plugins_overview.script") ..[[</th>
                            <th>]].. i18n("plugins_overview.type") ..[[</th>
                            <th>]].. i18n("availability") ..[[</th>
                            <th>]].. i18n("plugins_overview.hooks") ..[[</th>
                            <th>]].. i18n("plugins_overview.filters") ..[[</th>
                            <th>]].. i18n("action") ..[[</th>
                        </tr>
                    </thead>
                    <tbody>]])
                    printUserScripts()
print([[
                    </tbody>
                </table>
        </div>
    </div>
    <link href="]].. ntop.getHttpPrefix() ..[[/datatables/datatables.min.css" rel="stylesheet"/>
    <script type='text/javascript'>

    $(document).ready(function() {

        const addFilterDropdown = (title, values, column_index, datatableFilterId, tableApi) => {

            const createEntry = (val, callback) => {
                const $entry = $(`<li class='dropdown-item pointer'>${val}</li>`);
                $entry.click(function(e) {

                    $dropdownTitle.html(`<i class='fas fa-filter'></i> ${val}`);
                    $menuContainer.find('li').removeClass(`active`);
                    $entry.addClass(`active`);
                    callback(e);
                });

                return $entry;
            }

            const dropdownId = `${title}-filter-menu`;
            const $dropdownContainer = $(`<div id='${dropdownId}' class='dropdown d-inline'></div>`);
            const $dropdownButton = $(`<button class='btn-link btn dropdown-toggle' data-toggle='dropdown' type='button'></button>`);
            const $dropdownTitle = $(`<span>${title}</span>`);
            $dropdownButton.append($dropdownTitle);

            const $menuContainer = $(`<ul class='dropdown-menu' id='${title}-filter'></ul>`);
            values.forEach((val) => {
                const $entry = createEntry(val, (e) => {
                    tableApi.columns(column_index).search(val).draw(true);
                });
                $menuContainer.append($entry);
            });

            const $allEntry = createEntry(']].. i18n('all') ..[[', (e) => {
                $dropdownTitle.html(`${title}`);
                $menuContainer.find('li').removeClass(`active`);
                tableApi.columns().search('').draw(true);
            });
            $menuContainer.prepend($allEntry);

            $dropdownContainer.append($dropdownButton, $menuContainer);
            $(datatableFilterId).prepend($dropdownContainer);
        }

        const $userScriptsTable = $('#user-scripts').DataTable({
            pagingType: 'full_numbers',
            initComplete: function(settings) {

                const table = settings.oInstance.api();
                const types = [... new Set(table.columns(1).data()[0].flat())];
                const availability = [... new Set(table.columns(2).data()[0].flat())];

                addFilterDropdown(']].. i18n("availability") ..[[', availability, 2, "#user-scripts_filter", table);
                addFilterDropdown(']].. i18n("plugins_overview.type") ..[[', types, 1, "#user-scripts_filter", table);
            },
            pageLength: 25,
            language: {
                info: "]].. i18n('showing_x_to_y_rows', {x='_START_', y='_END_', tot='_TOTAL_'}) ..[[",
                search: "]].. i18n('search') ..[[:",
                infoFiltered: "",
                paginate: {
                    previous: '&lt;',
                    next: '&gt;',
                    first: '«',
                    last: '»'
                },
            },
        });

    });

    </script>
]])


dofile(dirs.installdir .. "/scripts/lua/inc/footer.lua")


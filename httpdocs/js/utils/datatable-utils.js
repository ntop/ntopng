class DataTableUtils {

    /**
     * Return a standard config for the Sprymedia (c) DataTables
     */
    static getStdDatatableConfig(dom = "lBfrtip", dtButtons = []) {
        return {
            dom: dom,
            pagingType: 'full_numbers',
            lengthMenu: [[10, 25, 50, -1], [10, 25, 50, `${i18n.all}`]],
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
            saveState: true,
            buttons: {
                buttons: dtButtons,
                dom: {
                    button: {
                        className: 'btn btn-link'
                    },
                    container: {
                        className: 'border-left ml-1 float-right'
                    }
                }
            }
        }
    }

    static setAjaxConfig(config, url, dataSrc = '', method = "get", params = {}) {

        config.ajax = {
            url: url,
            type: method,
            dataSrc: dataSrc,
            data: function (d) {
                return $.extend({}, d, params);
            }
        }

        return config;
    }

    static extendConfig(config, extension) {

        // if there are custom filters then manage state in this way
        if (extension.hasFilters) {

            extension.stateSaveCallback = function(settings,data) {
                localStorage.setItem('DataTables_' + settings.sInstance, JSON.stringify(data))
            };

            extension.stateLoadCallback = function(settings) {
                return JSON.parse(localStorage.getItem('DataTables_' + settings.sInstance));
            };

            // on saving the table state store the selected filters
            extension.stateSaveParams = function(settings, data) {

                // save the filters selected from the user inside the state
                $('[data-filter]').each(function() {

                    const activeFilter = $(this).find(`li.active`).data('filter-key');
                    if (!activeFilter) return;

                    // if the filters object is not allocated then initizializes it
                    if (!data.filters) data.filters = {};
                    data.filters[$(this).data('filter')] = activeFilter;

                });
            };
        }

        return $.extend({}, config, extension);
    }

    /**
     * A simple filter is an object like this: { key: '', label: 'label1', regex: 'http://' }
     * @param {*} title The select title
     * @param {*} filters An array of filters
     * @param {*} columnIndex The column index to sort
     * @param {*} filterID The filter container
     * @param {*} tableAPI
     */
    static addFilterDropdown(title, filters = [], columnIndex, filterID, tableAPI) {

        const createEntry = (val, key, callback) => {

            const $entry = $(`<li data-filter-key='${key}' class='dropdown-item pointer'>${val}</li>`);

            $entry.click(function(e) {
                // set active filter title and key
                if ($dropdownTitle.parent().find(`i.fas`).length == 0) {
                    $dropdownTitle.parent().prepend(`<i class='fas fa-filter'></i>`);
                }
                $dropdownTitle.text($entry.text());
                $dropdownTitle.attr(`data-filter-key`, key);
                // remove the active class from the li elements
                $menuContainer.find('li').removeClass(`active`);
                // add active class to current entry
                $entry.addClass(`active`);
                // if there is a callback then invoked it
                if (callback) callback(e);
            });
            return $entry;
        }

        const filterKey = title.toLowerCase().split(" ").join("_");
        const dropdownId = `${filterKey}-filter-menu`;
        const $dropdownContainer = $(`<div id='${dropdownId}' class='dropdown d-inline'></div>`);
        const $dropdownButton = $(`<button class='btn-link btn dropdown-toggle' data-toggle='dropdown' type='button'></button>`);
        const $dropdownTitle = $(`<span>${title}</span>`);
        $dropdownButton.append($dropdownTitle);

        const $menuContainer = $(`<ul class='dropdown-menu' data-filter='${filterKey}' id='${filterKey}-filter'></ul>`);

        // for each filter defined in filters create a dropdown item <li>
        for (let filter of filters) {

            const $entry = createEntry(filter.label, filter.key, (e) => {
                tableAPI.column(columnIndex).search(filter.regex, true, false).draw();
            });

            $menuContainer.append($entry);
        }

        // add all filter
        const $allEntry = createEntry(i18n.all, 'all', (e) => {

            $dropdownTitle.parent().find('i.fas.fa-filter').remove();
            $dropdownTitle.html(`${title}`).removeAttr(`data-filter-key`);
            tableAPI.columns(columnIndex).search('').draw(true);
        });

        // append the created dropdown inside
        $(filterID).prepend(
            $dropdownContainer.append(
                $dropdownButton, $menuContainer.prepend($allEntry)
            )
        );

        DataTableUtils.setCurrentFilter(tableAPI);
    }

    /**
     * For each filter object set the previous filter's state
     * @param {object} tableAPI
     */
    static setCurrentFilter(tableAPI) {

        if (!tableAPI.state) return;
        if (!tableAPI.state.loaded()) return;
        if (!tableAPI.state.loaded().filters) return;

        const filters = tableAPI.state.loaded().filters;
        if (!filters) return;

        for (let [key, value] of Object.entries(filters)) {

            // if the all value was selected the do nothing
            if (value == "all") continue;

            const entry = $(`li[data-filter-key='${value}']`);
            entry.addClass('active');
            // change the dropdown main content
            $(`#${key}-filter-menu button`).prepend(`<i class='fas fa-filter'></i>`).find(`span`).html(entry.text());
        }

        // save the current table state
        tableAPI.state.save();
    }

}
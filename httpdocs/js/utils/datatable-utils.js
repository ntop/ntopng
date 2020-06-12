class DataTableUtils {

    /**
     * Return a standard config for the Sprymedia (c) DataTables
     */
    static getStdDatatableConfig(dom = "lBfrtip", dtButtons = []) {
        return {
            dom: dom,
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

    static setAjaxConfig(config, url, dataSrc, method = "get", params = {}) {

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
                $dropdownTitle.html($entry.html());
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

        const dropdownId = `${title}-filter-menu`;
        const $dropdownContainer = $(`<div id='${dropdownId}' class='dropdown d-inline'></div>`);
        const $dropdownButton = $(`<button class='btn-link btn dropdown-toggle' data-toggle='dropdown' type='button'></button>`);
        const $dropdownTitle = $(`<span>${title}</span>`);
        $dropdownButton.append($dropdownTitle);

        const $menuContainer = $(`<ul class='dropdown-menu' id='${title}-filter'></ul>`);

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

    }

}
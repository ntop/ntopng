jQuery.fn.dataTableExt.sErrMode = 'console';
jQuery.fn.dataTableExt.formatSecondsToHHMMSS = (data, type, row) => {
    if (isNaN(data)) return data;
    if (type == "display" && data <= 0) return ' ';
    if (type == "display") return NtopUtils.secondsToTime(data);
    return data;
};
jQuery.fn.dataTableExt.absoluteFormatSecondsToHHMMSS = (data, type, row) => {

    if (isNaN(data)) return data;
    if (type == "display" && (data <= 0)) return ' ';

    const delta = Math.floor(Date.now() / 1000) - data;
    if (type == "display") return NtopUtils.secondsToTime(delta);
    return data;
};
jQuery.fn.dataTableExt.sortBytes = (byte, type, row) => {
    if (type == "display") return NtopUtils.bytesToSize(byte);
    return byte;
};
jQuery.fn.dataTableExt.hideIfZero = (value, type, row) => {
    if (type === "display" && value === 0) return "";
    return value;
};

class DataTableFiltersMenu {

    /**
     *
     * @param {options}
     */
    constructor({tableAPI, filterMenuKey, filterTitle, filters, columnIndex}) {

        const self = this;

        this.tableAPI = tableAPI;
        this.filterTitle = filterTitle;
        this.filterMenuKey = filterMenuKey;
        this.columnIndex = columnIndex;
        this.preventUpdate = false;
        this.$datatableWrapper = $(tableAPI.context[0].nTableWrapper);

        // when the datatable has been initialized render the dropdown
        this.$datatableWrapper.on('init.dt', function() {
            self._render(filters);
        });

        // on ajax reload then update the datatable entries
        this.tableAPI.on('draw', function() {
            self._update();
        });
    }

    _countEntries(regex, data = []) {

        if (regex === undefined) {
            console.error("DataTableFiltersMenu::_countEntries() => the passed regex is undefined!");
        }

        const reg = new RegExp(regex);
        return data.filter(cellValue => reg.test(cellValue)).length;
    }

    _createMenuEntry(filter) {

        const self = this;
        const $entry = $(`<li class='dropdown-item pointer'>${filter.label} </li>`);

        if (filter.countable === undefined || filter.countable) {

            const data = this.tableAPI.columns(this.columnIndex).data()[0];
            const count = this._countEntries(filter.regex, data);
            const $counter = $(`<span class='counter'>(${count})</span>`);

            // if the count is 0 then hide the menu entry
            if (count == 0) $entry.hide();

            //append the $counter object inside the $entry
            $entry.append($counter);
        }

        $entry.click(function (e) {

            self.preventUpdate = true;

            // set active filter title and key
            if (self.$dropdown.title.parent().find(`i.fas`).length == 0) {
                self.$dropdown.title.parent().prepend(`<i class='fas fa-filter'></i>`);
            }

            const newContent = $entry.html();
            self.$dropdown.title.html(newContent);
            // remove the active class from the li elements
            self.$dropdown.container.find('li').removeClass(`active`);
            // add active class to current entry
            $entry.addClass(`active`);
            // if the filter have a callback then call it
            if (filter.callback) filter.callback();
            // perform the table filtering
            self.tableAPI.column(self.columnIndex).search(filter.regex, true, false).draw();
        });

        return $entry;
    }

    _createFilters(filters) {

        const filtersCreated = {};

        // for each filter defined in this.filters
        for (const filter of filters) {

            const $filter = this._createMenuEntry(filter);
            // save the filter inside the $filters object
            filtersCreated[filter.key] = { filter: filter, $node: $filter };
        }

        return filtersCreated;
    }

    _render(filters) {

        const $dropdownContainer = $(`<div id='${this.filterMenuKey}-filters' class='dropdown d-inline'></div>`);
        const $dropdownButton = $(`<button class='btn-link btn dropdown-toggle' data-toggle='dropdown' type='button'></button>`);
        const $dropdownTitle = $(`<span class='filter-title'>${this.filterTitle}</span>`);
        $dropdownButton.append($dropdownTitle);

        this.filters = this._createFilters(filters);

        this.$dropdown = {
            container: $dropdownContainer,
            title: $dropdownTitle,
            button: $dropdownButton
        };

        const $menuContainer = $(`<ul class='dropdown-menu scrollable-dropdown' id='${this.filterMenuKey}-filter-menu'></ul>`);
        for (const [_, filter] of Object.entries(this.filters)) {
            $menuContainer.append(filter.$node);
        }

        // the All entry is created by the object
        const allFilter = {
            key: 'all',
            label: i18n.all,
            regex: '',
            countable: false,
            callback: () => {
                this.$dropdown.title.parent().find('i.fas.fa-filter').remove();
                this.$dropdown.title.html(`${this.filterTitle}`);
            }
        };

        $menuContainer.prepend(this._createMenuEntry(allFilter));

        // append the created dropdown inside
        $dropdownContainer.append($dropdownButton);
        $dropdownContainer.append($menuContainer);
        // append the dropdown menu inside the filter wrapper
        this.$datatableWrapper.find('.dataTables_filter').prepend($dropdownContainer);

        this._selectFilterFromState(this.filterMenuKey);
    }

    _selectFilterFromState(filterKey) {

        if (!this.tableAPI.state) return;
        if (!this.tableAPI.state.loaded()) return;
        if (!this.tableAPI.state.loaded().filters) return;

        // save the current table state
        tableAPI.state.save();
    }

    _update() {

        // if the filters have not been initialized by _render then return
        if (this.filters === undefined) return;
        if (this.preventUpdate) {
            this.preventUpdate = false;
            return;
        }

        for (const [_, filter] of Object.entries(this.filters)) {
            if (filter.countable == false) continue;

            const data = this.tableAPI.columns(this.columnIndex).data()[0];
            const count = this._countEntries(filter.filter.regex, data);

            // hide the filter if the count is zero
            (count == 0) ? filter.$node.hide() : filter.$node.show();
            // update the counter label
            filter.$node.find('.counter').text(`(${count})`);
            // update the selected button counter
            this.$dropdown.button.find('.counter').text(`(${count})`);
        }
    }

}

class DataTableUtils {

    /**
     * Return a standard config for the Sprymedia (c) DataTables
     */
    static getStdDatatableConfig(dtButtons = [], dom = "<'d-flex'<'mr-auto'l><'dt-search'f>B>rtip") {

        if (dtButtons.length == 0) {
            dom = "fbrtip";
        }

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

    /**
     * Example of action:
     * {
     *  class: string,
     *  data: object,
     *  icon: string,
     *  modal: string,
     *  href: string,
     *  hidden: bool,
     * }
     * @param {*} actions
     */
    static createActionButtons(actions = []) {

        const buttons = [];
        actions.forEach((action) => {

            let button = (`
                <a
                    href='${action.href || action.modal}'
                    ${action.modal ? "data-toggle='modal'" : ""}
                    class='btn btn-sm ${action.class}'
                    ${action.hidden ? "style='display: none'" : ''}
                    >
                    <i class='fas ${action.icon}'></i>
                </a>
            `);

            buttons.push(button);
        });

        return (`<div class='actions-group' role='group'>${buttons.join('')}</div>`);
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

            extension.stateSaveCallback = function (settings, data) {
                localStorage.setItem('DataTables_' + settings.sInstance, JSON.stringify(data))
            };

            extension.stateLoadCallback = function (settings) {
                return JSON.parse(localStorage.getItem('DataTables_' + settings.sInstance));
            };

            // on saving the table state store the selected filters
            extension.stateSaveParams = function (settings, data) {

                // save the filters selected from the user inside the state
                $('[data-filter]').each(function () {

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
     * Format the passed seconds into the "HH:MM:SS" string.
     * @param {number} seconds
     */
    static secondsToHHMMSS(seconds) {

        const padZeroes = n => `${n}`.padStart(2, '0');

        const sec = seconds % 60;
        const mins = Math.floor(seconds / 60) % 60;
        const hours = Math.floor(seconds / 3600);

        return `${padZeroes(hours)}:${padZeroes(mins)}:${padZeroes(sec)}`;
    }

    /**
    * Open the pool edit modal of a chosen pool if the query params contains the pool paramater
    * @param tableAPI
    */
    static openEditModalByQuery(params) {

        const urlParams = new URLSearchParams(window.location.search);
        if (!urlParams.has(params.paramName)) return;

        const dataID = urlParams.get(params.paramName);
        const data = params.datatableInstance.data().toArray().find((data => data[params.paramName] == dataID));

        // if the cancelIf param has been passed
        // then test the cancelIf function, if the return value
        // is true then cancel the modal opening
        if (typeof(params.cancelIf) === 'function') {
            if (params.cancelIf(data)) return;
        }

        const $modal = $(`#${params.modalHandler.getModalID()}`);

        // if the pool id is valid then open the edit modal
        if (data !== undefined) {
            params.modalHandler.invokeModalInit(data);
            $modal.modal('show');
        }

        if (!urlParams.has('referer')) {
            $modal.on('hidden.bs.modal', function (e) {

                const url = new URL(window.location.href);
                url.searchParams.delete(params.paramName);

                history.replaceState({}, '', url.toString());
            });
            return;
        }
        const referer = urlParams.get('referer');

        $modal.on('hidden.bs.modal', function (e) {
            window.location = referer;
        });
    }

}

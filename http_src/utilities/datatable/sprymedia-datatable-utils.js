/**
 * (C) 2020-21 - ntop.org
 * This file contains utilities used by the *new* datatables.
 */
'use strict';

import NtopUtils from "../ntop-utils";


const DataTableHandlers = function () {
    let handlersIdDict = {};
    return {
        addHandler: function (h) {
            let handlers = handlersIdDict[h.handlerId];
            if (handlers == null) {
                handlers = [];
                handlersIdDict[h.handlerId] = handlers;
            }
            handlers.push(() => {
                h.onClick();
            });
            return `window['_DataTableButtonsOnClick']('${h.handlerId}', '${handlers.length - 1}')`;
        },
        getHandler: function (handlerId, rowId) {
            let handlers = handlersIdDict[handlerId];
            if (handlers == null) { return null; }
            return handlers[rowId];
        },
        deleteHandlersById: function (handlerId) {
            handlersIdDict[handlerId] = null;
        },
    }
}();

window["_DataTableButtonsOnClick"] = function (handlerId, rowId) {
    let onClick = DataTableHandlers.getHandler(handlerId, rowId);
    if (onClick != null) {
        onClick();
    }
}

export class DataTableFiltersMenu {

    /**
     *
     * @param {options}
     */
    constructor({ tableAPI, filterMenuKey, filterTitle, filters, columnIndex, icon = null, extraAttributes = "", id = null, url = null, urlParams = null, removeAllEntry = false, callbackFunction = null }) {
        this.rawFilters = filters;
        this.tableAPI = tableAPI;
        this.filterTitle = filterTitle;
        this.icon = icon;
        this.filterMenuKey = filterMenuKey;
        this.columnIndex = columnIndex;
        this.preventUpdate = false;
        this.currentFilterSelected = undefined;
        this.$datatableWrapper = $(tableAPI.context[0].nTableWrapper);
        this.extraAttributes = extraAttributes;
        this.id = id;
        this.url = url;
        this.removeAllEntry = removeAllEntry;
        this.callbackFunction = callbackFunction;
    }

    get selectedFilter() {
        return this.currentFilterSelected;
    }

    init() {

        const self = this;

        // when the datatable has been initialized render the dropdown
        this.$datatableWrapper.on('init.dt', function () {
            self._render(self.rawFilters);
        });

        // on ajax reload then update the datatable entries
        this.tableAPI.on('draw', function () {
            self._update();
        });

        return self;
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
        let $entry = $(`<li class='dropdown-item pointer'>${filter.label} </li>`);

        if (self.url) {
            $entry = $(`<li class='dropdown-item pointer'><a href=# class='p-1 standard-color'>${filter.label} </li>`);

            if (filter.currently_active == true) {
                // set active filter title and key
                if (self.$dropdown.title.parent().find(`i.fas`).length == 0) {
                    self.$dropdown.title.parent().prepend(`<i class='fas fa-filter'></i>`);
                }

                const newContent = $entry.html();
                self.$dropdown.title.html(newContent);
                // remove the active class from the li elements
                self.$dropdown.container.find('li').removeClass(`active`);
                // add active class to current entry
                if (filter.key !== 'all') {
                    $entry.addClass(`active`);
                }
            }
        } else if (filter.regex !== undefined && (filter.countable === undefined || filter.countable)) {
            const data = this.tableAPI.columns(this.columnIndex).data()[0];
            const count = this._countEntries(filter.regex, data);
            const $counter = $(`<span class='counter'>(${count})</span>`);

            // if the count is 0 then hide the menu entry
            if (count == 0) $entry.hide();

            //append the $counter object inside the $entry
            $entry.append($counter);
        }

        $entry.on('click', function (e) {
            // set active filter title and key
            if (self.$dropdown.title.parent().find(`i.fas`).length == 0) {
                self.$dropdown.title.parent().prepend(`<i class='fas fa-filter'></i>`);
            }

            const newContent = $entry.html();
            self.$dropdown.title.html(newContent);
            // remove the active class from the li elements
            self.$dropdown.container.find('li').removeClass(`active`);
            // add active class to current entry
            if (filter.key !== 'all') {
                $entry.addClass(`active`);
            }

            if (self.callbackFunction) {
                self.callbackFunction(self.tableAPI, filter);
                if (filter.callback) filter.callback();
                return;
            }

            if (!self.url) {
                self.preventUpdate = true;

                // if the filter have a callback then call it
                if (filter.callback) filter.callback();
                // perform the table filtering
                self.tableAPI.column(self.columnIndex).search(filter.regex, true, false).draw();
                // set current filter
                self.currentFilterSelected = filter;
            } else {
                self.urlParams = window.location.search
                const newUrlParams = new URLSearchParams(self.urlParams)
                newUrlParams.set(self.filterMenuKey, (typeof (filter.id) != "undefined") ? filter.id : '')

                window.history.pushState('', '', window.location.pathname + '?' + newUrlParams.toString())
                location.reload()
            }
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
        if (typeof this.columnIndex == 'undefined') {
            $(`<span id="${this.id}" ${this.extraAttributes} title="${this.filterTitle}">${this.icon || this.filterTitle}</span>`).insertBefore(this.$datatableWrapper.find('.dataTables_filter').parent());
        } else {
            const $dropdownContainer = $(`<div id='${this.filterMenuKey}_dropdown' class='dropdown d-inline'></div>`);
            const $dropdownButton = $(`<button class='btn-link btn dropdown-toggle' data-bs-toggle="dropdown" type='button'></button>`);
            const $dropdownTitle = $(`<span class='filter-title'>${this.filterTitle}</span>`);
            $dropdownButton.append($dropdownTitle);

            this.$dropdown = {
                container: $dropdownContainer,
                title: $dropdownTitle,
                button: $dropdownButton
            };

            this.filters = this._createFilters(filters);

            const $menuContainer = $(`<ul class='dropdown-menu dropdown-menu-lg-end scrollable-dropdown' id='${this.filterMenuKey}_dropdown_menu'></ul>`);
            for (const [_, filter] of Object.entries(this.filters)) {
                $menuContainer.append(filter.$node);
            }

            // the All entry is created by the object
            if (!this.removeAllEntry) {
                const allFilter = this._generateAllFilter();
                $menuContainer.prepend(this._createMenuEntry(allFilter));
            }

            // append the created dropdown inside
            $dropdownContainer.append($dropdownButton);
            $dropdownContainer.append($menuContainer);
            // append the dropdown menu inside the filter wrapper
            $dropdownContainer.insertBefore(this.$datatableWrapper.find('.dataTables_filter').parent());

            this._selectFilterFromState(this.filterMenuKey);
        }
    }

    _selectFilterFromState(filterKey) {

        if (!this.tableAPI.state) return;
        if (!this.tableAPI.state.loaded()) return;
        if (!this.tableAPI.state.loaded().filters) return;

        // save the current table state
        tableAPI.state.save();
    }

    _generateAllFilter() {
        return {
            key: 'all',
            label: i18n_ext.all,
            regex: '',
            countable: false,
            callback: () => {
                this.$dropdown.title.parent().find('i.fas.fa-filter').remove();
                this.$dropdown.title.html(`${this.filterTitle}`);
            }
        };
    }

    _update() {

        // if the filters have not been initialized by _render then return
        if (this.filters === undefined) return;
        if (this.preventUpdate) {
            this.preventUpdate = false;
            return;
        }

        for (const [_, filter] of Object.entries(this.filters)) {
            if (filter.countable == false || filter.filter.countable == false) continue;

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

export class DataTableUtils {

    /**
     * Return a standard config for the Sprymedia (c) DataTables
     */
    static getStdDatatableConfig(dtButtons = [], dom = "<'row'<'col-sm-2 d-inline-block'l><'col-sm-10 text-end d-inline-block'<'dt-search'f>B>rtip>") {

        // hide the buttons section if there aren't buttons inside the array
        if (dtButtons.length == 0) {
            dom = "fBrtip";
        }

        return {
            dom: dom,
            pagingType: 'full_numbers',
            lengthMenu: [[10, 20, 50, 100], [10, 20, 50, 100]],
            language: {
                search: i18n.script_search,
                paginate: {
                    previous: '&lt;',
                    next: '&gt;',
                    first: '«',
                    last: '»'
                }
            },
            saveState: true,
            responsive: true,
            buttons: {
                buttons: dtButtons,
                dom: {
                    button: {
                        className: 'btn btn-link'
                    },
                    container: {
                        className: 'd-inline-block'
                    }
                }
            }
        }
    }

    static createLinkCallback(action) {
        let handler = "";
        let fOnClick = DataTableHandlers.addHandler(action.handler);
        handler = `onclick="${fOnClick}"`;
        return `<a href=#
                   ${handler}>
                   ${action.text || ''}
                </a>`;
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
        const dropdownButton = '<button type="button" class="btn btn-sm btn-secondary dropdown-toggle" data-bs-toggle="dropdown" aria-expanded="false"><i class="fas fa-align-justify"></i></button>'

        actions.forEach((action, i) => {
            let handler = "";
            if (action.handler) {
                let fOnClick = DataTableHandlers.addHandler(action.handler);
                handler = `onclick="${fOnClick}"`;
            }
            let button = (`
            <li>
                <a
                    ${(action.href || action.modal) ? `href='${action.href || action.modal}'` : ``}
                    ${handler}
                    ${(action.onclick) ? `onclick='${action.onclick}'` : ``}
                    ${action.modal ? "data-bs-toggle='modal'" : ``}
                    class='dropdown-item ${action.class ? action.class : ``}'
                    ${action.hidden ? "style='display: none'" : ``}
                    ${action.external ? "target='_about'" : ``}
                    >
                    <i class='fas ${action.icon}'></i> ${action.title || ''}
                </a>
            </li>
            `);
            buttons.push(button);
        });

        const list = `<ul class="dropdown-menu">${buttons.join('')}</ul>`

        return (`<div class='dropdown'>${dropdownButton}${list}</div>`);
    }

    static deleteButtonHandlers(handlerId) {
        DataTableHandlers.deleteHandlersById(handlerId);
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

        // const userInitComplete = extension.initComplete;

        // const initComplete = (settings, json) => {
        //     if (userInitComplete !== undefined) userInitComplete(settings, json);
        //     // turn on tooltips
        //     $(`.actions-group [title]`).tooltip('enable');
        // };

        // // override initComplete function
        // extension.initComplete = initComplete;

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
        if (typeof (params.cancelIf) === 'function') {
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

    static addToggleColumnsDropdown(tableAPI, toggleCallback = (col, visible) => { }) {

        if (tableAPI === undefined) {
            throw 'The $table is undefined!';
        }

        const tableID = tableAPI.table().node().id;

        DataTableUtils._loadColumnsVisibility(tableAPI).then(function (fetchedData) {

            let savedColumns = [-1];
            if (fetchedData.success) {
                savedColumns = fetchedData.columns.map(i => parseInt(i));
            }
            else {
                console.warn(fetchedData.message);
            }

            const columns = [];
            const ignoredColumns = [];
            const $datatableWrapper = $(tableAPI.context[0].nTableWrapper);

            // get the table headers 
            tableAPI.columns().every(function (i) {

                // avoid already hidden columns
                if (!tableAPI.column(i).visible()) {
                    ignoredColumns.push(i);
                    return;
                }

                columns.push({ index: i, name: this.header().textContent, label: this.i18n.name /* Human-readable column name */ });
            });

            const $btnGroup = $(`
                <div class="btn-group">
                    <button type="button" class="btn btn-link dropdown-toggle" data-bs-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
                        <i class="fas fa-eye"></i>
                    </button>
                </div>
            `);

            const $dropdownMenu = $(`<div class="dropdown-menu dropdown-menu-right" style='width: max-content;'><h6 class="dropdown-header">Show Columns</h6></div>`);
            const $checkboxes = $(`<div class='px-4'></div>`);

            for (let i = 0; i < columns.length; i++) {
                const column = columns[i];

                // Prevents columns with no names to be selectively hidden (e.g., the entity under the all alerts page)
                if (column.name == "")
                    continue;

                // create a checkbox and delegate a change event
                const id = `toggle-${column.name.split().join('_')}`;

                // check if the column id it's inside the savedColumns array
                // if toggled is true then the column is not hidden
                const toggled = savedColumns.indexOf(column.index) === -1;
                if (!toggled) {
                    const col = tableAPI.column(column.index);
                    col.visible(false);
                }

                const $checkbox = $(`<input class="form-check-input" ${(toggled ? 'checked' : '')} type="checkbox" id="${id}">`);
                const $wrapper = $(`
                    <div class="form-check form-switch">
                        <label class="form-check-label" for="${id}">
                            ${column.name}
                        </label>
                    </div>
                `);

                $checkbox.on('change', function (e) {
                    $(`.overlay`).toggle(500);

                    // Get the column API object
                    const col = tableAPI.column(column.index);
                    // Toggle the visibility
                    col.visible(!col.visible());

                    const visible = col.visible();

                    const hiddenColumns = [];
                    // insert inside the array only the hidden columns
                    tableAPI.columns().every(function (i) {
                        if (tableAPI.column(i).visible() || ignoredColumns.indexOf(i) !== -1) return;
                        hiddenColumns.push(i);
                    });

                    // save the table view inside redis
                    $.post(`${http_prefix}/lua/datatable_columns.lua`, {
                        action: 'save', table: tableID, columns: hiddenColumns.join(','), csrf: window.__CSRF_DATATABLE__
                    }).then(function (data) {
                        if (data.success) return;
                        console.warn(data.message);
                    });

                    if (toggleCallback !== undefined) {
                        toggleCallback(col, visible);
                    }

                });

                $wrapper.prepend($checkbox);
                $checkboxes.append($wrapper);
            }

            $dropdownMenu.on("click.bs.dropdown", function (e) { e.stopPropagation(); });

            // append the new node inside the datatable
            $btnGroup.append($dropdownMenu.append($checkboxes));
            $datatableWrapper.find('.dt-search').parent().append($btnGroup);
        });
    }

    static async _loadColumnsVisibility(tableAPI) {
        const tableID = tableAPI.table().node().id;
        return $.get(`${http_prefix}/lua/datatable_columns.lua?table=${tableID}&action=load`);
    }

}

export class DataTableRenders {

    static alertSeverityAndType(severity, type, alert) {
        return `${DataTableRenders.formatValueLabel(severity, type, alert)} ${DataTableRenders.formatValueLabel(alert.alert_id, type, alert)}`;
    }

    static hideIfZero(obj, type, row, zero_is_null) {
        let color = (obj.color !== undefined ? obj.color : "#aaa");
        let value = (obj.value !== undefined ? obj.value : obj);
        if (type === "display" && parseInt(value) === 0) color = "#aaa";
        let span = `<span style='color: ${color}'>${NtopUtils.fint(value)}</span>`;
        if (obj.url !== undefined) span = `<a href="${obj.url}">${span}</a>`;
        return span;
    }

    static secondsToTime(seconds, type, row, zero_is_null) {
        if (type === "display") return NtopUtils.secondsToTime(seconds);
        return seconds;
    }

    static filterize(key, value, label, tag_label, title, html, is_snmp_ip, ip) {
        let content = `<a class='tag-filter' data-tag-key='${key}' title='${title || value}' data-tag-value='${value}' data-tag-label='${tag_label || label || value}' href='javascript:void(0)'>${html || label || value}</a>`;
        if (is_snmp_ip != null) {
            if (is_snmp_ip) {
                if (value) {
                    let url = NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?host=${value}`);
                    content += ` <a href='${url}'data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;
                }
            } else {
                if (ip && value) {

                    if (value.includes(ip)) {
                        value = value.split("_")[1];
                    }
                    let url = NtopUtils.buildURL(`${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${ip}&snmp_port_idx=${value}`);
                    content += ` <a href='${url}'data-bs-toggle='tooltip' title=''><i class='fas fa-laptop'></i></a>`;
                }
            }
        }
        return content;
    }

    static formatValueLabel(obj, type, row, zero_is_null) {
        if (type !== "display") return obj.value;
        let cell = obj.label;
        if (zero_is_null == true && obj.value == 0) {
            cell = "";
        }
        if (obj.color) cell = `<span class='font-weight-bold' style='color: ${obj.color}'>${cell}</span>`;
        return cell;
    }

    static formatCategory(obj, type, row, zero_is_null) {
        if (type !== "display") return obj.value;
        let cell = `<a class='tag-filter' data-tag-key='alert_category' data-tag-value='${obj.value}' data-tag-label='${obj.label}' href='javascript:void(0)'><i class="fa fas ${obj.icon}" title="${obj.label}"></i></a>`;
        if (zero_is_null == true && obj.value == 0) {
            cell = "";
        }
        return cell;
    }

    static formatMitreId(obj) {
        if (obj.mitre_id !== "0") {
            return DataTableRenders.filterize('mitre_id', obj.mitre_id, obj.mitre_id_i18n, obj.mitre_id_i18n, obj.mitre_id_i18n);
        }
        return ""
    }
    
    static formatMitreTactic(obj) {
        if (obj.mitre_tactic !== "0") {
            return DataTableRenders.filterize('mitre_tactic', obj.mitre_tactic, i18n(obj.mitre_tactic_i18n), obj.mitre_tactic_i18n, obj.mitre_tactic_i18n);
        }

        return ""
    }
    
    static formatMitreTechnique(obj) {
        if (obj.mitre_technique !== "0") {
            return DataTableRenders.filterize('mitre_technique', obj.mitre_technique, i18n(obj.mitre_technique_i18n), obj.mitre_technique_i18n, obj.mitre_technique_i18n);
        }
        return ""
    }

    static formatMitreSubTechnique(obj) {
        if (obj.mitre_subtechnique !== "0") {
            return DataTableRenders.filterize('mitre_subtechnique', obj.mitre_subtechnique, i18n(obj.mitre_subtechnique_i18n), obj.mitre_subtechnique_i18n, obj.mitre_subtechnique_i18n);
        }
        return ""
    }

    static formatScore(obj, type, row, zero_is_null) {
        if (type !== "display") return obj.value;
        let cell = obj.label;
        if (zero_is_null == true && obj.value == 0) {
            cell = "";
        }
        if (obj.color) cell = `<span class='font-weight-bold' style='color: ${obj.color}'>${cell}</span>`;
        return `<a class='tag-filter' data-tag-key='score' title='${obj.label}' data-tag-value='${obj.value}' data-tag-label='${obj.label}' href='javascript:void(0)'>${cell}</a>`;
    }

    static formatMessage(obj, type, row, zero_is_null) {
        if (type !== "display") return obj.value;

        let cell = obj.descr;
        if (obj.shorten_descr)
            cell = `<span title="${obj.descr}">${obj.shorten_descr}</span>`;

        return cell;
    }

    static formatTraffic(obj, type, row, zero_is_null) {
        if (type !== "display") return obj.total_bytes;

        const traffic = `${NtopUtils.formatPackets(obj.total_packets)} / ${NtopUtils.bytesToVolume(obj.total_bytes)}`
        return traffic;
    }

    static formatSubtype(obj, type, row, zero_is_null) {
        if (type !== "display") return obj;

        let label = DataTableRenders.filterize('subtype', obj, obj);

        return label;
    }

    static filterize_2(key, value, label, tag_label, title, html) {
        if (value == null || (value == 0 && (label == null || label == ""))) { return ""; }
        return `<a class='tag-filter' data-tag-key='${key}' title='${title || value}' data-tag-value='${value}' data-tag-label='${tag_label || label || value}' href='javascript:void(0)'>${html || label || value}</a>`;
    }

    static getFormatGenericField(field, zero_is_null) {
        return function (obj, type, row) {
            if (type !== "display") return obj.value;
            if (zero_is_null == true && obj?.value == 0) { return ""; }
            let html_ref = '';
            if (obj.reference !== undefined)
                html_ref = obj.reference
            let label = DataTableRenders.filterize_2(field, row[field].value, row[field].label, row[field].label, row[field].label);
            return label + ' ' + html_ref;
        }
    }

    static formatSNMPInterface(obj, type, row) {
        if (type !== "display") return obj.value;
        if (obj.value === undefined || obj.value == '')
            return ''; /* interface not defined - probably a device-level alert */
        let cell = DataTableRenders.filterize('snmp_interface', `${row.ip}_${obj.value}`, obj.label, obj.label, obj.label, null, false, row.ip);
        if (obj.color) cell = `<span class='font-weight-bold' style='color: ${obj.color}'>${cell}</span>`;
        return cell;
    }

    static formatSNMPIP(obj, type, row, zero_is_null) {
        if (type !== "display") return obj;
        return DataTableRenders.filterize('ip', obj, obj, obj, obj, null, true);
    }

    static formatNetwork(obj, type, row, zero_is_null) {
        if (type !== "display") return obj;
        return DataTableRenders.filterize('network_name', obj, obj, obj, obj, null, false);
    }

    static formatProbeIP(obj, type, row, zero_is_null) {
        if (type !== "display") return obj;

        let label = DataTableRenders.filterize('probe_ip', obj.value, obj.label, obj.label, obj.label_long);

        return label;
    }

    static formatHost(obj, type, row, zero_is_null) {
        if (type !== "display") return obj;
        let html_ref = '';
        if (obj.reference !== undefined)
            html_ref = obj.reference;
        let label = "";

        let hostKey, hostValue;
        if (obj.label && obj.label != obj.value) {
            hostKey = "name";
            hostValue = obj.label_long;
            label = DataTableRenders.filterize('name', obj.label_long, obj.label, obj.label, obj.label_long);
        }
        else {
            hostKey = "ip";
            hostValue = obj.value;
            label = DataTableRenders.filterize('ip', obj.value, obj.label, obj.label, obj.label_long);
        }

        if (row.vlan_id && row.vlan_id != "" && row.vlan_id != "0") {
            label = DataTableRenders.filterize(hostKey, `${hostValue}@${row.vlan_id}`, `${obj.label}@${row.vlan_id}`, `${obj.label}@${row.vlan_id}`, `${obj.label_long}@${row.vlan_id}`);
        }

        if (obj.country)
            label = label + DataTableRenders.filterize('country', obj.country, obj.country, obj.country, obj.country, ' <img src="' + http_prefix + '/dist/images/blank.gif" class="flag flag-' + obj.country.toLowerCase() + '"></a> ');

        if (obj.is_multicast) {
            label = label + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("multicast") + "'><span class='badge bg-primary'>" + i18n("short_multicast") + "</span></abbr> "
        } else if (obj.is_local) {
            label = label + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("details.label_local_host") + "'><span class='badge bg-success'>" + i18n("details.label_short_local_host") + "</span></abbr> "
        } else {
            label = label + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("details.label_remote") + "'><span class='badge bg-secondary'>" + i18n("details.label_short_remote") + "</span></abbr> "
        }

        if (row.role && row.role.value == 'attacker')
            label = label + ' ' + DataTableRenders.filterize('role', row.role.value,
                '<i class="fas fa-skull" title="' + row.role.label + '"></i>', row.role.label);
        else if (row.role && row.role.value == 'victim')
            label = label + ' ' + DataTableRenders.filterize('role', row.role.value,
                '<i class="fas fa-sad-tear" title="' + row.role.label + '"></i>', row.role.label);

        if (row.role_cli_srv && row.role_cli_srv.value == 'client')
            label = label + ' ' + DataTableRenders.filterize('role_cli_srv', row.role_cli_srv.value,
                '<i class="fas fa-long-arrow-alt-right" title="' + row.role_cli_srv.label + '"></i>', row.role_cli_srv.label);
        else if (row.role_cli_srv && row.role_cli_srv.value == 'server')
            label = label + ' ' + DataTableRenders.filterize('role_cli_srv', row.role_cli_srv.value,
                '<i class="fas fa-long-arrow-alt-left" title="' + row.role_cli_srv.label + '"></i>', row.role_cli_srv.label);

        return label + ' ' + html_ref;
    }

    static filterizeVlan(flow, row, key, value, label, title) {
        let valueVlan = value;
        let labelVlan = label;
        let titleVlan = title;
        if (flow.vlan && flow.vlan.value != 0) {
            valueVlan = `${value}@${flow.vlan.value}`;
            labelVlan = `${label}@${flow.vlan.label}`;
            titleVlan = `${title}@${flow.vlan.title}`;
        }
        return DataTableRenders.filterize(key, valueVlan, labelVlan, labelVlan, titleVlan);
    }

    static formatFlowTuple(flow, type, row, zero_is_null) {
        let active_ref = (flow.active_url ? `<a href="${flow.active_url}"><i class="fas fa-stream"></i></a>` : "");
        let cliLabel = "";
        if (flow.cli_ip.name) {
            let title = "";
            if (flow.cli_ip.label_long) title = flow.cli_ip.value + " [" + flow.cli_ip.label_long + "]";
            cliLabel = DataTableRenders.filterizeVlan(flow, row, 'cli_name', flow.cli_ip.name, flow.cli_ip.label, title);
        } else
            cliLabel = DataTableRenders.filterizeVlan(flow, row, 'cli_ip', flow.cli_ip.value, flow.cli_ip.label, flow.cli_ip.label_long);

        let cliFlagLabel = ''

        if (flow.cli_ip.country && flow.cli_ip.country !== "nil")
            cliFlagLabel = DataTableRenders.filterize('cli_country', flow.cli_ip.country, flow.cli_ip.country, flow.cli_ip.country, flow.cli_ip.country, ' <img src="' + http_prefix + '/dist/images/blank.gif" class="flag flag-' + flow.cli_ip.country.toLowerCase() + '"></a> ');

        let cliPortLabel = ((flow.cli_port && flow.cli_port.value && flow.cli_port.value != 0) ? ":" + DataTableRenders.filterize('cli_port', flow.cli_port.value, flow.cli_port.label) : "");

        let cliBlacklisted = ''
        if (flow.cli_ip.blacklisted == true)
            cliBlacklisted = " <i class=\'fas fa-ban fa-sm\' title=\'" + i18n("hosts_stats.blacklisted") + "\'></i>"

        let cliLocation = ''
        if (flow.cli_ip.location == 'multicast') {
            cliLocation = cliLocation + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("multicast") + "'><span class='badge bg-primary'>" + i18n("short_multicast") + "</span></abbr> "
        } else if (flow.cli_ip.location == 'local') {
            cliLocation = cliLocation + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("details.label_local_host") + "'><span class='badge bg-success'>" + i18n("details.label_short_local_host") + "</span></abbr> "
        } else {
            cliLocation = cliLocation + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("details.label_remote") + "'><span class='badge bg-secondary'>" + i18n("details.label_short_remote") + "</span></abbr> "
        }

        let srvLabel = ""
        if (flow.srv_ip.name) {
            let title = "";
            if (flow.srv_ip.label_long) title = flow.srv_ip.value + " [" + flow.srv_ip.label_long + "]";
            srvLabel = DataTableRenders.filterizeVlan(flow, row, 'srv_name', flow.srv_ip.name, flow.srv_ip.label, title);
        } else
            srvLabel = DataTableRenders.filterizeVlan(flow, row, 'srv_ip', flow.srv_ip.value, flow.srv_ip.label, flow.srv_ip.label_long);
        let srvPortLabel = ((flow.srv_port && flow.srv_port.value && flow.srv_port.value != 0) ? ":" + DataTableRenders.filterize('srv_port', flow.srv_port.value, flow.srv_port.label) : "");

        let srvFlagLabel = ''

        if (flow.srv_ip.country && flow.srv_ip.country !== "nil")
            srvFlagLabel = DataTableRenders.filterize('srv_country', flow.srv_ip.country, flow.srv_ip.country, flow.srv_ip.country, flow.srv_ip.country, ' <img src="' + http_prefix + '/dist/images/blank.gif" class="flag flag-' + flow.srv_ip.country.toLowerCase() + '"></a> ');

        let srvBlacklisted = ''
        if (flow.srv_ip.blacklisted == true)
            srvBlacklisted = " <i class=\'fas fa-ban fa-sm\' title=\'" + i18n("hosts_stats.blacklisted") + "\'></i>"

        let srvLocation = ''
        if (flow.srv_ip.location == 'multicast') {
            srvLocation = srvLocation + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("multicast") + "'><span class='badge bg-primary'>" + i18n("short_multicast") + "</span></abbr> "
        } else if (flow.srv_ip.location == 'local') {
            srvLocation = srvLocation + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("details.label_local_host") + "'><span class='badge bg-success'>" + i18n("details.label_short_local_host") + "</span></abbr> "
        } else {
            srvLocation = srvLocation + " <abbr data-bs-toggle='tooltip' data-bs-placement='bottom' title='" + i18n("details.label_remote") + "'><span class='badge bg-secondary'>" + i18n("details.label_short_remote") + "</span></abbr> "
        }

        let cliIcons = "";
        let srvIcons = "";
        if (row.cli_role) {
            if (row.cli_role.value == 'attacker')
                cliIcons += DataTableRenders.filterize('role', 'attacker', '<i class="fas fa-skull" title="' + row.cli_role.label + '"></i>', row.cli_role.tag_label);
            else if (row.cli_role.value == 'victim')
                cliIcons += DataTableRenders.filterize('role', 'victim', '<i class="fas fa-sad-tear" title="' + row.cli_role.label + '"></i>', row.cli_role.tag_label);
        }

        if (row.srv_role) {
            if (row.srv_role.value == 'attacker')
                srvIcons += DataTableRenders.filterize('role', 'attacker', '<i class="fas fa-skull" title="' + row.srv_role.label + '"></i>', row.srv_role.tag_label);
            else if (row.srv_role.value == 'victim')
                srvIcons += DataTableRenders.filterize('role', 'victim', '<i class="fas fa-sad-tear" title="' + row.srv_role.label + '"></i>', row.srv_role.tag_label);
        }

        return `${active_ref} ${cliLabel}${cliBlacklisted}${cliLocation}${cliFlagLabel}${cliPortLabel} ${cliIcons} ${flow.cli_ip.reference} <i class="fas fa-exchange-alt fa-lg" aria-hidden="true"></i> ${srvLabel}${srvBlacklisted}${srvLocation}${srvFlagLabel}${srvPortLabel} ${srvIcons} ${flow.srv_ip.reference}`;
    }

    static formatSubtypeValueLabel(obj, type, row, zero_is_null) {
        if (type !== "display") return obj.name;
        let msg = DataTableRenders.filterize('subtype', obj.value, obj.name, obj.fullname, obj.fullname);

        return msg;
    }

    static formatNameDescription(obj, type, row, zero_is_null) {
        if (type !== "display") return obj.name;
        let msg = DataTableRenders.filterize('alert_id', obj.value, obj.name, obj.fullname, obj.fullname);

        return msg;
    }

    static applyCellStyle(cell, cellData, rowData, rowIndex, colIndex) {
        if (cellData.highlight) {
            $(cell).css("border-left", "5px solid " + cellData.highlight);
        }
    }
}

<!-- (C) 2022 - ntop.org     -->
<template>
    <slot name="custom_header2"></slot>
    <div ref="tableContainerRef" :id="id">
        <!-- Loading during data fetch-->
        <Loading v-if="isLoading"></Loading>
        <div class="button-group mb-2 d-flex align-items-center"> <!-- TableHeader -->
            <div class="form-group d-flex align-items-end" style="flex-wrap: wrap;">
                <!-- Slot for custom header--> 
                <slot name="custom_header"></slot>
            </div>

            <div style="text-align:right;" class="form-group d-flex align-items-center ms-auto">
                <div class="d-flex align-items-center">
                    <!-- Rows per page selector-->
                    <div class="me-2">
                        <label>
                            <select v-model="rowsPerPage" @change="change_per_page">
                                <option v-for="rowsPerPage in rowsPerPageOptions" :value="rowsPerPage">{{ rowsPerPage }}</option>
                            </select>
                        </label>
                    </div>

                    <!-- Custom buttons slot -->
                    <slot name="custom_buttons"></slot>
                    
                    <!-- Reset columns size-->
                    <button class="btn btn-link" type="button" @click="reset_column_size">
                        <i class="fas fa-columns" data-bs-toggle="tooltip" data-bs-placement="top"
                            :title="_i18n('reset_column')"></i>
                    </button>
                    
                    <!-- Refresh table -->
                    <button class="btn btn-link" type="button" @click="refresh_table()">
                        <i class="fas fa-refresh" data-bs-toggle="tooltip" data-bs-placement="top"
                            :title="_i18n('refresh')"></i>
                    </button>
                    
                    <!-- Autorefresh toggle -->
                    <div v-if="show_autorefresh > 0" class="d-inline-block">
                        <Switch v-model:value="isAutoRefreshEnabled" class="me-2 mt-1" :title="autorefresh_title" style=""
                            @change_value="update_autorefresh">
                        </Switch>
                    </div>

                    <Dropdown :id="id + '_dropdown'" ref="dropdownRef"> <!-- Dropdown columns -->
                        <template v-slot:title>
                            <i class="fas fa-eye" data-bs-toggle="tooltip" data-bs-placement="top"
                                :title="_i18n('visible_columns')"></i>
                        </template>
                        <template v-slot:menu>
                            <div v-for="col in processedColumns" class="form-check form-switch ms-1">
                                <input class="form-check-input" style="cursor:pointer;" :checked="col.visible == true"
                                    @click="change_columns_visibility(col)" type="checkbox" :id="get_col_id(col)">
                                <label class="form-check-label" :for="get_col_id(col)"
                                    v-html="print_column_name(col.data)">
                                </label>
                            </div>
                        </template>
                    </Dropdown> <!-- Dropdown columns -->

                    <!-- Columns search if enabled in table json definition -->
                    <div v-if="enable_search" class="d-inline me-2 ms-auto">
                        <label>{{ _i18n('search') }}:
                            <input type="search" v-model="searchString" @input="on_change_map_search" class="">
                        </label>
                    </div>
                </div>
            </div>
        </div> <!-- TableHeader -->

        <div :key="table_key" style="overflow:auto;width:100%;"> <!-- Table -->

            <!-- Message display -->
            <div v-if="display_message == true" class="centered-message">
                <span v-html="message_to_display"></span>
            </div>

            <table ref="tableRef" class="table table-striped table-bordered ml-0 mr-0 mb-0 ntopng-table"
                :class="[(display_message || isLoading) ? 'ntopng-gray-out' : '']" data-resizable="true"
                :data-resizable-columns-id="id"> <!-- Table -->
                <thead>
                    <tr>
                        <!-- Column Headers -->
                        <template v-for="(col, col_index) in processedColumns">
                            <th v-if="col.visible" scope="col"
                                :class="{ 'pointer': col.sortable, 'unset': !col.sortable, }"
                                style="white-space: nowrap;"
                                :style="[(col.min_width ? 'min-width: ' + col.min_width + ';' : '')]"
                                @click="change_column_sort(col, col_index)"
                                :data-resizable-column-id="get_column_id(col.data)">
                                <div style="display:flex;">
                                    <!-- Print column name -->
                                    <span v-html="print_column_name(col.data)" class="wrap-column"></span>

                                    <!-- Sort indicators, 0 double arrow, else up or down-->
                                    <!-- <i v-show="col.sort == 0" class="fa fa-fw fa-sort"></i> -->
                                    <i v-show="col.sort == 1 && col.sortable" class="fa fa-fw fa-sort-up"></i>
                                    <i v-show="col.sort == 2 && col.sortable" class="fa fa-fw fa-sort-down"></i>
                                </div>
                            </th>
                        </template>
                    </tr>
                </thead>
                <tbody>
                    <!-- Data rows -->
                    <tr v-if="!isChangingColumnVisibility && !isChangingRows" v-for="row in displayedRows">
                        <template v-for="(col, col_index) in processedColumns">
                            <td v-if="col.visible" scope="col" class="">
                                <!-- HTML content if provided -->
                                <div v-if="print_html_row != null && print_html_row(col.data, row, true) != null"
                                :class="col.classes" class="wrap-column" :style="col.style"
                                v-html="print_html_row(col.data, row)">
                            </div>
                            <div :style="col.style" style="" class="wrap-column margin-sm" :class="col.classes">
                                    <!-- Vue node if provided -->
                                    <VueNode :key="row"
                                        v-if="print_vue_node_row != null && print_vue_node_row(col.data, row, vue_obj, true) != null"
                                        :content="print_vue_node_row(col.data, row, vue_obj)"></VueNode>
                                </div>
                            </td>
                        </template>
                    </tr>
                    <!-- Show empty rows if present -->
                    <tr v-if="display_empty_rows && displayedRows.length < rowsPerPage"
                        v-for="index in (rowsPerPage - displayedRows.length)">
                        <template v-for="(col, col_index) in processedColumns">
                            <td style="" class="" v-if="col.visible" scope="col">
                                <div class="wrap-column"></div>
                            </td>
                        </template>
                    </tr>
                </tbody>
            </table> <!-- Table -->
        </div> <!-- Table div-->

        <div>
            <!-- Pagination component, bottom right -->
            <SelectTablePage ref="paginationRef" :key="searchDelay" :total_rows="totalRowCount"
                :per_page="rowsPerPage" @change_active_page="change_active_page">
            </SelectTablePage>
        </div>

        <!-- SQL Query info footer, if present -->
        <div v-if="query_info != null" class="mt-2">
            <div class="text-end">
                <small style="" class="query text-end"><span class="records">{{ query_info.num_records_processed
                        }}</span>.</small>
            </div>
            <div class="text-start">
                <small id="historical_flows_table-query-time" style="" class="query">Query performed in <span
                        class="seconds">{{
        (query_info.query_duration_msec / 1000).toFixed(3) }}</span> seconds. <span
                        id="historical_flows_table-query" style="cursor: pointer;" class="badge bg-secondary"
                        :title=query_info.query @click="copy_query_into_clipboard"
                        ref="sqlButtonRef">SQL</span></small>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, computed, watch, nextTick, onUpdated } from "vue";
import { h } from 'vue';
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import { default as Dropdown } from "./dropdown.vue";
import { default as SelectTablePage } from "./select_table_page.vue";
import { default as VueNode } from "./vue_node.vue";
import { default as Loading } from "./loading.vue";
import { default as Switch } from "./switch.vue";
import NtopUtils from "../utilities/ntop-utils.js";

/* rows_loaded, is emitted every time the rows are loaded,
 * loaded,      is emitted when the table is loaded (mounted)
 */
const emit = defineEmits(['custom_event', 'loaded', 'rows_loaded']);
const vue_obj = {
    emit,
    h,
    nextTick,
};

const props = defineProps({
    id: String,                     // table id   
    columns: Array,                 // table columns
    get_rows: Function,             // async (currentPage: number, rowsPerPage: number, processedColumns: any[], search_map: string, isFirstDataLoad: boolean) => { totalRowCount: number, rows: any[], query_info: { query_duration_msec: number, num_records_processed: string, query: string } }
    get_column_id: Function,        // function to 
    print_column_name: Function,    // Function to render column header text/HTML
    print_html_row: Function,       // Function to render cell HTML content
    print_vue_node_row: Function,   // Function to render Vue component in cell
    f_is_column_sortable: Function, // Function to determine if column is sortable
    f_column_min_width: Function,   // Function to determine column minimum width
    f_sort_rows: Function,          // Function for custom row sorting
    f_get_column_classes: Function, // Function to get CSS classes for column
    f_get_column_style: Function,   // Function to get inline styles for column
    enable_search: Boolean,         // Enable search functionality
    display_empty_rows: Boolean,    // Show empty rows to maintain table height  
    show_autorefresh: Number,       // autorefresh seconds, if null or 0 autorefresh switch will not showed
    default_sort: Object,           // { column_id: string, sort: number (0, 1, 2) }
    csrf: String,                   // CSRF token for API calls
    paging: Boolean,                // Enable server-side pagination
    display_message: Boolean,       // Display a message instead of the table
    message_to_display: String,     // Message to display    
});

// Get number of rows shown per page from local storage
const get_num_pages = function () {
    return Number(localStorage.getItem("ntopng.tables.rowPerPage")) || 10;
}

const _i18n = (t) => i18n(t);

const tableContainerRef = ref(null);                   // Reference to the table container
const tableRef = ref(null);                             // Reference to the table element
const dropdownRef = ref(null);                          // Reference to the column visibility dropdown
const rowElementRefs = ref([]);                   // References to row HTML elements
let currentPage = 0;                                 // Current active page
let allRows = [];                                       // All fetched rows data
const processedColumns = ref([]);                        // Wrapped column definitions with extra properties
const displayedRows = ref([]);                         // Rows displayed in the current page
const totalRowCount = ref(0);                           // Total number of rows (for pagination)
const rowsPerPageOptions = [10, 20, 40, 50, 80, 100];  // Available rows per page options
const rowsPerPage = ref(get_num_pages());               // Current rows per page setting
const columnWidthStore = window.store;                          // Store for column width persistence
const searchString = ref("");                          // Search term
             
const paginationRef = ref(null);                 // Reference to pagination component
const isLoading = ref(false);                          // Loading state flag
const query_info = ref(null);                        // Query execution info (time, records, SQL)
const sqlButtonRef = ref(null);             // Reference to SQL button for copy to clipboard
const isChangingColumnVisibility = ref(false);       // Flag for column visibility changes
const isChangingRows = ref(false);                    // Flag for row data changes
const isAutoRefreshEnabled = ref(false);               // Auto-refresh state

onMounted(async () => {
    if (props.columns != null) {
        load_table();
    }
});

// refresh bootstrap tooltip
onUpdated(() => {
    NtopUtils.reloadBSTooltips();
});

// autorefresh tooltip text
const autorefresh_title = computed(() => {
    if (props.show_autorefresh == null || props.show_autorefresh <= 0) {
        return "";
    }
    let text = _i18n("table.autorefresh");
    return text.replace("%time", props.show_autorefresh);
});

watch(() => [props.id, props.columns], (cur_value, old_value) => {
    load_table();
}, { flush: 'pre' });

// get column id as defined in the json of the table definition
function get_col_id(col) {
    if (col != null && col.id != null) {
        return col.id;
    } else {
        return "toggle-Begin";
    }
}

// init table with columns and rows
async function load_table() {
    await set_columns_wrap();       // Prepare column definitions
    await set_rows();               // Fetch initial rows
    set_columns_resizable();        // Initialize resizable columns
    dropdownRef.value.load_menu();     // Initialize dropdown menu
    emit("loaded");                 // Emit loaded event
}

// autorefresh interval and enabling
let refreshInterval;
function update_autorefresh() {
    if (isAutoRefreshEnabled.value == false) {
        clearInterval(refreshInterval);
        return;
    }
    refreshInterval = setInterval(() => {
        change_active_page();
    }, props.show_autorefresh * 1000);
}

async function change_columns_visibility(col) {
    isChangingColumnVisibility.value = true;
    col.visible = !col.visible;

    // if server side pagination, get rows
    if (props.paging) {
        await set_rows();
    }

    // redraw with new visibility
    // redraw_table();
    await redraw_table_resizable();
    await set_columns_visibility();
    // set_columns_resizable();
    isChangingColumnVisibility.value = false;
}

async function redraw_table_resizable() {
    await redraw_table();
    set_columns_resizable();
}

// increase table key to force vuejs to rerender table
const table_key = ref(0);
async function redraw_table() {
    table_key.value += 1;
    await nextTick();
}

function set_columns_resizable() {
    let options = {
        store: columnWidthStore, // persist column width
        minWidth: 70,
    };
    $(tableRef.value).resizableColumns(options);
}

// get table configuration
async function get_columns_visibility_dict() {
    if (props.csrf == null) { return {}; }

    // build request parameters
    // fetches tableId (in httpdocs/tables_config/<tableId>.json where the table scheme is defined)
    const params = { table_id: props.id };
    const url_params = ntopng_url_manager.obj_to_url_params(params);
    const url = `${http_prefix}/lua/rest/v2/get/tables/user_columns_config.lua?${url_params}`;
    let columns_visible = await ntopng_utility.http_request(url);
    let columns_visible_dict = {};

    // convert to dictionary
    columns_visible.forEach((c) => {
        columns_visible_dict[c.id] = c;
    });

    return columns_visible_dict;
}

// save columns visibility in backend
async function set_columns_visibility() {
    if (props.csrf == null) { return; }

    // prepare request parameters with column configuration
    let params = { table_id: props.id, visible_columns_ids: [], csrf: props.csrf };
    params.visible_columns_ids = processedColumns.value.map((c, i) => {
        return {
            id: c.id,
            visible: c.visible,
            order: c.order,
            sort: c.sort,
        };
    });

    // post configuration to server
    const url = `${http_prefix}/lua/rest/v2/add/tables/user_columns_config.lua`;
    await ntopng_utility.http_post_request(url, params);
}

// preapre column definitions with visibility and sort 
async function set_columns_wrap() {

    // get configuration
    let cols_visibility_dict = await get_columns_visibility_dict();

    // check if table has sorting enabled
    let is_table_not_sorted = true;
    for (let id in cols_visibility_dict) {
        is_table_not_sorted &= (cols_visibility_dict[id]?.sort);
    }

    // process column definitions
    processedColumns.value = props.columns.map((c, i) => {
        let classes = [];
        let style = "";

        // get column CSS class from json config
        if (props.f_get_column_classes != null) {
            classes = props.f_get_column_classes(c);
        }
        // get column CSS style from json config
        if (props.f_get_column_style != null) {
            style = props.f_get_column_style(c);
        }

        // get column id and condiguration
        let id = props.get_column_id(c);
        let col_opt = cols_visibility_dict[id];

        // determine sort state, 0 = no sort, 1 = asc, 2 = desc
        let sort = col_opt?.sort;
        if (is_table_not_sorted == true && sort == null && props.default_sort != null && id == props.default_sort.column_id) {
            sort = props.default_sort.sort;
        } else if (col_opt?.sort) {
            sort = col_opt?.sort;
        } else {
            sort = 0;
        }
        return {
            id,
            visible: col_opt?.visible == null || col_opt?.visible == true, // defaults column to visible
            sort: sort,
            sortable: is_column_sortable(c),
            min_width: column_min_width(c),
            order: col_opt?.order || i,
            classes,
            style,
            data: c,
        };
    });

    // save column config to server
    await set_columns_visibility();
}

// reset all column widths to default
async function reset_column_size() {
    props.columns.forEach((c) => {
        let id = `${props.id}-${props.get_column_id(c)}`;
        columnWidthStore.remove(id); // remove saved width from local storage
    });
    await redraw_table_resizable();
}

// handle row number count per page
function change_per_page() {
    save_num_pages()
    redraw_select_pages();
    change_active_page(0);
}

// save rows count per page to local storage
const save_num_pages = function () {
    localStorage.setItem("ntopng.tables.rowPerPage", rowsPerPage.value);
}

// force pagination to redraw
const searchDelay = ref(0);
function redraw_select_pages() {
    searchDelay.value += 1;
}


// force table content to redraw
const table_content_id = ref(0);
function refresh_table_content() {
    table_content_id.value += 1;
}


// change pagination active page and update displayed rows
async function change_active_page(new_active_page) {
    if (new_active_page != null) {
        currentPage = new_active_page;
    }
    if (currentPage == null) {
        currentPage = 0;
    }

    // fetch new rows if paging is enabled
    if (props.paging == true || shouldForceRefresh) {
        await set_rows();
    } else {
        set_active_rows();
    }
    refresh_table_content();
}

// handle column sort
async function change_column_sort(col, col_index) {
    if (!col.sortable) {
        return;
    }

    // cycle states: no sort -> asc desc -> none
    col.sort = (col.sort + 1) % 3;

    // reset sort on all other columns
    processedColumns.value.filter((c, i) => i != col_index).forEach((c) => c.sort = 0);

    // no sort, stop
    if (col.sort == 0) { return; }

    if (props.paging) {
        await set_rows(); // server side sorting
    } else {
        set_active_rows(); // client side sorting
    }
    await set_columns_visibility();
}


// get sort function for available functions
function get_sort_function() {
    if (props.f_sort_rows != null) {
        return props.f_sort_rows;
    }

    // default sort strings
    return (col, r0, r1) => {
        let r0_col = props.print_html_row(col.data, r0);
        let r1_col = props.print_html_row(col.data, r1);
        if (col.sort == 1) {
            return r0_col.localeCompare(r1_col); // ascending
        }
        return r1_col.localeCompare(r0_col);     // descending
    };
}

let shouldForceRefresh = false;
let shouldDisableLoading = false;

/* ********************************************* */

/*  Refresh table contents
    - If disable_loading is true, no loading indicator will be shown
    - If disable_loading is true, current page will be maintained
*/

async function refresh_table(disable_loading) {
    /* NOTE: first refresh_table is called then set_rows */
    shouldForceRefresh = true;
    shouldDisableLoading = disable_loading || false;

    if (shouldDisableLoading) {
        /* In case of disabled loading, reload the same page */
        paginationRef.value.change_active_page();
    } else {
        /* Otherwise reload from page 1 */
        paginationRef.value.change_active_page(0, 0);
    }
    await nextTick();

    /* Reset the refresh/loading params */
    shouldForceRefresh = false;
    shouldDisableLoading = false;
}

/* ********************************************* */

let isFirstDataLoad = true;

// get and update rows data
async function set_rows() {
    // show loading spinner
    isLoading.value = true && !shouldDisableLoading;

    // get rows from backend
    let res = await props.get_rows(
        currentPage,                // current page
        rowsPerPage.value,          // rows per page
        processedColumns.value,     // columns definition
        searchString.value,         // search term
        isFirstDataLoad             // first load
    );

    // update query info if available
    query_info.value = null;
    if (res.query_info != null) {
        query_info.value = res.query_info;
    }

    isFirstDataLoad = false;

    // If we're not using server-side paging, we need to filter the rows client-side
    if (props.paging !== true && searchString.value.trim() !== '') {
        res.rows = filterRows(res.rows, searchString.value);
    }

    // update total rows count
    totalRowCount.value = res.rows.length;
    if (props.paging == true) {
        totalRowCount.value = res.total_rows; // use number of rows provided by server
    }

    // store fetched rows and update displayed rows 
    allRows = res.rows;
    set_active_rows();
    isLoading.value = false;

    // wait for dom to update and emit event
    await nextTick();
    emit('rows_loaded', res);
}

// New function to filter rows based on search string
function filterRows(rows, searchTerm) {
    if (!searchTerm || searchTerm.trim() === '') {
        return rows;
    }
    
    searchTerm = searchTerm.toLowerCase();
    
    return rows.filter(row => {
        // Check each visible column for the search term
        return processedColumns.value.some(col => {
            if (!col.visible) return false;
            
            let cellContent = '';
            
            // Get cell content based on how it's rendered
            if (props.print_html_row && props.print_html_row(col.data, row, true) != null) {
                // For HTML content, get the rendered text and strip HTML tags
                const htmlContent = props.print_html_row(col.data, row);
                cellContent = htmlContent ? stripHtmlTags(htmlContent).toLowerCase() : '';
            } else if (props.print_vue_node_row && props.print_vue_node_row(col.data, row, vue_obj, true) != null) {
                // For Vue nodes, we might need to extract text differently
                // This is a simplification and might need adjustment based on your Vue node structure
                const vueContent = props.print_vue_node_row(col.data, row, vue_obj);
                cellContent = typeof vueContent === 'string' ? vueContent.toLowerCase() : '';
            } else {
                // Fallback: try to access the raw value from the row using column data
                const rawValue = row[col.data];
                cellContent = rawValue ? String(rawValue).toLowerCase() : '';
            }
            
            return cellContent.includes(searchTerm);
        });
    });
}

function stripHtmlTags(html) {
    if (!html) return '';
    return html.replace(/<\/?[^>]+(>|$)/g, " ").replace(/\s+/g, " ").trim();
}

// determine if column is sortable
function is_column_sortable(col) {
    if (props.f_is_column_sortable != null) {
        return props.f_is_column_sortable(col); // use custom function to sort
    }
    return true;
}

// determine column minimum width
function column_min_width(col) {
    if (props.f_column_min_width != null) {
        return props.f_column_min_width(col); // use custom function for min width
    }
    return true;
}

// set displayed columns for current page
function set_active_rows() {
    let start_row_index = 0;

    // start index for client side pagination
    if (props.paging == false) {
        start_row_index = currentPage * rowsPerPage.value;
    }

    // sort rows client side if enabled
    if (props.paging == false) {
        let f_sort = get_sort_function();
        let col_to_sort = get_column_to_sort();

        // sort rows if enabled

        if (col_to_sort) {
            allRows = allRows.sort((r0, r1) => {
                return f_sort(col_to_sort, r0, r1);
            });
        }
    }

    // update displayed rows for current page
    displayedRows.value = allRows.slice(start_row_index, start_row_index + rowsPerPage.value);
}

// get columns with active sort
function get_column_to_sort() {
    let col_to_sort = processedColumns.value.find((c) => c.sort != 0);
    return col_to_sort;
}

// add timeout to search to prevent request flooding
let map_search_change_timeout;
async function on_change_map_search() {
    let timeout = 300; // Reduced timeout for better responsiveness

    // clear existing timeouts
    if (map_search_change_timeout != null) {
        clearTimeout(map_search_change_timeout);
    }

    map_search_change_timeout = setTimeout(async () => {
        if (props.paging) {
            // For server-side pagination, reset to first page when searching
            currentPage = 0;
            paginationRef.value.change_active_page(0, 0);
        }
        
        await set_rows(); // get filtered rows
        
        // Update pagination after search
        if (!props.paging) {
            redraw_select_pages();
        }
        
        map_search_change_timeout = null;
    }, timeout);
}

// set search value
function search_value(value) {
    searchString.value = value; /* Add the new value */
    on_change_map_search(); // trigger search
}

// copy executed SQL query to clipboard
function copy_query_into_clipboard($event) {
    NtopUtils.copyToClipboard(query_info.value.query, sqlButtonRef.value);
}

// get current column definition
function get_columns_defs() {
    return processedColumns.value;
}

// get total number of rows
function get_rows_num() {
    return totalRowCount.value;
}

// expose methods for parent components
defineExpose({ load_table, refresh_table, get_columns_defs, get_rows_num, search_value });

</script>

<style scoped>
.sticky {
    position: sticky;
    left: 0;
    background-color: white;
}

.wrap-column {
    text-overflow: ellipsis;
    white-space: nowrap;
    overflow: hidden;
    width: 100%;
}

.pointer {
    cursor: pointer;
}

.unset {
    cursor: unset;
}

.link-button {
    color: var(--bs-dropdown-link-color);
    cursor: pointer;
}

.link-disabled {
    pointer-events: none;
    color: #ccc;
}

td {
    height: 2.5rem;
}

.margin-sm {
    margin-bottom: -0.25rem;
    margin-top: -0.25rem;
}
</style>

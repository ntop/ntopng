<!-- (C) 2026 - ntop.org -->
<template>
    <div class="row">
        <!-- Exporter sites table -->
        <div class="col-6">
            <TableWithConfig ref="exporter_sites_list" :table_id="table_id" :csrf="csrf" :showLoading="true"
                @custom_event="on_table_custom_event" :f_map_columns="map_table_def_columns"
                :get_extra_params_obj="get_extra_params_obj" :f_sort_rows="columns_sorting">
                <!-- Custom button slot for adding new sites -->
                <template v-slot:custom_buttons>
                    <button class="btn btn-link" type="button" @click="addExporterSite">
                        <i class="fas fa-plus" data-bs-toggle="tooltip" data-bs-placement="top"
                            :title="_i18n('exporter_sites_page.add_exporter_site')"></i>
                    </button>
                </template>
            </TableWithConfig>
        </div>
        <!-- Geographic map visualization of sites -->
        <div class="col-6">
            <Geomap :geomapDataArray="geomapDataArray" :tooltipFormatter="formatTooltipData" :glowDots="true"
                :style="['height: 50vh']" />
        </div>
    </div>

    <!-- Modal components for site management -->
    <ModalEditExporterSite ref="exporterSiteModal" :errorMessage="modalErrorMessage" @edit="handleEditExporterSite"
        @add="handleAddExporterSite">
    </ModalEditExporterSite>
    <ModalDeleteExporterSite ref="exporterSiteModalDelete" @delete="handleDeleteExporterSite">
    </ModalDeleteExporterSite>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as ModalEditExporterSite } from "./modal-edit-exporter-site.vue";
import { default as ModalDeleteExporterSite } from "./modal-delete-exporter-site.vue";
import { default as Geomap } from "./geomap.vue";

/* ************************************** */
// Internationalization helper function
const _i18n = (t) => i18n(t);

// Component props - receives context data from parent
const props = defineProps({ context: Object });

/* ************************************** */
// Reactive state variables
const table_id = ref("exporter_sites_list");         // Table identifier
const exporter_sites_list = ref(null);               // Reference to table component
const editingExporterSiteId = ref(null);             // ID of site currently being edited
const modalErrorMessage = ref("");                    // Error message for modals
const csrf = props.context.csrf;                      // CSRF token for API requests
const exporterSiteModal = ref(null);                  // Reference to edit/add modal
const exporterSiteModalDelete = ref(null);            // Reference to delete modal

// API endpoint URLs for exporter site management
const API = {
    edit: `${http_prefix}/lua/pro/rest/v2/edit/exporter_site/exporter_site.lua`,
    add: `${http_prefix}/lua/pro/rest/v2/add/exporter_site/exporter_site.lua`,
    delete: `${http_prefix}/lua/pro/rest/v2/delete/exporter_site/exporter_site.lua`,
    get: `${http_prefix}/lua/pro/rest/v2/get/exporter_site/exporter_sites_list.lua`
};


// Geographic data for map visualization
const geomapDataArray = ref([]);

/* ************************************** */
// Maps table column definitions to rendering functions
// This function customizes how each column displays its data
const map_table_def_columns = (columns) => {
    // Define rendering functions for each column type
    let map_columns = {
        // Site name column - displays the name directly
        "name": (value, row) => {
            return value
        },
        // Description column - displays description directly
        "description": (value, row) => {
            return value
        },
        // Location column - formats coordinates as human-readable string
        // Only displays if coordinates are not zero/empty
        "location": (value, row) => {
            let location = ''
            if (!dataUtils.isZeroOrEmptyString(row.latitude) && !dataUtils.isZeroOrEmptyString(row.longitude)) {
                location = `${row.latitude}° ${_i18n('exporter_sites_page.exporter_site_latitude')}, ${row.longitude}° ${_i18n('exporter_sites_page.exporter_site_longitude')}`
            }
            return location
        },
    };

    // Apply rendering functions to columns and configure action buttons
    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];

        // Special handling for actions column (edit/delete buttons)
        if (c.id === "actions") {
            c.button_def_array.forEach((b) => {
                // Disable buttons for default site (id=0) as it cannot be modified
                b.f_map_class = (current_class, row) => {
                    if (row.id == 0) {
                        current_class.push("disabled");
                    }
                    return current_class;
                };
            });
        }
    });

    return columns;
};

/* ************************************** */
// Sorting function for table columns
// Currently only supports sorting by name
function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "name") {
            return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
        }
    }
    // Fallback safe
    return 0;
}

/* ************************************** */
// Retrieves additional parameters from URL for API requests
const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */
// Handles custom events from table buttons (edit, delete)
function on_table_custom_event(event) {
    // Map event IDs to handler functions
    let events_managed = {
        "click_button_edit_exporter_site": click_button_edit_exporter_site,
        "click_button_delete_exporter_site": click_button_delete_exporter_site
    };

    if (events_managed[event.event_id] == null) {
        return;  // Unknown event - ignore
    }
    events_managed[event.event_id](event);
}

// Handler for edit button click
const click_button_edit_exporter_site = (event) => {
    const row = event.row
    if (!row) return;
    if (row.id == 0) return;  // Default site cannot be edited

    editingExporterSiteId.value = row.id;

    // Prepare site data for the edit modal
    const exporter_site_data = {
        exporter_site_name: row.name,
        exporter_site_description: row.description,
        exporter_site_lat: row.latitude,
        exporter_site_lng: row.longitude,
        exporter_site_reserved: row.reserved,
    };

    // Open the Edit modal with pre-filled data
    exporterSiteModal.value.open(exporter_site_data);
};

// Handler for delete button click
async function click_button_delete_exporter_site(event) {
    const row = event.row
    if (!row) return;
    if (row.id == 0) return;  // Default site cannot be deleted

    // Prepare site data for delete confirmation
    const exporter_site_data = {
        exporter_site_name: row.name,
        exporter_site_description: row.description,
        exporter_site_lat: row.latitude,
        exporter_site_lng: row.longitude,
        exporter_site_id: row.id,
    };

    showDeleteModal(exporter_site_data);
}

/* ************************************** */
// Opens the add site modal with empty form
function addExporterSite() {
    exporterSiteModal.value.open();
}

/* ************************************** */
// Shows the delete confirmation modal
const showDeleteModal = (item) => {
    exporterSiteModalDelete.value.showDelete(item);
};

/* ************************************** */
// Handles the edit form submission
// Sends updated site data to the server
const handleEditExporterSite = (data) => {
    modalErrorMessage.value = "";  // Clear any previous error

    const {
        exporter_site_name,
        exporter_site_description,
        exporter_site_lat,
        exporter_site_lng
    } = data

    const headers = {
        'Content-Type': 'application/json'
    };

    // Prepare request payload
    const addParams = {
        csrf: props.context.csrf,
        exporter_sites: {
            exporter_site_id: editingExporterSiteId.value,
            exporter_site_name,
            exporter_site_description,
            latitude: exporter_site_lat,
            longitude: exporter_site_lng
        }
    };

    // Send edit request to server
    ntopng_utility.http_request(API.edit, {
        method: 'POST',
        headers,
        body: JSON.stringify(addParams)
    },false, true, true)
        .then(data => {
            // Handle server-side validation errors
            if (!data || data.rc<0) {
                modalErrorMessage.value = data.rsp || _i18n("error");
                return;
            }
            // Success - refresh data and close modal
            refresh_sites();
            exporterSiteModal.value.close();
        })
        .catch(err => console.error('Error during exporter site edit:', err))
};

/* ************************************** */
// Handles the add site form submission
// Sends new site data to the server
const handleAddExporterSite = async (data) => {
    modalErrorMessage.value = "";  // Clear any previous error

    const headers = { 'Content-Type': 'application/json' };

    // Prepare request payload for new site
    const addParams = {
        csrf: props.context.csrf,
        exporter_sites: {
            exporter_site_name: data.exporter_site_name,
            exporter_site_description: data.exporter_site_description,
            latitude: data.exporter_site_lat,
            longitude: data.exporter_site_lng
        }
    };

    // Send add request to server
    ntopng_utility.http_request(API.add, {
        method: 'POST',
        headers,
        body: JSON.stringify(addParams)
    },false, true, true)
        .then(data => {
            // Handle server-side validation errors
            if (!data || data.rc<0) {
                modalErrorMessage.value = data.rsp || _i18n("error");
                return;
            }
            // Success - refresh data and close modal
            refresh_sites();
            exporterSiteModal.value.close();
        })
        .catch(err => console.error('Error during exporter site edit:', err))
};

/* ************************************** */
// Handles site deletion confirmation
// Sends delete request to server
const handleDeleteExporterSite = async (item) => {
    if (item) {
        const exporter_site = item.exporter_site_id;

        // Prepare delete request payload
        const requestParams = {
            csrf: props.context.csrf,
            exporter_site: exporter_site
        };

        const headers = { 'Content-Type': 'application/json' };

        // Send edit request to server
        ntopng_utility.http_request(API.delete, {
            method: 'POST',
            headers,
            body: JSON.stringify(requestParams)
        },false, true, true)
            .then(data => {
                // Refresh table after successful delete
                refresh_sites();
            })
            .catch(err => console.error('Error deleting exporter site:', err))
    }
    exporterSiteModalDelete.value.close();
};

/* ************************************** */
// Loads site data for the geographic map
// Fetches all sites and filters out the default site (id=0)
async function loadSitesMap() {
    const requestParams = {
        csrf: props.context.csrf
    };

    const headers = { 'Content-Type': 'application/json' };


    // Send add request to server
    ntopng_utility.http_request(API.get, {
        method: 'POST',
        headers,
        body: JSON.stringify(requestParams)
    }).then(data => {
        if (!Array.isArray(data)) {
            geomapDataArray.value = [];
            return;
        }

        // Transform server response into map-compatible format
        // Exclude default site (id=0) from map display
        geomapDataArray.value = data.filter(site => {
            return (site.id != 0);
        }).map(site => ({
            id: site.id,
            name: site.name,
            description: site.description,
            lat: Number(site.latitude),   // Convert to number for map library
            lng: Number(site.longitude)    // Convert to number for map library
        }));
    }).catch(err => {
        console.error('Error during exporter site edit:', err);
        geomapDataArray.value = [];
    })
}

/* ************************************** */
// Formats tooltip content for map markers
// Creates HTML structure with site information
function formatTooltipData(site) {
    return `
        <div class="custom-tooltip-content">
            <h6>${site.name}</h6>
            <hr/>
            <div>${site.description ?? ''}</div>
            <small>${site.lat}, ${site.lng}</small>
        </div>
    `;
}

/* ************************************** */
// Refreshes both table and map data
// Called after any CRUD operation to keep UI synchronized
const refresh_sites = async (item) => {
    exporter_sites_list.value?.refresh_table(true);  // Force table refresh
    loadSitesMap();  // Reload map data
};

/* ************************************** */
// Lifecycle hook: Load map data when component is mounted
onMounted(async () => {
    loadSitesMap();
});

</script>
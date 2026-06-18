<!-- (C) 2026 - ntop.org -->
<template>
    <div v-show="activePage === 'networks'" class="m-2 mb-3">
        <TableWithConfig ref="table_networks_stats" :table_id="networks_table" :csrf="csrf" showLoading="true"
            :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event">

            <!-- Table Selector: Networks or Sites -->
            <template v-slot:custom_header>
                <NavbarTabs :tabs="tabs" :active_tab_id="activePage" @on_click="switchActivePage" />
            </template>

            <!-- add Networks 
            <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" @click="openAddNetworksModal">
                    <i class="fas fa-plus"></i>
                </button>
            </template>
            -->
        </TableWithConfig>
    </div>
    <div v-show="activePage !== 'networks'" class="m-2 mb-3">
        <!-- Import feedback banners -->
        <div v-if="importWithSuccess" class="alert alert-success alert-dismissable">
            <span>{{ importOkText }}</span>
        </div>
        <div v-if="importWithError" class="alert alert-danger alert-dismissable">
            <span>{{ importErrorText }}</span>
        </div>

        <TableWithConfig ref="table_sites_stats" :table_id="site_table" :csrf="csrf" :showLoading="true"
            @custom_event="on_table_custom_event" :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting">

            <!-- Table Selector: Networks or Sites -->
            <template v-slot:custom_header>
                <NavbarTabs :tabs="tabs" :active_tab_id="activePage" @on_click="switchActivePage" />
            </template>

            <!-- Custom button slot for adding/importing/exporting sites -->
            <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" @click="openAddSiteModal">
                    <i class="fas fa-plus" data-bs-toggle="tooltip" data-bs-placement="top"
                        :title="_i18n('sites_page.add_site')"></i>
                </button>
                <button class="btn btn-link" type="button" @click="importSites">
                    <i class="fa-solid fa-file-arrow-down" data-bs-toggle="tooltip" data-bs-placement="top"
                        :title="_i18n('sites_page.import_sites')"></i>
                </button>
                <a class="btn btn-link" download="sites.csv" :href="sites_export_url">
                    <i class="fa-solid fa-file-arrow-up" data-bs-toggle="tooltip" data-bs-placement="top"
                        :title="_i18n('sites_page.export_sites')"></i>
                </a>
                <!-- Hidden file input used by the Import button -->
                <input ref="importFileInput" type="file" accept=".csv,text/csv" class="d-none"
                    @change="onImportFileSelected" />
            </template>
        </TableWithConfig>
    </div>

    <!-- Modal components for site management -->
    <ModalEditNetwork ref="networkModal" :errorMessage="modalNetworkErrorMessage" :sitesList="sitesList"
        @edit="handleEditNetwork">
    </ModalEditNetwork>
    <ModalEditSite ref="siteModal" :errorMessage="modalErrorMessage" @edit="handleEditSite" @add="handleAddSite">
    </ModalEditSite>
    <ModalDeleteSite ref="siteModalDelete" @delete="handleDeleteSite">
    </ModalDeleteSite>

    <NoteList v-if="activePage === 'networks'" :note_list="note_list"></NoteList>
</template>


<script setup>
import { ref, onBeforeMount, watch } from "vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as ModalEditSite } from "./modal-edit-site.vue";
import { default as ModalEditNetwork } from "./modal-edit-network.vue";
import { default as ModalDeleteSite } from "./modal-delete-site.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as NoteList } from "./note-list.vue";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";

/* ************************************** */
// Internationalization helper function
const _i18n = (t) => i18n(t);

// Component props - receives context data from parent
const props = defineProps({
    context: Object,
});

const tabs = [
    { id: "networks", label_i18n: "networks" },
    { id: "sites", label_i18n: "sites_page.sites" },
];

const note_list = [
    _i18n("network_stats.note_overlapping_networks"),
    _i18n("network_stats.note_see_both_network_entries"),
    _i18n("network_stats.note_broader_network")
];

// API endpoint URLs for site management
const API = {
    edit: `${http_prefix}/lua/pro/rest/v2/edit/sites/edit.lua`,
    add: `${http_prefix}/lua/pro/rest/v2/add/sites/add.lua`,
    delete: `${http_prefix}/lua/pro/rest/v2/delete/sites/delete.lua`,
    get: `${http_prefix}/lua/pro/rest/v2/get/sites/list.lua`,
    import: `${http_prefix}/lua/pro/rest/v2/import/sites/sites.lua`,
    net_edit: `${http_prefix}/lua/rest/v2/edit/network/edit.lua`
};

// Export endpoint used directly by the download anchor (CSV attachment)
const sites_export_url = `${http_prefix}/lua/pro/rest/v2/export/sites/sites.lua?download=1`;

const areNetworksTsEnabled = props.context.areNetworksTsEnabled;
const csrf = props.context.csrf;

/* ************************************** */
// Reactive state variables
const activePage = ref("networks");
// Networks
const networks_table = ref('networks_list');
const table_networks_stats = ref(null);

// Sites
const sitesList = ref([]);
const site_table = ref("sites_list");         // Table identifier
const table_sites_stats = ref(null);               // Reference to table component
const editingSiteId = ref(null);             // ID of site currently being edited
const modalErrorMessage = ref("");                    // Error message for modals
const modalNetworkErrorMessage = ref("");     // Error message for modals
const siteModal = ref(null);                  // Reference to edit/add modal
const networkModal = ref(null);                  // Reference to edit/add modal
const siteModalDelete = ref(null);            // Reference to delete modal

// Import (CSV) state
const importFileInput = ref(null);
const importWithSuccess = ref(false);
const importWithError = ref(false);
const importOkText = ref("");
const importErrorText = ref("");

/* ************************************** */

onBeforeMount(() => {
    retrieveSitesList()
    const activePageURL = ntopng_url_manager.get_url_entry("page")
    activePage.value = activePageURL ? activePageURL : "networks";
})

/* ************************************** */

watch(activePage, (newVal) => {
    // This is mandatory because when switching between tables, being just "hidden" the tables
    // to have a fast load, the jquery resize properties are not correctly loaded (size at 0)
    if (newVal === 'networks') {
        table_networks_stats?.value?.redrawTable()
    } else {
        table_sites_stats?.value?.redrawTable()
    }
}, { flush: 'post' })

/* ************************************** */

const switchActivePage = function (tab) {
    activePage.value = tab.id
    ntopng_url_manager.set_key_to_url("page", tab.id)
}

/* ************************************** */

const retrieveSitesList = function () {
    sitesList.value = [];
    // Send edit request to server
    ntopng_utility.http_request(API.get)
        .then(data => {
            sitesList.value = data;
        })
        .catch(err => console.error('Error retrieving Sites'))
}

/* ************************************** */

const refreshActiveTable = () => {
    table_sites_stats.value?.refresh_table(true);
    table_networks_stats.value?.refresh_table(true);
    retrieveSitesList()
}

const map_table_def_columns = (columns) => {
    let map_columns = {
        /* Networks */
        "networkName": (value, row) => {
            const network_url = `${http_prefix}/lua/hosts_stats.lua?network=${row.networkId}`;
            const network_ts_url = `${http_prefix}/lua/network_details.lua?network=${row.networkId}&page=historical`;

            // Create href with network name and icons
            let href = `<a href="${network_url}">${value}</a>`;
            const ts_icon_href = `&nbsp;<a href="${network_ts_url}"><i class="fas fa-chart-area"></i></a>`;

            if (areNetworksTsEnabled) {
                href += ts_icon_href;
            }
            return href
        },
        // Site name column - displays the name directly
        "site": (value, row) => {
            const netSite = sitesList.value.find((el) => el.id === value.id)
            if (!netSite)
                return ''
            return netSite.name
        },
        "hosts": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "score": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "hostsScoreRatio": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "alertedFlows": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "breakdown": (value, row) => {
            return NtopUtils.createBreakdown(row.breakdown.percentage_bytes_sent, row.breakdown.percentage_bytes_rcvd, "Sent", "Rcvd")
        },
        "throughput": (value, row) => {
            return formatterUtils.getFormatter("bps")(value);
        },
        "traffic": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value);
        },
        /* Sites */
        // Site name column - displays the name directly
        "name": (value, row) => {
            return value
        },
        // Description column - displays description directly
        "description": (value, row) => {
            return value
        },
        // Networks column - displays the list of networks associated with the Site
        "networks": (value, row) => {
            let networksList = ""

            value?.forEach((el) => {
                networksList = `${networksList}${el.network_name}, `
            })

            if (!dataUtils.isEmptyString(networksList)) {
                networksList = networksList.slice(0, -2)
            }
            return networksList
        },
        // Location column - formats coordinates as human-readable string
        // Only displays if coordinates are not zero/empty
        "location": (value, row) => {
            let location = ''
            if (!dataUtils.isZeroOrEmptyString(row.latitude) && !dataUtils.isZeroOrEmptyString(row.longitude)) {
                location = `${row.latitude}° ${_i18n('sites_page.site_latitude')}, ${row.longitude}° ${_i18n('sites_page.site_longitude')}`
            }
            return location
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id === "charts_enabled") {
            const visible_dict = {
                historical_data: props.context.show_historical,
            };

            c.button_def_array.forEach((b) => {

                if (!visible_dict[b.id]) {
                    b.class.push("disabled");
                }
            });
        }
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


function columns_sorting(col, r0, r1) {
    if (col != null) {
        /* Networks */
        if (col.id == "network_name") {
            return sortingFunctions.sortByName(r0.networkName, r1.networkName, col.sort);
        } else if (col.id == "site") {
            return sortingFunctions.sortByName(r0.site.name, r1.site.name, col.sort);
        } else if (col.id == "hosts") {
            return sortingFunctions.sortByNumber(r0.hosts, r1.hosts, col.sort);
        } else if (col.id == "score") {
            return sortingFunctions.sortByNumber(r0.score, r1.score, col.sort);
        } else if (col.id == "hosts_score_ratio") {
            return sortingFunctions.sortByNumber(r0.hostsScoreRatio, r1.hostsScoreRatio, col.sort);
        } else if (col.id == "alerted_flows") {
            return sortingFunctions.sortByNumber(r0.alertedFlows, r1.alertedFlows, col.sort);
        } else if (col.id == "throughput") {
            return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
        } else if (col.id == "traffic") {
            return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
        }
        /* Sites */
        else if (col.id == "name") {
            return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
        }
    }

}

/* ************************************** */
//                  SITES                 //
/* ************************************** */


/* ************************************** */
// Handles custom events from table buttons (edit, delete)
function on_table_custom_event(event) {
    // Map event IDs to handler functions
    let events_managed = {
        "click_button_edit_site": click_button_edit_site,
        "click_button_delete_site": click_button_delete_site,
        "click_button_edit_network": click_button_edit_network
    };

    if (events_managed[event.event_id] == null) {
        return;  // Unknown event - ignore
    }
    events_managed[event.event_id](event);
}

// Handler for edit button click
const click_button_edit_network = (event) => {
    const row = event.row
    if (!row) return;
    if (row.id == 0) return;  // Default site cannot be edited

    // Open the Edit modal with pre-filled data
    networkModal.value.open({
        network_id: row.networkId,
        network_alias: row.networkNameOnly,
        site_id: row.site.id
    });
};

// Handler for edit button click
const click_button_edit_site = (event) => {
    const row = event.row
    if (!row) return;
    if (row.id == 0) return;  // Default site cannot be edited

    editingSiteId.value = row.id;

    // Prepare site data for the edit modal
    const site_data = {
        site_name: row.name,
        site_description: row.description,
        site_networks: row.networks,
        site_lat: row.latitude,
        site_lng: row.longitude,
        site_reserved: row.reserved,
    };

    // Open the Edit modal with pre-filled data
    siteModal.value.open(site_data);
};

// Handler for delete button click
async function click_button_delete_site(event) {
    const row = event.row
    if (!row) return;
    if (row.id == 0) return;  // Default site cannot be deleted

    // Prepare site data for delete confirmation
    const site_data = {
        site_name: row.name,
        site_description: row.description,
        site_networks: row.networks,
        site_lat: row.latitude,
        site_lng: row.longitude,
        site_id: row.id,
    };

    showDeleteModal(site_data);
}

/* ************************************** */
// Opens the add site modal with empty form
function openAddSiteModal() {
    siteModal.value.open();
}

/* ************************************** */

// Resets the import feedback banners
function refreshImportFeedback() {
    importWithSuccess.value = false;
    importWithError.value = false;
    importOkText.value = "";
    importErrorText.value = "";
}

// Triggers the hidden file input (opens the OS file picker)
function importSites() {
    refreshImportFeedback();
    importFileInput.value.click();
}

// Reads the selected CSV file and uploads it to the import endpoint.
const onImportFileSelected = (event) => {
    const file = event.target.files && event.target.files[0];
    // Reset the input so selecting the same file again still fires @change
    event.target.value = "";
    if (!file) return;

    refreshImportFeedback();

    const reader = new FileReader();

    reader.onload = () => {
        const requestParams = {
            csrf: props.context.csrf,
            sites_csv: reader.result,
        };

        const headers = { 'Content-Type': 'application/json' };

        ntopng_utility.http_request(API.import, {
            method: 'POST',
            headers,
            body: JSON.stringify(requestParams)
        }, false, true, true)
            .then(data => {
                if (!data || data.rc < 0) {
                    importErrorText.value = (data && data.rsp && data.rsp.feedback)
                        ? data.rsp.feedback
                        : _i18n("sites_page.import_sites_error");
                    importWithError.value = true;
                } else {
                    importOkText.value = (data.rsp && data.rsp.feedback)
                        ? data.rsp.feedback
                        : _i18n("sites_page.import_sites_ok");
                    importWithSuccess.value = true;
                }
            })
            .catch(err => {
                console.error("Error during Sites CSV import:", err);
                importErrorText.value = _i18n("sites_page.import_sites_error");
                importWithError.value = true;
            })
            .finally(() => {
                setTimeout(refreshImportFeedback, 10000);
                // A failed import may still have added some rows: refresh anyway
                refreshActiveTable();
            });
    };

    reader.onerror = () => {
        importErrorText.value = _i18n("sites_page.import_sites_error");
        importWithError.value = true;
    };

    reader.readAsText(file);
};

/* ************************************** */
// Shows the delete confirmation modal
const showDeleteModal = (item) => {
    siteModalDelete.value.showDelete(item);
};

/* ************************************** */
// Handles the edit form submission
// Sends updated site data to the server
const handleEditSite = (data) => {
    modalErrorMessage.value = "";  // Clear any previous error

    const {
        site_name,
        site_description,
        site_networks,
        site_lat,
        site_lng
    } = data

    const headers = {
        'Content-Type': 'application/json'
    };

    // Prepare request payload
    const addParams = {
        csrf: props.context.csrf,
        sites: {
            site_id: editingSiteId.value,
            site_name,
            site_description,
            site_networks,
            latitude: site_lat,
            longitude: site_lng
        }
    };

    // Send edit request to server
    ntopng_utility.http_request(API.edit, {
        method: 'POST',
        headers,
        body: JSON.stringify(addParams)
    }, false, true, true)
        .then(data => {
            // Handle server-side validation errors
            if (!data || data.rc < 0) {
                modalErrorMessage.value = data.rsp || _i18n("error");
                return;
            }
            // Success - refresh data and close modal
            refreshActiveTable();
            siteModal.value.close();
        })
        .catch(err => console.error('Error during Site editing:', err))
};

/* ************************************** */
// Handles the add site form submission
// Sends new site data to the server
const handleAddSite = async (data) => {
    modalErrorMessage.value = "";  // Clear any previous error

    const headers = { 'Content-Type': 'application/json' };

    // Prepare request payload for new site
    const addParams = {
        csrf: props.context.csrf,
        sites: {
            site_name: data.site_name,
            site_description: data.site_description,
            site_networks: data.site_networks,
            latitude: data.site_lat,
            longitude: data.site_lng
        }
    };

    // Send add request to server
    ntopng_utility.http_request(API.add, {
        method: 'POST',
        headers,
        body: JSON.stringify(addParams)
    }, false, true, true)
        .then(data => {
            // Handle server-side validation errors
            if (!data || data.rc < 0) {
                modalErrorMessage.value = data.rsp || _i18n("error");
                return;
            }
            // Success - refresh data and close modal
            refreshActiveTable();
            siteModal.value.close();
        })
        .catch(err => console.error('Error during Site editing:', err))
};

/* ************************************** */
// Handles site deletion confirmation
// Sends delete request to server
const handleDeleteSite = async (item) => {
    if (item) {
        const site_id = item.site_id;

        // Prepare delete request payload
        const requestParams = {
            csrf: props.context.csrf,
            site_id: site_id
        };

        const headers = { 'Content-Type': 'application/json' };

        // Send edit request to server
        ntopng_utility.http_request(API.delete, {
            method: 'POST',
            headers,
            body: JSON.stringify(requestParams)
        }, false, true, true)
            .then(data => {
                // Refresh table after successful delete
                refreshActiveTable();
            })
            .catch(err => console.error('Error deleting Site:', err))
    }
    siteModalDelete.value.close();
};

/* ************************************** */
// Handles the edit network form submission
const handleEditNetwork = async (data) => {
    modalErrorMessage.value = "";  // Clear any previous error

    const headers = { 'Content-Type': 'application/json' };

    // Prepare request payload for new site
    const editParams = {
        csrf: props.context.csrf,
        network: data.network_id,
        custom_name: data.network_alias,
        site_id: data.site_id,
    };

    // Send add request to server
    ntopng_utility.http_request(API.net_edit, {
        method: 'POST',
        headers,
        body: JSON.stringify(editParams)
    }, false, true, true)
        .then(data => {
            // Handle server-side validation errors
            if (!data || data.rc < 0) {
                modalErrorMessage.value = data.rsp || _i18n("error");
                return;
            }
            // Success - refresh data and close modal
            refreshActiveTable();
            networkModal.value.close();
        })
        .catch(err => console.error('Error during Site editing:', err))
}
</script>

<!-- (C) 2026 - ntop.org -->
<template>
    <div class="m-2 mb-3">
        <Transition v-if="activeTab === 'stats'" name="add-effect" mode="out-in">
            <div class="position-relative">
                <div class="mb-4 d-flex flex-column" style="height: 30vh;">
                    <Loading :isLoading="loading"></Loading>
                    <Sankey ref="sankey_chart" :no_data_message="no_data_message" :sankey_data="sankey_data">
                    </Sankey>
                </div>
            </div>
        </Transition>
        <TableWithConfig v-if="activeTab === 'stats'" ref="tableSitesStats" :table_id="'sites_stats'" :csrf="csrf"
            :showLoading="true" @custom_event="on_table_custom_event" :f_map_columns="map_table_def_columns"
            :f_sort_rows="columns_sorting">

            <!-- Table Selector: Stats or Config -->
            <template v-slot:custom_header>
                <NavbarTabs :tabs="tabs" :active_tab_id="activeTab" @on_click="switchActiveTab" />
            </template>

            <!-- Custom button slot for adding new sites -->
            <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" @click="openAddSiteModal">
                    <i class="fas fa-plus" data-bs-toggle="tooltip" data-bs-placement="top"
                        :title="_i18n('sites_page.add_site')"></i>
                </button>
            </template>
        </TableWithConfig>
        <template v-else>
            <!-- Import feedback banners -->
            <div v-if="importWithSuccess" class="alert alert-success alert-dismissable">
                <span>{{ importOkText }}</span>
            </div>
            <div v-if="importWithError" class="alert alert-danger alert-dismissable">
                <span>{{ importErrorText }}</span>
            </div>

            <TableWithConfig ref="tableSitesConfig" :table_id="'sites_config'" :csrf="csrf" :showLoading="true"
                @custom_event="on_table_custom_event" :f_map_columns="map_table_def_columns"
                :f_sort_rows="columns_sorting" @rows_loaded="updateSitesList">

                <!-- Table Selector: Stats or Config -->
                <template v-slot:custom_header>
                    <NavbarTabs :tabs="tabs" :active_tab_id="activeTab" @on_click="switchActiveTab" />
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
        </template>
    </div>

    <!-- Modal components for site management -->
    <ModalEditSite ref="siteModal" :errorMessage="modalErrorMessage" :sitesList="sitesList" @edit="handleEditSite"
        @add="handleAddSite">
    </ModalEditSite>
    <ModalDeleteSite ref="siteModalDelete" @delete="handleDeleteSite">
    </ModalDeleteSite>
</template>


<script setup>
import { ref, onBeforeMount, onMounted, watch } from "vue";
import { default as Loading } from "./loading.vue"
import { default as Sankey } from "./sankey.vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as ModalEditSite } from "./modal-edit-site.vue";
import { default as ModalDeleteSite } from "./modal-delete-site.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as NoteList } from "./note-list.vue";
import FormatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";

/* ************************************** */
// Internationalization helper function
const _i18n = (t) => i18n(t);

// Component props - receives context data from parent
const props = defineProps({
    context: Object,
});

const tabs = [
    { id: "stats", label_i18n: "statistics" },
    { id: "config", label_i18n: "configuration" },
];
const sankey_url = `${http_prefix}/lua/pro/rest/v2/get/sites/sankey.lua`;

// API endpoint URLs for site management
const API = {
    edit: `${http_prefix}/lua/pro/rest/v2/edit/sites/edit.lua`,
    add: `${http_prefix}/lua/pro/rest/v2/add/sites/add.lua`,
    delete: `${http_prefix}/lua/pro/rest/v2/delete/sites/delete.lua`,
    import: `${http_prefix}/lua/pro/rest/v2/import/sites/sites.lua`,
    get: `${http_prefix}/lua/pro/rest/v2/get/sites/list.lua`,
};

// Export endpoint used directly by the download anchor (CSV attachment)
const sites_export_url = `${http_prefix}/lua/pro/rest/v2/export/sites/sites.lua?download=1`;
const areNetworksTsEnabled = props.context.areNetworksTsEnabled;
const csrf = props.context.csrf;
const loading = ref(true);
const sankey_chart = ref(null);
const sankey_data = ref({});
const no_data_message = _i18n("as_overview.no_data")

/* ************************************** */
// Reactive state variables
const activeTab = ref("stats");

const tableSitesStats = ref(null);
const tableSitesConfig = ref(null);
const editingSiteId = ref(null);             // ID of site currently being edited
const modalErrorMessage = ref("");                    // Error message for modals
const siteModal = ref(null);                  // Reference to edit/add modal
const siteModalDelete = ref(null);            // Reference to delete modal
const sitesList = ref([]);

// Import (CSV) state
const importFileInput = ref(null);
const importWithSuccess = ref(false);
const importWithError = ref(false);
const importOkText = ref("");
const importErrorText = ref("");

/* ************************************** */

onMounted(() => {
    updateSankeyData();
})

/* ************************************** */

onBeforeMount(() => {
    const activeTabURL = ntopng_url_manager.get_url_entry("tab")
    activeTab.value = activeTabURL ? activeTabURL : "stats";
    retrieveSitesList()
})

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

watch(activeTab, (newVal) => {
    // This is mandatory because when switching between tables, being just "hidden" the tables
    // to have a fast load, the jquery resize properties are not correctly loaded (size at 0)
    if (newVal === 'stats') {
        tableSitesStats?.value?.redrawTable()
    } else {
        tableSitesConfig?.value?.redrawTable()
    }
}, { flush: 'post' })

/* ************************************** */

const switchActiveTab = function (tab) {
    activeTab.value = tab.id
    ntopng_url_manager.set_key_to_url("tab", tab.id)
}

/* ************************************** */

const refreshActiveTable = () => {
    tableSitesStats.value?.refresh_table(true);
    tableSitesConfig.value?.refresh_table(true);
}

/* ************************************** */

const updateSankeyData = async () => {
    loading.value = true;
    let data = await getSankeyData();
    sankey_data.value = data;
    loading.value = false;
}

/* ***************************************************** */

const getExtraParameters = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    if (!props.context.isEnterpriseXL || !props.context.hasClickHouseSupport) {
        extra_params.epoch_begin = null
        extra_params.epoch_end = null
    }
    return extra_params;
};

/* ************************************** */

const getSankeyUrl = () => {
    let params = {
        ifid: props.context.ifid,
        ...getExtraParameters()
    }
    let url_params = ntopng_url_manager.obj_to_url_params(params);
    let url_request = `${sankey_url}?${url_params}`;
    return url_request;
}

/* ************************************** */

const getSankeyData = async () => {
    const url_request = getSankeyUrl();
    let graph = await ntopng_utility.http_request(url_request);
    graph.nodes.forEach((node, i) => {
        node.index = i
    })
    graph.links.forEach((link, i) => {
        if (link.value === 0) {
            link.value = 1
        }
        let node = graph.nodes.find((el) => el.node_id == link.source_node_id)
        link.source = node.index;
        node = graph.nodes.find((el) => el.node_id == link.target_node_id)
        link.target = node.index;
    })

    return graph
}

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        /* Stats */
        // Site name column - displays the name directly
        "site_a": (value, row) => {
            return value.name
        },
        // Site name column - displays the name directly
        "site_b": (value, row) => {
            return value.name
        },
        "bytes_sent": (value, row) => {
            return FormatterUtils.getFormatter("bytes")(value);
        },
        "bytes_rcvd": (value, row) => {
            return FormatterUtils.getFormatter("bytes")(value);
        },
        "total_bytes": (value, row) => {
            return FormatterUtils.getFormatter("bytes")(value);
        },
        /* Config */
        // Site name column - displays the name directly
        "name": (value, row) => {
            return value
        },
        // Site name column - displays the name directly
        "parent": (value, row) => {
            if (!value)
                return ''
            const netSite = sitesList.value.find((el) => String(el.id) === String(value))
            if (!netSite)
                return ''
            return netSite.name
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
        /* Config */
        if (col.id == "name") {
            return sortingFunctions.sortByName(r0.name, r1.name, col.sort);
        } else if (col.id == "parent") {
            return sortingFunctions.sortByName(r0.parent, r1.parent, col.sort);
        } else if (col.id == "site_a") {
            return sortingFunctions.sortByName(r0.site_a.name, r1.site_a.name, col.sort);
        } else if (col.id == "site_b") {
            return sortingFunctions.sortByName(r0.site_b.name, r1.site_b.name, col.sort);
        } else if (col.id == "bytes_sent") {
            return sortingFunctions.sortByNumber(r0.bytes_sent, r1.bytes_sent, col.sort);
        } else if (col.id == "bytes_rcvd") {
            return sortingFunctions.sortByNumber(r0.bytes_rcvd, r1.bytes_rcvd, col.sort);
        } else if (col.id == "total_bytes") {
            return sortingFunctions.sortByNumber(r0.total_bytes, r1.total_bytes, col.sort);
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
    };

    if (events_managed[event.event_id] == null) {
        return;  // Unknown event - ignore
    }
    events_managed[event.event_id](event);
}

// Handler for edit button click
const click_button_edit_site = (event) => {
    const row = event.row
    if (!row) return;
    if (row.id == 0) return;  // Default site cannot be edited

    editingSiteId.value = row.id;

    // Prepare site data for the edit modal
    const site_data = {
        site_id: row.id, 
        site_name: row.name,
        site_description: row.description,
        site_networks: row.networks,
        site_lat: row.latitude,
        site_lng: row.longitude,
        site_reserved: row.reserved,
        site_parent: row.parent
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
        site_parent: row.site_parent
    };

    showDeleteModal(site_data);
}

/* ************************************** */
// Opens the add site modal with empty form
function openAddSiteModal() {
    siteModal.value.open();
}

/* ************************************** */
// Shows the delete confirmation modal
const showDeleteModal = (item) => {
    siteModalDelete.value.showDelete(item);
};


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
// Handles the edit form submission
// Sends updated site data to the server
const handleEditSite = (data) => {
    modalErrorMessage.value = "";  // Clear any previous error

    const {
        site_name,
        site_description,
        site_networks,
        site_lat,
        site_lng,
        site_parent
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
            longitude: site_lng,
            site_parent
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
            site_parent: data.site_parent,
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

const updateSitesList = function (res) {
    sitesList.value = res?.rows?.filter(el => el.id !== "0");
}
</script>

<style>
.add-effect-move,
/* apply transition to moving elements */
.add-effect-enter-active,
.add-effect-leave-active {
    transition: all 0.35s ease;
}

/* Transform: positive pixels, the effects let enters the component
 * from the right, negative pixels from the left
 */
.add-effect-enter-from {
    opacity: 0;
    transform: translateX(-60px);
}

.add-effect-leave-to {
    opacity: 0;
    transform: translateX(0px);
}

/* ensure leaving items are taken out of layout flow so that moving
   animations can be calculated correctly. */
.add-effect-leave-active {
    position: absolute;
}
</style>

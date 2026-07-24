<!-- (C) 2026 - ntop.org -->
<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_networks_stats" :table_id="networks_table" :csrf="csrf" :showLoading="true"
            :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
            :handleLoadedColumns="handleLoadedColumns" @custom_event="on_table_custom_event">

            <!-- add Networks 
            <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" @click="openAddNetworksModal">
                    <i class="fas fa-plus"></i>
                </button>
            </template>
-->
        </TableWithConfig>
    </div>

    <!-- Modal components for site management -->
    <ModalEditNetwork ref="networkModal" :errorMessage="modalNetworkErrorMessage" :sitesList="sitesList"
        @edit="handleEditNetwork">
    </ModalEditNetwork>
    <NoteList :note_list="note_list"></NoteList>
</template>


<script setup>
import { ref, onBeforeMount, watch } from "vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as ModalEditNetwork } from "./modal-edit-network.vue";
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

// Emitted after a network is successfully edited, so an embedding parent
// (e.g. the sites dashboard's tree sidebar) can invalidate its own cached
// copy of the site hierarchy instead of going stale.
const emit = defineEmits(["network_changed"]);

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
const SITE_API = {
    get: `${http_prefix}/lua/pro/rest/v2/get/sites/list.lua`,
    net_edit: `${http_prefix}/lua/rest/v2/edit/network/edit.lua`
};

const areNetworksTsEnabled = props.context.areNetworksTsEnabled;
const csrf = props.context.csrf;

/* ************************************** */
// Networks
const modalErrorMessage = ref('');
const networkModal = ref(null);
const modalNetworkErrorMessage = ref('');
const networks_table = ref('networks_list');
const table_networks_stats = ref(null);
const sitesList = ref([]);

/*******************************************************/

/* This function dinamycally modify the columns in order to 
 * change visibility of the columns based on license and available 
 * data (e.g. flow exporters)
 */
const handleLoadedColumns = (columns) => {
    let modified_columns = columns
    if (props.context.isPro === false) {
        /* Remove the column Exporter IP, In/Out interface in case ntopng has no exporters */
        modified_columns = modified_columns.filter((element) => {
            return ((element.id !== "site"))
        })
    }
    return modified_columns
}

/* ************************************** */

onBeforeMount(() => {
    retrieveSitesList()
})

/* ************************************** */

const retrieveSitesList = function () {
    sitesList.value = [];
    if (props.context.isPro) {
        // Send edit request to server
        ntopng_utility.http_request(SITE_API.get)
            .then(data => {
                sitesList.value = data;
            })
            .catch(err => console.error('Error retrieving Sites'))
    }
}

/* ************************************** */

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
    ntopng_utility.http_request(SITE_API.net_edit, {
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

const refreshActiveTable = function () {
    table_networks_stats.value.refresh_table(true);
    emit("network_changed");
}
</script>

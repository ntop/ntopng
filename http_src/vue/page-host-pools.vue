<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_host_pools" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event">
            <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" ref="add_new_pool" @click="addNewPool">
                    <i class="fas fa-plus"></i>
                </button>
            </template>

        </TableWithConfig>

        <!-- Buttons for policy export and management -->
        <div class="card-footer mt-3">
            <div class="d-flex gap-2">
                <a class="btn btn-secondary" style="" :href="pool_configuration_url">
                    <i class="fas fa-tasks" data-bs-toggle="tooltip" data-bs-placement="top"
                        :title="_i18n('manage_configurations.manage_configuration')"></i> {{
                            _i18n('manage_configurations.manage_configuration') }}
                </a>
                <a v-if="!isnEdge" class="btn btn-primary" download="policy.json" :href="export_policy_url">
                    <i class="fas fa-file-export" data-bs-toggle="tooltip" data-bs-placement="top"
                        :title="_i18n('manage_configurations.export_policy')"></i> {{
                            _i18n('manage_configurations.export_policy') }}
                </a>
            </div>
        </div>
    </div>

    <!-- Modals to add and delete host pools -->
    <ModalAddHostPool ref="modal_add_pool" :context="context" @add="handleAddPool" @edit="handleEditPool">
    </ModalAddHostPool>

    <ModalDeleteConfirm ref="modal_delete_pool" :title="title_delete" :body="body_delete" @delete="handleDeletePool">
    </ModalDeleteConfirm>
</template>

<script setup>
import { ref, nextTick } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";
import { default as ModalAddHostPool } from "./modal-add-host-pool.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const table_id = ref('host_pools');
const table_host_pools = ref(null);
const csrf = props.context.csrf;
const isnEdge = props.context.isnEdge;
const isPro = props.context.isPro;
const pool_base_url = `${http_prefix}/lua/hosts_stats.lua?pool=`;
const modal_add_pool = ref(null);
const modal_delete_pool = ref(null);
const add_new_pool = ref(null);
const title_delete = i18n("host_pools.delete_pool");
let body_delete_18n = i18n("pools.remove_pool");

// delete modal variables
const body_delete = ref('');
const current_pool_to_delete = ref(null);

// table footer buttons urls
const export_policy_url = `${http_prefix}/lua/pro/rest/v2/export/pool/policy.lua?download=1`
const pool_configuration_url = `${http_prefix}/lua/admin/manage_configurations.lua?item=pool`

// add new pool
const addNewPool = () => {
    modal_add_pool.value.show();
};

/* handles post request to add a new pool from modal */
const handleAddPool = async (params) => {
    const url = `${http_prefix}/lua/rest/v2/add/host/pool.lua`;

    const requestParams = {
        csrf: props.context.csrf,
        pool_name: params.pool_name,
        pool_members: params.pool_members
    };

    let headers = {
        'Content-Type': 'application/json'
    };

    try {
        await ntopng_utility.http_request(url, {
            method: 'post',
            headers,
            body: JSON.stringify(requestParams)
        });

        // Refresh the table
        table_host_pools.value.refresh_table(true);
    } catch (e) {
        console.error('Network error:', e.message);
    }
};

/* called on edit modal close to post the new pool config */
const handleEditPool = async (params) => {
    const url = `${http_prefix}/lua/rest/v2/edit/host/pool.lua`;

    const requestParams = {
        csrf: props.context.csrf,
        pool_name: params.pool_name,
        pool_members: params.pool_members,
        pool: params.item.pool // this is the pool id
    };
    console.log(requestParams)

    let headers = {
        'Content-Type': 'application/json'
    };

    try {
        await ntopng_utility.http_request(url, {
            method: 'post',
            headers,
            body: JSON.stringify(requestParams)
        });

        // Refresh the table
        table_host_pools.value.refresh_table(true);

    } catch (e) {
        console.error('Network error:', e.message);
    }
};

/* deletes the selected pool */
const handleDeletePool = async (params) => {
    const url = `${http_prefix}/lua/rest/v2/delete/host/pool.lua`;

    const requestParams = {
        csrf: props.context.csrf,
        pool: current_pool_to_delete.value
    };

    let headers = {
        'Content-Type': 'application/json'
    };

    try {
        await ntopng_utility.http_request(url, {
            method: 'post',
            headers,
            body: JSON.stringify(requestParams)
        });

        // Refresh the table
        table_host_pools.value.refresh_table(true);
        // Clear the selected pool
        current_pool_to_delete.value = null;
    } catch (e) {
        console.error('Network error:', e.message);
    }
};

const map_table_def_columns = (columns) => {
    let map_columns = {
        "pool_name": (value, row) => {
            const url = pool_base_url + row["pool_id"]
            return `<a href="${url}">${value}</a>`
        },
        "hosts": (value, row) => {
            if(value != "0") { return formatterUtils.getFormatter("number")(value); } else { return(""); }
        },
        "seen_since": (value, row) => {
	    if(value == 0) return("");
            const formattedDate = NtopUtils.secondsToTime(Math.round(new Date().getTime() / 1000) - value)
            return formattedDate;
        },
        "breakdown": (value, row) => {
            return NtopUtils.createBreakdown(value.bytes_sent, value.bytes_rcvd, _i18n('sent'), _i18n('rcvd'))
        },
        "throughput": (value, row) => {
            return formatterUtils.getFormatter("bps")(value);
        },
        "traffic": (value, row) => {
	    if(value == 0) return("");
            return formatterUtils.getFormatter("bytes")(value);
        },
        "clean_members": (value, row) => {
            // format as member1, member2, member3 etc
            return Object.values(value).join(', ');
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        // disable action dropdown items
        if (c.id == "actions") {

            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {

                    // disable dropdown button delete for pools: 'Jailed Hosts' and 'Default'
                    if ((row.pool_name === "Jailed Hosts" || row.pool_name === "Default") &&
                        b.id === "delete") {
                        current_class.push("disabled");

                    } else if (row.pool_name === "Default" && b.id === "manage_pool") {
                        // disable dropdown button manage pool for pool: 'Default'
                        current_class.push("disabled");
                    }
                    else if (b.id === "edit_pool_policy" && (!isPro || !isnEdge)) {
                        current_class.push("disabled");
                    }
                    return current_class;
                }
            });
        }
    });
    return columns;
};

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "pool_name") {
            return sortingFunctions.sortByName(r0.pool_name, r1.pool_name, col.sort);
        } else if (col.id == "hosts") {
            return sortingFunctions.sortByNumber(r0.hosts, r1.hosts, col.sort);
        } else if (col.id == "seen_since") {
            return sortingFunctions.sortByNumber(r0.seen_since, r1.seen_since, col.sort);
        } else if (col.id == "throughput") {
            return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
        } else if (col.id == "traffic") {
            return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
        }
    }
}

/* Used to Handle click on actions dropdown */
function on_table_custom_event(event) {
    let events_managed = {
        "click_manage_pool": click_manage_pool,
        "click_edit_pool": click_edit_pool,
        "click_edit_pool_policy": click_edit_pool_policy,
        "click_delete_pool": click_delete_pool,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* Functions below are used to handle 'actions' dropdown click */

/* redirect to manage pool page */
const click_manage_pool = (param) => {
    let pool_id = param.row.pool_id;
    let manage_pool_url = `${http_prefix}/lua/admin/manage_host_members.lua?pool=${pool_id}`;
    // open page in current tab
    window.location.href = manage_pool_url;
};

/* edit pool button to change pool name */
const click_edit_pool = (param) => {
    // memebers is an array, rest expects string of elements
    let members_array = param.row.members
    let members_string = members_array.join(",")

    // Check if the modal ref exists
    if (!modal_add_pool.value) {
        console.error('Edit Modal reference is null in parent');
        return;
    }

    const poolData = {
        pool: param.row.pool_id,
        pool_name: param.row.pool_name,
        pool_members: members_string,
    };

    modal_add_pool.value.showEdit(poolData);
};

/* edit pool button to change pool policy */
const click_edit_pool_policy = (param) => {
    let pool_id = param.row.pool_id;
    let pool_name = param.row.pool_name;
    let manage_pool_url;
    
    if(isnEdge)
        manage_pool_url = `${http_prefix}/lua/pro/nedge/admin/nf_edit_user.lua?username=${pool_name}`;
    else
        manage_pool_url = `${http_prefix}/lua/pro/policy.lua?pool=${pool_id}`;
    // open page in current tab
    window.location.href = manage_pool_url;
};

/* delete host pool */
const click_delete_pool = (param) => {

    if (!modal_delete_pool.value) {
        console.error('Delete modal reference is null');
        return;
    }

    // store pool to be deleted
    current_pool_to_delete.value = param.row.pool_id;

    // reate body text
    const body_text = body_delete_18n.replace("%{pool}", param.row.pool_name);

    // Pass the dynamic body and title to the show method
    modal_delete_pool.value.show(body_text, title_delete);
};
</script>
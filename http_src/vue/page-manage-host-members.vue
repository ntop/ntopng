<template>
    <div class="m-2 mb-3">
        <!-- Edit traffic policy button -->
        <button class="btn btn-primary" type="button" @click="editTrafficPolicy" v-show="true">
            <i class="fas fa-shield-alt" data-bs-toggle="tooltip" data-bs-placement="top"></i>
            {{ _i18n('host_pools.edit_traffic_policy') }}
        </button>


        <!-- Table component -->
        <TableWithConfig ref="table_host_pools" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event"
            :get_extra_params_obj="get_extra_params_obj">
            <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" ref="add_new_pool" @click="addNewPool">
                    <i class="fas fa-plus"></i>
                </button>
            </template>
        </TableWithConfig>

        <div class="card-footer mt-3">
            <div class="d-flex gap-2">
                <a class="btn btn-secondary" style="" :href="pool_configuration_url">
                    <i class="fas fa-file-import" data-bs-toggle="tooltip" data-bs-placement="top"
                        :title="_i18n('host_pools.import_hosts')"></i>
                    {{ _i18n('host_pools.import_hosts') }}
                </a>
            </div>
        </div>
    </div>

    <ModalAddHostPoolMember ref="modal_add_member" :context="context" @add="handleAddMember" @edit="handleEditMember">
    </ModalAddHostPoolMember>

    <ModalDeleteConfirm ref="modal_delete_pool" :title="title_delete" :body="body_delete" @delete="handleDeleteMember">
    </ModalDeleteConfirm>
</template>

<script setup>
import { ref } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import formatterUtils from "../utilities/formatter-utils";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddHostPoolMember } from "./modal-host-pool-member.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const table_id = ref('manage_host_pool');
const table_host_pools = ref(null);
const csrf = props.context.csrf;
const modal_add_member = ref(null);
const modal_delete_pool = ref(null);
const add_new_pool = ref(null);
const member_to_delete = ref(null);

const title_delete = i18n("host_pools.delete_pool");
let body_delete_member_i18n_template = i18n("host_pools.remove_member_pool");

// delete modal variables
const body_delete = ref('');
const current_pool_to_delete = ref(null);

// table footer buttons urls
const pool_configuration_url = `${http_prefix}/lua/admin/manage_configurations.lua?item=pool`


// add new pool
const addNewPool = () => {
    modal_add_member.value.show();
};

/* redirect to pool policy page */
const editTrafficPolicy = () => {
    console.log('editTrafficPolicy called!');
    console.log('props.context:', props.context);
    console.log('pool_id:', props.context.pool_id);

    let pool_id = props.context.pool_id;
    let edit_policy_url = `${http_prefix}/lua/pro/policy.lua?pool=${pool_id}`;

    console.log('Navigating to:', edit_policy_url);
    window.location.href = edit_policy_url;
};


/* Used by table to pass parameter to default rest that populates table with data */
const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* handles post request to add a new pool member from modal */
const handleAddMember = async (params) => {
    const url = `${http_prefix}/lua/rest/v2/add/host/pool_member.lua`;

    const requestParams = {
        csrf: props.context.csrf,
        pool: props.context.pool_id,
        member: params.member
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

/* called on edit modal to edit a member */
const handleEditMember = async (params) => {

    const url = `${http_prefix}/lua/rest/v2/edit/host/pool/member.lua`;

    const requestParams = {
        action: "edit",
        csrf: props.context.csrf,
        member: params.member,
        old_member: params.old_member,
        pool: Number(props.context.pool_id)
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

/* deletes the selected member*/
const handleDeleteMember = async () => {

    const url = `${http_prefix}/lua/rest/v2/delete/host/pool_member.lua`;

    const requestParams = {
        csrf: props.context.csrf,
        pool: parseInt(member_to_delete.value.pool, 10),
        member: member_to_delete.value.member,
        pool_name: member_to_delete.value.pool_name
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
        "member_address": (value, row) => {
            return value
        },
        "vlan": (value, row) => {
            return value;
        },
        "type": (value, row) => {
            return formatterUtils.capitalizeFirstLetters(value)
        }
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        // disable action dropdown items
        if (c.id == "actions") {

            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {

                    // Disable dropdown button delete for pools: 'Jailed Hosts' and 'Default'
                    if ((row.pool_name === "Jailed Hosts" || row.pool_name === "Default") &&
                        b.id === "delete") {
                        current_class.push("disabled");

                    } else if (row.pool_name === "Default" && b.id === "manage_pool") {
                        // Disable dropdown button manage pool for pool: 'Default'
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
        if (col.id == "member_address") {
            return sortingFunctions.sortByIP(r0.name, r1.name, col.sort);
        } else if (col.id == "vlan") {
            return sortingFunctions.sortByNumber(r0.vlan, r1.vlan, col.sort);
        } else if (col.id == "member_type") {
            return sortingFunctions.sortByName(r0.type, r1.type, col.sort);
        }
    }
}

/* Used to Handle click on actions dropdown */
function on_table_custom_event(event) {
    let events_managed = {
        "click_edit_member": click_edit_member,
        "click_delete_member": click_delete_member,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}


const click_edit_member = (param) => {
    // Check if the modal ref exists
    if (!modal_add_member.value) {
        console.error('Modal reference is null in parent');
        return;
    }

    //  showEdit in modal expects this data
    const memberData = {
        name: param.row.name,
        type: param.row.type,
        vlan: param.row.vlan,
        member: param.row.member,
        pool: props.context.pool_id,
        pool_name: props.context.pool_name
    };

    modal_add_member.value.showEdit(memberData);
};

/* delete host pool member*/
const click_delete_member = (param) => {

    // Check if the modal ref exists
    if (!modal_delete_pool.value) {
        console.error('Delete modal reference is null');
        return;
    }

    // Store the pool to be deleted
    current_pool_to_delete.value = props.context.pool_id

    // Set the dynamic body text
    body_delete.value = body_delete_member_i18n_template.replace("%{member}", param.row.name);
    member_to_delete.value = { member: param.row.member, pool: current_pool_to_delete.value, pool_name: props.context.pool_name }

    // Show the delete confirmation modal with the body
    modal_delete_pool.value.show(
        body_delete.value,
        title_delete
    );
};

</script>
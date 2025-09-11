<!-- (C) 2024 - ntop.org     -->
<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_traffic_rules" :table_id="table_id" :csrf="context.csrf"
            :f_sort_rows="columns_sorting" @custom_event="on_table_custom_event" :f_map_columns="map_table_def_columns">
            <template v-slot:custom_buttons>
                <button class="btn btn-link" type="button" @click="add_profile">
                    <i class="fas fa-plus" data-bs-toggle="tooltip" data-bs-placement="top"
                        :title="_i18n('policy.add_profile')"></i>
                </button>
            </template>
        </TableWithConfig>
        <!--
        <div class="card-footer mt-3">
            <button v-if="false" type="button" ref="export_rules" @click="export_rules" class="btn btn-primary ms-1">
                <i class="fas fa-file-export"></i>
                {{ _i18n("acl_page.export_rules") }}
            </button>
            
        </div>
        -->
        <ModalAddTrafficProfile ref="trafficProfileModal" @add="handleAddProfile" @edit="handleEditProfile"
            </ModalAddTrafficProfile>
    </div>
</template>

<script setup>
import { ref } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as ModalAddTrafficProfile } from "./modal-add-traffic-profile.vue";

const props = defineProps({
    context: Object,
});

const ifid = props.context.ifid;
const areTsEnabled = props.context.areTsEnabled;

const _i18n = (t) => i18n(t);
const table_traffic_rules = ref(null);
const trafficProfileModal = ref(null);

const table_id = ref('traffic_profiles');

const delete_profile_url = `${http_prefix}/lua/pro/rest/v2/delete/filters/traffic_profile.lua`;
const add_profile_url = `${http_prefix}/lua/pro/rest/v2/add/filters/traffic_profile.lua`;

/* ******************************************************************** */
const map_table_def_columns = (columns) => {

    columns.forEach((c) => {

        if (c.id == "actions") {
            const visible_dict = {
                edit_rule: true,
                timeseries: areTsEnabled,
                delete_rule: true
            };

            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    // if is not defined is enabled
                    if (!visible_dict[b.id]) {
                        current_class.push("disabled");
                    }
                    return current_class;
                }
            });
        }
    });

    return columns;
};
/* ******************************************************************** */

/* Function to add a new host to scan */
function add_profile() {
    trafficProfileModal.value.show(null, props.context.host);
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "profileName") {
            return sortingFunctions.sortByName(r0.profileName, r1.profileName, col.sort);
        }
    }
}

/* ************************************** */

const showEditModal = (item) => {
    trafficProfileModal.value.showEdit(item);
};

/* ************************************** */
// delete the traffic profile
async function click_button_delete_profile(event) {
    const profile_name = event.row.profileName;

    const requestParams = {
        csrf: props.context.csrf,
        delete_profile: profile_name,
        ifid: ifid
    };

    let headers = {
        'Content-Type': 'application/json'
    };

    try {
        await ntopng_utility.http_request(delete_profile_url, {
            method: 'post',
            headers,
            body: JSON.stringify(requestParams)
        });

        // Refresh the table
        table_traffic_rules.value.refresh_table(true);
    } catch (e) {
        console.error('Network error:', e.message);
    }
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_edit_profile": click_button_edit_profile,
        "click_button_delete_profile": click_button_delete_profile,
        "click_button_timeseries": click_button_timeseries,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

// add new traffic profile
const handleAddProfile = async (data) => {
    let profile_name = data.profile_name
    let profile_filter = data.profile_filter;

    const requestParams = {
        csrf: props.context.csrf,
        profiles: [{ name: profile_name, filter: profile_filter }]
    };

    let headers = {
        'Content-Type': 'application/json'
    };

    try {
        await ntopng_utility.http_request(add_profile_url, {
            method: 'post',
            headers,
            body: JSON.stringify(requestParams)
        });

        // Refresh the table
        table_traffic_rules.value.refresh_table(true);
    } catch (e) {
        console.error('Network error:', e.message);
    }
};

// show edit modal when clicking edit on actions dropdown
const click_button_edit_profile = (event) => {
    const profile_data = {
        profile_name: event.row.profileName,
        profile_filter: event.row.profileFilter || ""
    };

    showEditModal(profile_data);
};

function click_button_timeseries(event) {
    let profileName = event.row.profileName
    window.location.href = `${http_prefix}/lua/pro/profile_details.lua?profile=${profileName}`;
}

const handleEditProfile = async (data) => {
    // data = { profile_name, profile_filter, item }
    const old_profile_name = data.item.profile_name;
    const new_profile_name = data.profile_name;
    const new_profile_filter = data.profile_filter;

    let headers = {
        'Content-Type': 'application/json'
    };

    try {
        // Delete the old profile
        const deleteParams = {
            csrf: props.context.csrf,
            delete_profile: old_profile_name,
            ifid: ifid
        };

        await ntopng_utility.http_request(delete_profile_url, {
            method: 'post',
            headers,
            body: JSON.stringify(deleteParams)
        });

        // create new profile
        const addParams = {
            csrf: props.context.csrf,
            profiles: [{
                name: new_profile_name,
                filter: new_profile_filter
            }]
        };

        await ntopng_utility.http_request(add_profile_url, {
            method: 'post',
            headers,
            body: JSON.stringify(addParams)
        });

        // Refresh the table
        table_traffic_rules.value.refresh_table(true);

    } catch (e) {
        console.error('Error during profile edit:', e);
        table_traffic_rules.value.refresh_table(true);
    }
};

</script>
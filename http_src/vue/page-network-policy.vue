<template>
    <div class="m-3">
        <template v-if="(!props.context.is_check_enabled)">
            <div class="alert alert-warning" role="alert" id='error-alert' v-html:="error_message">
            </div>
        </template>
        <div class="card card-shadow" :class="[(!props.context.is_check_enabled) ? 'ntopng-gray-out' : '']">
            <Loading :isLoading="isLoading"></Loading>
            <div class="card-body">
                <table class="table table-striped table-bordered col-sm-12">
                    <tbody class="table_length">
                        <tr v-for="(value, key) in check_name" :key="key" class="mb-4">
                            <td>
                                <div class="mb-2">
                                    <b>{{ _i18n(value.i18n_title) }}</b>
                                </div>
                                <div class="ms-4 me-4">
                                    <textarea v-model="networks[key]" class="form-control rounded"
                                        :class="(show_border_error) ? 'border-danger' : ''"
                                        :placeholder="`Enter ${value.device_type} Networks (Comma Separated)`"
                                        @input="markAsModified(key)" rows="2"></textarea>
                                    <small>{{ _i18n(value.i18n_description) }}</small>
                                    <div v-if="validationErrors[key]" class="text-danger mt-1">
                                        {{ validationErrors[key] }}
                                    </div>

                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>
                <div v-if="show_configuration_error" class="text-danger">
                    <span v-html="configuration_error"></span>
                </div>
                <div class="d-flex justify-content-between">
                    <div clas="align-items-center ms-auto">
                        <button class="btn btn-primary me-2" type="button" @click="import_policies">
                            <i class="fa-solid fa-file-arrow-up" data-bs-toggle="tooltip" data-bs-placement="top"
                                :title="_i18n('network_configuration.import_policies')"></i> {{
                                    _i18n('network_configuration.import_policies') }}
                        </button>
                        <a class="btn btn-primary" download="network_policies.json" :href="export_network_policies_url">
                            <i class="fa-solid fa-file-arrow-down" data-bs-toggle="tooltip" data-bs-placement="top"
                                :title="_i18n('network_configuration.export_policies')"></i> {{
                                    _i18n('network_configuration.export_policies') }}
                        </a>
                    </div>
                    <div clas="align-items-center ms-auto">
                        <button class="btn btn-primary" :disabled="disable_save" @click="reloadNetworks">
                            {{ _i18n('save_settings') }}
                        </button>
                    </div>
                </div>
            </div>
        </div>
        <NoteList :note_list="notes"> </NoteList>
    </div>

    <ModalImportNetworkPolicies ref="modal_import_network_policies" :context="context"
        @add="import_network_policies_rest">
    </ModalImportNetworkPolicies>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as NoteList } from "./note-list.vue";
import { default as Loading } from "./loading.vue";
import { default as ModalImportNetworkPolicies } from "./modal-import-network-policies.vue"
import regexValidation from "../utilities/regex-validation.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object
});

const notes = [
    _i18n("network_configuration.allowed_servers_description"),
    _i18n("network_configuration.uses_of_servers")
]

const networks = reactive({});
const validationErrors = reactive({});
const set_config_url = `${http_prefix}/lua/pro/rest/v2/set/network/policy.lua`
const get_config_url = `${http_prefix}/lua/pro/rest/v2/get/network/policy.lua`
const import_network_policies_url = `${http_prefix}/lua/pro/rest/v2/add/network/policy.lua`;
const export_network_policies_url = `${http_prefix}/lua/pro/rest/v2/export/network/policy.lua`;
const modifiedInputs = ref([]);
const modal_import_network_policies = ref();

const error_message = ref(_i18n('network_configuration.policy_note'))
const configuration_error = ref('');
const show_configuration_error = ref(false);
const isSaving = ref(false);
const saveSuccess = ref(false);
const disable_save = ref(true);
const show_border_error = ref(false);
const isLoading = ref(true);

const saveButtonText = computed(() => {
    if (isSaving.value) return 'Saving...';
    if (saveSuccess.value) return 'Saved!';
    return _i18n("flow_checks.save_configuration");
});

const saveButtonClass = computed(() => {
    if (saveSuccess.value) return 'btn btn-success';
    return 'btn btn-primary';
});

const reloadNetworks = function () {
    /* Save the configuration and reload the configured confs */
    saveConfig();
}

const check_name = {
    "local_devices": { "i18n_title": "network_configuration.local_devices_title", "device_type": "Local Devices", "reques_param": "local_devices", "i18n_description": "network_configuration.local_devices_description" },
    "corporate_devices": { "i18n_title": "network_configuration.corporate_devices_title", "device_type": "Corporate Devices", "reques_param": "corporate_devices", "i18n_description": "network_configuration.corporate_devices_description" },
    "whitelisted_networks": { "i18n_title": "network_configuration.whitelisted_networks_title", "device_type": "Whitelisted", "reques_param": "whitelisted_networks", "i18n_description": "network_configuration.whitelisted_networks_description" },
}

Object.keys(check_name).forEach(key => {
    networks[key] = '';
});

onMounted(() => {
    getConfig();
});

/* ************************************** */

function import_policies() {
    modal_import_network_policies.value.show();
}

const import_network_policies_rest = async function (params) {
    const url = import_network_policies_url;
    const result = await ntopng_utility.http_post_request(url, { ...{ csrf: props.context.csrf }, ...params }, false, true);

    if (result == null) {
        modal_import_network_policies.value.show_bad_feedback(_i18n("import_network_policies_error"));
    } else if (result.rc < 0) {
        modal_import_network_policies.value.show_bad_feedback(result.rsp.feedback);
        table_network_policies.value.refresh_table();
    } else {
        setTimeout(() => { modal_import_network_policies.value.close() }, 1000);

        getConfig();
    }
}

/* ************************************** */

// Function used to populate text area with data received from the backend at page initialization
const getConfig = async () => {
    isLoading.value = true;
    const data = await ntopng_utility.http_request(get_config_url)

    data.forEach(item => {
        const key = Object.keys(check_name).find(k => k === item.key);
        if (key) {
            networks[key] = Array.isArray(item.value_description)
                ? item.value_description.join(', ')
                : item.value_description;
        }
    })
    isLoading.value = false;
};

// Used to mark a text area as modified so that only modified text areas are sent to the backend to be stored in redis
const markAsModified = (key) => {
    if (!modifiedInputs.value.includes(key)) {
        modifiedInputs.value.push(key);
    }
    validationErrors[key] = '';
    disable_save.value = false;
};

// Function to validate Network addresses inserted in text area
const validateNetworkAddresses = () => {
    let isValid = true;
    Object.keys(networks).forEach((key) => {
        const fixed_networks = [];
        const network_list = networks[key].split(',').map(net => net.trim()).filter(net => net !== '');
        network_list.forEach((net) => {
            if (regexValidation.validateCIDR(net)) {
                fixed_networks.push(net);
                return;
            } else if (regexValidation.validateIPv4(net)) {
                fixed_networks.push(net + "/32");
                return;
            } else if (regexValidation.validateIPv6(net)) {
                fixed_networks.push(net + "/128");
                return;
            } else if (key === "whitelisted_networks") {
                if (regexValidation.validateMAC(net)) {
                    fixed_networks.push(net);
                    return;
                }
            }
            validationErrors[key] = 'Invalid Network format';
            isValid = false;
        })
        if (isValid) {
            networks[key] = fixed_networks.join(",")
        }
    });
    return isValid;
};

// Function used to post data to the backend and save the values in
const saveConfig = async () => {
    if (validateNetworkAddresses()) {
        isSaving.value = true;
        let data = { csrf: props.context.csrf };

        for (const server of modifiedInputs.value) {
            const value = networks[server];
            const key = check_name[server].reques_param
            data = {
                [key]: value,
                ...data
            }
        }

        const res = await ntopng_utility.http_post_request(set_config_url, data)
        modifiedInputs.value = [];
        if (!res.error) {
            // Show success when saved
            saveSuccess.value = true;
            configuration_error.value = '';
            show_configuration_error.value = false;
            disable_save.value = true;
            show_border_error.value = false;
            setTimeout(() => {
                saveSuccess.value = false;
                getConfig();
            }, 500);
        } else {
            configuration_error.value = 'Error: ' + res.error_msg;
            show_configuration_error.value = true;
            show_border_error.value = true;
        }
        return true;
    }

    return false;
};
</script>

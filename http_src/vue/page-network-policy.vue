<template>
    <div class="m-3">
        <div class="m-4 card card-shadow">
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
                <div class="d-flex justify-content-end me-1">
                    <button class="btn btn-primary" :disabled="disable_save" @click="reloadNetworks">
                        {{ _i18n('save_settings') }}
                    </button>
                </div>
            </div>
        </div>
        <NoteList :note_list="notes"> </NoteList>
    </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as NoteList } from "./note-list.vue";
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
const modifiedInputs = ref([]);

const alert_note = ref(_i18n('network_configuration.alert_note'))
const isSaving = ref(false);
const saveSuccess = ref(false);
const disable_save = ref(true)

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
    saveConfig()
    getConfig();
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

// Function used to populate text area with data received from the backend at page initialization
const getConfig = async () => {
    const data = await ntopng_utility.http_request(get_config_url)

    data.forEach(item => {
        const key = Object.keys(check_name).find(k => k === item.key);
        if (key) {
            networks[key] = Array.isArray(item.value_description)
                ? item.value_description.join(', ')
                : item.value_description;
        }
    })
};

// Used to mark a text area as modified so that only modified text areas are sent to the backend to be stored in redis
const markAsModified = (key) => {
    if (!modifiedInputs.value.includes(key)) {
        modifiedInputs.value.push(key);
    }
    disable_save.value = false
};

// Function to validate Network addresses inserted in text area
const validateNetworkAddresses = () => {
    let isValid = true;
    Object.keys(networks).forEach(key => {
        const network_list = networks[key].split(',').map(net => net.trim()).filter(net => net !== '');
        if (network_list.length === 0) {
            validationErrors[key] = '';
        } else if (!network_list.every(regexValidation.validateCIDR)) {
            validationErrors[key] = 'Invalid Network format';
            isValid = false;
        } else {
            validationErrors[key] = '';
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

        await ntopng_utility.http_post_request(set_config_url, data)
        modifiedInputs.value = [];

        // Show success when saved
        saveSuccess.value = true;
        setTimeout(() => {
            saveSuccess.value = false;
        }, 1500);
    }
};
</script>

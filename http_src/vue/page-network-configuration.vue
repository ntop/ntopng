<template>
    <div class="m-3">
        <div class="alert alert-info alert-dismissable">
            <span v-html="alert_note"></span>
        </div>
        <div class="card card-shadow">
            <div class="card-body">
                <Loading v-if="loading"></Loading>
                <table class="table table-striped table-bordered col-sm-12"
                    :class="[(loading) ? 'ntopng-gray-out' : '']">
                    <tbody class="table_length">
                        <tr v-for="(value, key) in check_name" :key="key" class="mb-4">
                            <td>
                                <div class="mb-2">
                                    <b>{{ _i18n(value.i18n_title) }}</b>
                                </div>
                                <div class="ms-4 me-4">
                                    <textarea v-model="ipAddresses[key]" class="form-control rounded"
                                        :placeholder="`Enter ${value.device_type} IPs (Comma Separated)`"
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
                    <button class="btn btn-primary" :disabled="disable_save" @click="reloadIp">
                        {{ _i18n('save_settings') }}
                    </button>
                </div>
            </div>
        </div>
        <NoteList :note_list="notes"> </NoteList>
    </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed, watch } from 'vue'
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as NoteList } from "./note-list.vue";
import regexValidation from "../utilities/regex-validation.js";
import { default as Loading } from "./loading.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object
});

const notes = [
    _i18n("network_configuration.allowed_servers_description"),
    _i18n("network_configuration.uses_of_servers")
]

const loading = ref(false);
const ipAddresses = reactive({});
const validationErrors = reactive({});
const set_config_url = `${http_prefix}/lua/rest/v2/set/network/config.lua`
const get_config_url = `${http_prefix}/lua/rest/v2/get/network/config.lua`
const modifiedInputs = ref([]);
const disable_save = ref(true)

const alert_note = ref(_i18n('network_configuration.alert_note'))
const isSaving = ref(false);
const saveSuccess = ref(false);

const saveButtonText = computed(() => {
    if (isSaving.value) return 'Saving...';
    if (saveSuccess.value) return 'Saved!';
    return _i18n("flow_checks.save_configuration");
});

const saveButtonClass = computed(() => {
    if (saveSuccess.value) return 'btn btn-success';
    return 'btn btn-primary';
});

const check_name = {
    "dns_list": { "i18n_title": "network_configuration.dns_servers_title", "device_type": "DNS Server", "reques_param": "dns_list", "i18n_description": "network_configuration.dns_servers_description" },
    "ntp_list": { "i18n_title": "network_configuration.ntp_servers_title", "device_type": "NTP Server", "reques_param": "ntp_list", "i18n_description": "network_configuration.ntp_servers_description" },
    "dhcp_list": { "i18n_title": "network_configuration.dhcp_servers_title", "device_type": "DHCP Server", "reques_param": "dhcp_list", "i18n_description": "network_configuration.dhcp_servers_description" },
    "smtp_list": { "i18n_title": "network_configuration.smtp_servers_title", "device_type": "SMTP Server", "reques_param": "smtp_list", "i18n_description": "network_configuration.smtp_servers_description" },
    "gateway_list": { "i18n_title": "network_configuration.gateway_servers_title", "device_type": "Gateway", "reques_param": "gateway_list", "i18n_description": "network_configuration.gateway_servers_description" },
}

Object.keys(check_name).forEach(key => {
    ipAddresses[key] = '';
});

onMounted(() => {
    getConfig();
});

// Function used to populate text area with data received from the backend at page initialization
const getConfig = async () => {
    loading.value = true;
    const data = await ntopng_utility.http_request(get_config_url)

    data.forEach(item => {
        const key = Object.keys(check_name).find(k => k === item.key);
        if (key) {
            ipAddresses[key] = Array.isArray(item.value_description)
                ? item.value_description.join(', ')
                : item.value_description;
        }
    })
    loading.value = false;
};

/* ************************************** */

// Used to mark a text area as modified so that only modified text areas are sent to the backend to be stored in redis
const markAsModified = (key) => {
    if (!modifiedInputs.value.includes(key)) {
        modifiedInputs.value.push(key);
    }
    disable_save.value = false
};

/* ************************************** */

// Function to validate IP addresses inserted in text area
const validateIpAddresses = () => {
    let isValid = true;
    Object.keys(ipAddresses).forEach(key => {
        const ips = ipAddresses[key].split(',').map(ip => ip.trim()).filter(ip => ip !== '');
        if (ips.length === 0) {
            validationErrors[key] = '';
        } else if (!ips.every(regexValidation.validateIP)) {
            validationErrors[key] = 'Invalid IP address format';
            isValid = false;
        } else {
            validationErrors[key] = '';
        }
    });
    return isValid;
};

const reloadIp = function () {
    saveConfig()
}

// Function used to post data to the backend and save the values in
const saveConfig = async () => {
    if (validateIpAddresses()) {
        isSaving.value = true;
        let data = { csrf: props.context.csrf };

        for (const server of modifiedInputs.value) {
            const value = ipAddresses[server];
            const key = check_name[server].reques_param
            data = {
                [key]: value,
                ...data
            }
        }

        await ntopng_utility.http_post_request(set_config_url, data)
        modifiedInputs.value = [];
        loading.value = true;
        // Show success when saved
        saveSuccess.value = true;
        setTimeout(() => {
            getConfig();
            saveSuccess.value = false;
        }, 1500);
    }
};
</script>

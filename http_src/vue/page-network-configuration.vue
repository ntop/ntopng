<template>
    <div class="container mt-4">
        <div v-for="(value, key) in check_name" :key="key" class="mb-4">
            <div class="mb-2">
                <strong>{{ _i18n(value.i18n_title) }}</strong>
            </div>
            <div>
                <textarea v-model="ipAddresses[key]" class="form-control rounded"
                    :placeholder="`Enter ${value.device_type} IPs (Comma Separated)`" @input="markAsModified(key)"
                    rows="3"></textarea>
                <div v-if="validationErrors[key]" class="text-danger mt-1">
                    {{ validationErrors[key] }}
                </div>
            </div>
        </div>
        <div class="d-flex justify-content-end mt-4">
            <button @click="saveConfig" :class="saveButtonClass" :disabled="isSaving"> {{ saveButtonText }}
            </button>
        </div>
    </div>
</template>

<script setup>
import { ref, reactive, onMounted, computed } from 'vue'
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import regexValidation from "../utilities/regex-validation.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object
});


const ipAddresses = reactive({});
const validationErrors = reactive({});
const set_config_url = `${http_prefix}/lua/rest/v2/set/network/config.lua`
const get_config_url = `${http_prefix}/lua/rest/v2/get/network/config.lua?ifid=${props.context.ifid}`
const modifiedInputs = ref([]);

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
    "dns_list":  { "i18n_title": "flow_checks.dns_servers_title", "device_type": "DNS Server", "reques_param": "dns_list" },
    "ntp_list":  { "i18n_title": "flow_checks.ntp_servers_title", "device_type": "NTP Server", "reques_param": "ntp_list" },
    "dhcp_list": { "i18n_title": "flow_checks.dhcp_servers_title", "device_type": "DHCP Server", "reques_param": "dhcp_list" },
    "smtp_list": { "i18n_title": "flow_checks.smtp_servers_title", "device_type": "SMTP Server", "reques_param": "smtp_list" },
    "gateway":         { "i18n_title": "flow_checks.gateway", "device_type": "Gateway", "reques_param": "gateway" },
}

Object.keys(check_name).forEach(key => {
    ipAddresses[key] = '';
});

onMounted(() => {
    getConfig();
});

// Function used to populate text area with data received from the backend at page initialization
const getConfig = async () => {
    const data = await ntopng_utility.http_request(get_config_url)

    data.forEach(item => {
        const key = Object.keys(check_name).find(k => k === item.key);
        if (key && item.is_enabled === true) {
            ipAddresses[key] = Array.isArray(item.value_description)
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
};

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

// Function used to post data to the backend and save the values in
const saveConfig = async () => {
    if (validateIpAddresses()) {
        isSaving.value = true;
        let data = { csrf: props.context.csrf, config: []};

        let headers = {
            'Content-Type': 'application/json'
        };

        try {
            for (const key of modifiedInputs.value) {
                const value = ipAddresses[key];
                const ips = value.split(',').map(ip => ip.trim());

                let requestData = {
                    asset_key: check_name[key].reques_param,
                    item: ips
                };

                data.config.push(requestData)

            }

            console.log(data)
            //await ntopng_utility.http_post_request(set_config_url, data);

            await ntopng_utility.http_request(set_config_url, { method: 'post', headers, body: JSON.stringify(data) })
            modifiedInputs.value = [];

            // Show success when saved
            saveSuccess.value = true;
            setTimeout(() => {
                saveSuccess.value = false;
            }, 1500);

        } catch (error) {
            console.error('Save failed:', error);

        } finally {
            isSaving.value = false;
        }
    }
};
</script>

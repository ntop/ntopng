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
const update_config_url = `${http_prefix}/lua/rest/v2/get/network_config/network_config.lua`
//const get_config_url = `${http_prefix}/lua/rest/v2/get/network_config/network_config.lua?action=get`
const get_config_url = `${http_prefix}/lua/rest/v2/get/checks/get_checks.lua?check_subdir=flow&ifid=${props.context.ifid}`
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
    "unexpected_dns": { "i18n_title": "flow_checks.dns_servers_title", "device_type": "DNS Server", "reques_param": "unexpected_dns" },
    "unexpected_ntp": { "i18n_title": "flow_checks.ntp_servers_title", "device_type": "NTP Server", "reques_param": "unexpected_ntp" },
    "unexpected_dhcp": { "i18n_title": "flow_checks.dhcp_servers_title", "device_type": "DHCP Server", "reques_param": "unexpected_dhcp" },
    "unexpected_smtp": { "i18n_title": "flow_checks.smtp_servers_title", "device_type": "SMTP Server", "reques_param": "unexpected_smtp" },
    "gateway": { "i18n_title": "flow_checks.gateway", "device_type": "Gateway", "reques_param": "gateway" },
}

Object.keys(check_name).forEach(key => {
    ipAddresses[key] = '';
});

onMounted(() => {
    getConfig();
});

const getConfig = async () => {
    const data = await ntopng_utility.http_request(get_config_url)
    console.log(data)
    
    data.forEach(item => {
        const key = Object.keys(check_name).find(k => k === item.key);
        if (key && item.is_enabled === true) {
            ipAddresses[key] = Array.isArray(item.value_description)
                ? item.value_description.join(', ')
                : item.value_description;
        }
    })
};


const markAsModified = (key) => {
    if (!modifiedInputs.value.includes(key)) {
        modifiedInputs.value.push(key);
    }
};

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

const saveConfig = async () => {
    if (validateIpAddresses()) {
        isSaving.value = true;
        try {
            for (const key of modifiedInputs.value) {
                const value = ipAddresses[key];
                const ips = value.split(',').map(ip => ip.trim());
                let enabled_value = ips.length > 0;

                let requestData = {
                    check_subdir: 'flow',
                    script_key: check_name[key].reques_param,
                    csrf: props.context.csrf,
                    JSON: JSON.stringify({
                        all: {
                            enabled: enabled_value,
                            script_conf: {
                                items: ips
                            }
                        }
                    })
                };
                console.log(requestData)
                await ntopng_utility.http_post_request(update_config_url, requestData);
                
            }
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

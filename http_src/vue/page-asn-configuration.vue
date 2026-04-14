<template>
    <div class="m-3">
        <template v-if="(!props.context.is_check_enabled)">
            <div class="alert alert-warning" role="alert" id='error-alert' v-html:="error_message">
            </div>
        </template>
        <div class="card card-shadow" :class="[(!props.context.is_check_enabled) ? 'ntopng-gray-out' : '']">
            <div class="card-body">
                <Loading :isLoading="loading"></Loading>
                <table class="table table-striped table-bordered col-sm-12">
                    <tbody class="table_length">
                        <tr v-for="(value, key) in check_name" :key="key" class="mb-4">
                            <td>
                                <div class="mb-2">
                                    <b>{{ _i18n(value.i18n_title) }}</b>
                                </div>
                                <div class="ms-4 me-4">
                                    <textarea v-model="asnList[key]" class="form-control rounded"
                                        :placeholder="`Enter a comma separated list of ASNs`"
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
                    <button class="btn btn-primary" :disabled="disable_save" @click="reloadASN">
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
    i18n('asn_configuration.notes')
]

const loading = ref(true);
const asnList = reactive({});
const validationErrors = reactive({});
const set_config_url = `${http_prefix}/lua/rest/v2/set/asn/config.lua`
const get_config_url = `${http_prefix}/lua/rest/v2/get/asn/config.lua`
const modifiedInputs = ref([]);
const disable_save = ref(true)

const error_message = ref(_i18n('asn_configuration.alert_note'))
const isSaving = ref(false);
const saveSuccess = ref(false);

const check_name = {
    "customer_asn": { "i18n_title": "asn_configuration.customer_asn_title", "request_param": "customer_asn", "i18n_description": "asn_configuration.customer_asn_description" },
    "sub_customer_asn": { "i18n_title": "asn_configuration.sub_customer_asn_title", "request_param": "sub_customer_asn", "i18n_description": "asn_configuration.sub_customer_asn_description" },
    "remote_asn": { "i18n_title": "asn_configuration.remote_asn_title", "request_param": "remote_asn", "i18n_description": "asn_configuration.remote_asn_description" },
}

Object.keys(check_name).forEach(key => {
    asnList[key] = '';
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
            asnList[key] = Array.isArray(item.value_description)
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

// Function to validate ASN inserted in text area
const validateASN = () => {
    let isValid = true;
    Object.keys(asnList).forEach(key => {
        const all_asn = asnList[key].split(',').map(asn => asn.trim()).filter(asn => asn !== '');
        if (all_asn.length === 0) {
            validationErrors[key] = '';
        } else if (!all_asn.every(regexValidation.validateUInt32)) {
            validationErrors[key] = 'Invalid ASN format';
            isValid = false;
        } else {
            validationErrors[key] = '';
        }
    });
    return isValid;
};

const reloadASN = function () {
    saveConfig()
}

// Function used to post data to the backend and save the values in
const saveConfig = async () => {
    if (validateASN()) {
        isSaving.value = true;
        let data = { csrf: props.context.csrf };

        for (const asn of modifiedInputs.value) {
            const value = asnList[asn];
            const key = check_name[asn].request_param
            const cleaned_value = Array.from(new Set(
                value.split(',').map(s => s.trim())
            )).join(',').replace(/\s*,\s*/g, ',');
            data = {
                [key]: cleaned_value,
                ...data
            }
        }
        const isCustomerAsnModified = modifiedInputs.value.includes('customer_asn');
        await ntopng_utility.http_post_request(set_config_url, data)
        modifiedInputs.value = [];
        loading.value = true;
        // Show success when saved
        saveSuccess.value = true;

        if (isCustomerAsnModified) {
            ToastUtils.showToast({
                id: "customer-asn-warning-alert",
                level: "warning",
                title: _i18n('warning'),
                body: _i18n("asn_configuration.costumer_asn_message"),
                delay: 6000,
            });
        }

        setTimeout(() => {
            getConfig();
            saveSuccess.value = false;
        }, 1500);
    }
};
</script>

<template>
    <div class="m-3">
        <template v-if="(!props.context.is_check_enabled)">
            <div class="alert alert-warning" role="alert" id='error-alert' v-html:="error_message">
            </div>
        </template>
        <div :class="[(!props.context.is_check_enabled) ? 'ntopng-gray-out' : '']">
            <div class="card card-shadow" :class="[(!props.context.is_check_enabled) ? 'ntopng-gray-out' : '']">
                <div class="card-body">
                    <Loading :isLoading="loading"></Loading>
                    <table class="table table-striped table-bordered col-sm-12">
                        <tbody class="table_length">
                            <tr class="mb-4">
                                <td>
                                    <div class="mb-2">
                                        <b>{{ _i18n("acl_page.scope_filters") }}</b>
                                    </div>
                                    <div class="ms-4 me-4">
                                        <textarea v-model="filters" class="form-control rounded"
                                            :placeholder="`Enter IP or Network CIDR, comma separated or on a newline (e.g. 192.168.1.1,10.0.0.1/24)`"
                                            @input="markAsModified" rows="15"></textarea>
                                        <div v-if="validationErrors" class="text-danger mt-1">
                                            {{ validationErrors }}
                                        </div>

                                    </div>
                                </td>
                            </tr>
                        </tbody>
                    </table>
                    <div class="d-flex justify-content-end me-1">
                        <button class="btn btn-primary" :disabled="disable_save" @click="reloadScopeFilters">
                            {{ _i18n('save_settings') }}
                        </button>
                    </div>
                </div>
            </div>
            <NoteList :note_list="notes"> </NoteList>
        </div>
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
    _i18n("acl_page.scope_filters_note_interfaces"),
    _i18n("acl_page.scope_filters_note"),
]

const loading = ref(true);
const filters = ref('');
const validationErrors = ref('');
const set_config_url = `${http_prefix}/lua/pro/rest/v2/add/system/access_control_list_scope.lua`
const get_config_url = `${http_prefix}/lua/pro/rest/v2/get/system/access_control_list_scope.lua`
const modifiedInputs = ref([]);
const disable_save = ref(true)

const error_message = i18n('acl_page.check_disabled') + " <a href='" + http_prefix + "/lua/admin/edit_configset.lua?subdir=all#disabled'><i class='fas fa-cog fa-sm'></i></a>";
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

onMounted(() => {
    getConfig();
});

// Function used to populate text area with data received from the backend at page initialization
const getConfig = async () => {
    loading.value = true;
    let data = await ntopng_utility.http_request(get_config_url)
    if (data.length > 0) {
        data = data.split(/[\n,]+/).map(s => s.trim()).filter(Boolean).join('\n')
    }
    filters.value = data;
    loading.value = false;
};

/* ************************************** */

// Used to mark a text area as modified so that only modified text areas are sent to the backend to be stored in redis
const markAsModified = () => {
    disable_save.value = false
};

/* ************************************** */

// Function to validate IP addresses inserted in text area
const validateFilters = () => {
    let isValid = true;
    const list = filters.value.split(/[\n,]+/).map(s => s.trim()).filter(Boolean);
    if (list.length === 0) {
        return true; // Valid, empty list
    }
    list.forEach(element => {
        if (!regexValidation.validateIP(element) && !regexValidation.validateCIDR(element)) {
            isValid = false;
            validationErrors.value = "Incorrect IP or Network CIDR: " + element;
        }
    });
    return isValid;
};

const reloadScopeFilters = function () {
    saveConfig()
}

// Function used to post data to the backend and save the values in
const saveConfig = async () => {
    if (validateFilters()) {
        isSaving.value = true;
        const scope_filters = filters.value.split(/[\n,]+/).map(s => s.trim()).filter(Boolean).join(',')
        let data = {
            csrf: props.context.csrf,
            scope_filters: scope_filters
        };

        await ntopng_utility.http_post_request(set_config_url, data)
        validationErrors.value = null;
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

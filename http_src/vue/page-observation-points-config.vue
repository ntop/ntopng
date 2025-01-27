<template>
    <div class="m-3">
        <div class="card card-shadow">
            <div class="card-body">
                <form @submit.prevent="saveConfig">
                    <table class="table table-striped table-bordered">
                        <tbody>
                            <tr>
                                <th>{{ _i18n("observation_point_alias") }}</th>
                                <td>
                                    <input 
                                        type="text" 
                                        v-model="aliasValue"
                                        class="form-control"
                                        :placeholder="defaultAlias"
                                        @input="handleInput"
                                    />
                                </td>
                            </tr>
                        </tbody>
                    </table>
                    <div class="d-flex justify-content-end me-1">
                        <button 
                            class="btn"
                            :class="saveButtonClass"
                            :disabled="disableSave"
                            @click="saveConfig"
                        >
                            {{ saveButtonText }}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue'
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object
});

const aliasValue = ref('');
const defaultAlias = ref('');
const disableSave = ref(true);
const isSaving = ref(false);
const saveSuccess = ref(false);

// Computed properties for button states
const saveButtonText = computed(() => {
    if (isSaving.value) return 'Saving...';
    if (saveSuccess.value) return 'Saved!';
    return _i18n("save_settings");
});

const saveButtonClass = computed(() => {
    if (saveSuccess.value) return 'btn-success';
    return 'btn-primary';
});

// API endpoints
const get_alias_url = `${http_prefix}/lua/rest/v2/get/observation_points/alias.lua?observation_point=${props.context.obs_point_id}`;
const set_alias_url = `${http_prefix}/lua/rest/v2/set/observation_points/alias.lua`;

// get alias
onMounted(async () => {
    try {
        const response = await ntopng_utility.http_request(get_alias_url);
        if (response) {
            aliasValue.value = response;
        }
    } catch (error) {
        console.error('Error fetching alias:', error);
    }
});

// Handle input changes
const handleInput = () => {
    disableSave.value = aliasValue.value === defaultAlias.value;
};


const saveConfig = async () => {
    if (disableSave.value) return;
    
    isSaving.value = true;
    try {
        await ntopng_utility.http_post_request(set_alias_url, {
            csrf: props.context.csrf,
            alias: aliasValue.value,
            observation_point: props.context.obs_point_id
        });

        // Show success state
        saveSuccess.value = true;
        disableSave.value = true;
        defaultAlias.value = aliasValue.value;
        
        setTimeout(() => {
            saveSuccess.value = false;
        }, 100);
        window.location.reload();

    } catch (error) {
        console.error('Error saving alias:', error);
    } finally {
        isSaving.value = false;
    }
};
</script>
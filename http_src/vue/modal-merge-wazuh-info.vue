<!-- (C) 2026 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>{{ _i18n("asset_details.merge_wazuh_info") }}</template>

        <template v-slot:body>
            <div v-if="state == 'confirm'" class="alert alert-warning text-start">
                {{ _i18n("asset_details.merge_wazuh_info_confirm") }}
            </div>

            <div v-if="state == 'loading'" class="d-flex align-items-center gap-2">
                <div class="spinner-border spinner-border-sm text-primary" role="status"></div>
                <span>{{ _i18n("loading") }}</span>
            </div>

            <div v-if="state == 'success'" class="alert alert-success text-start">
                <i class="fas fa-check-circle me-1"></i>
                {{ _i18n("asset_details.merge_wazuh_info_success") }}
            </div>

            <div v-if="state == 'error'" class="alert alert-danger text-start">
                <i class="fas fa-exclamation-triangle me-1"></i>
                {{ error_message }}
            </div>
        </template>

        <template v-slot:footer>
            <button v-if="state == 'confirm'" type="button" @click="on_confirm"
                class="btn btn-warning">
                <i class="fas fa-heartbeat me-1"></i>
                {{ _i18n("asset_details.merge_wazuh_info") }}
            </button>

            <button v-if="state == 'success' || state == 'error'" type="button" @click="close"
                class="btn btn-secondary">
                {{ _i18n("close") }}
            </button>
        </template>
    </modal>
</template>

<script setup>
/* Imports */
import { ref } from "vue";
import { default as modal } from "./modal.vue";

/* ****************************************************** */

const _i18n = (t) => i18n(t);
const emit = defineEmits(["merge"]);

const state = ref('confirm');
const error_message = ref('');
const modal_id = ref(null);

/* ****************************************************** */

const show = () => {
    state.value = 'confirm';
    error_message.value = '';
    modal_id.value.show();
};

const on_confirm = () => {
    state.value = 'loading';
    emit('merge');
};

const show_success = () => {
    state.value = 'success';
};

const show_error = (message) => {
    error_message.value = message;
    state.value = 'error';
};

const close = () => {
    modal_id.value.close();
};

defineExpose({ show, close, show_success, show_error });
</script>
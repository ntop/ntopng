<!-- (C) 2026 - ntop.org     -->
<template>
    <modal @showed="showed()" @hidden="on_hidden()" ref="modal_id">
        <!-- Modal title: displays the localized "Merge Wazuh Info" label -->
        <template v-slot:title>{{ _i18n("asset_details.merge_wazuh_info") }}</template>

        <template v-slot:body>
            <!-- Confirmation state: warns the user before proceeding with the merge -->
            <div v-if="state == 'confirm'" class="alert alert-warning text-start">
                {{ _i18n("asset_details.merge_wazuh_info_confirm") }}
            </div>
            
            <!-- Loading state: shown while the merge operation is in progress -->
            <div v-if="state == 'loading'" class="d-flex align-items-center gap-2">
                <div class="spinner-border spinner-border-sm text-primary" role="status"></div>
                <span>{{ _i18n("loading") }}</span>
            </div>

            <!-- Success state: displayed when the merge operation completes successfully -->
            <div v-if="state == 'success'" class="alert alert-success text-start">
                <div class="mb-2">
                    <i class="fas fa-check-circle me-1"></i>
                    {{ _i18n("asset_details.merge_wazuh_info_success") }}
                </div>
                <hr class="my-2">
                <div class="d-flex gap-4">
                    <div class="text-center">
                        <div class="fw-bold fs-5">{{ merge_stats.updated }}</div>
                        <small>{{ _i18n("asset_details.merge_wazuh_info_updated") }}</small>
                    </div>
                    <div class="text-center">
                        <div class="fw-bold fs-5">{{ merge_stats.not_found }}</div>
                        <small>{{ _i18n("asset_details.merge_wazuh_info_not_found") }}</small>
                    </div>
                    <div class="text-center">
                        <div class="fw-bold fs-5">{{ merge_stats.errors }}</div>
                        <small>{{ _i18n("asset_details.merge_wazuh_info_errors") }}</small>
                    </div>
                </div>
            </div>

            <!-- Error state: displayed when the merge operation fails; shows the error message -->
            <div v-if="state == 'error'" class="alert alert-danger text-start">
                <i class="fas fa-exclamation-triangle me-1"></i>
                {{ error_message }}
            </div>
        </template>

        <template v-slot:footer>
            <!--
              Confirm button: visible only during the confirmation state.
              Clicking it triggers on_confirm(), which transitions to "loading"
              and emits the "merge" event to the parent component.
            -->
            <button v-if="state == 'confirm'" type="button" @click="on_confirm"
                class="btn btn-warning">
                <i class="fas fa-heartbeat me-1"></i>
                {{ _i18n("asset_details.merge_wazuh_info") }}
            </button>

            <!--
              Close button: visible after a terminal state (success or error).
              Closes the modal, allowing the user to dismiss the dialog.
            -->
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

/**
 * merge: fired when the user confirms the merge action. The parent is 
 * responsible for performing the operation and calling show_success() 
 * or show_error() accordingly.
 */
const emit = defineEmits(["merge"]);

/**
 * state: tracks the current phase of the modal workflow.
 * Possible values:
 *   - 'confirm'  → awaiting user confirmation
 *   - 'loading'  → merge operation is in progress
 *   - 'success'  → operation completed successfully
 *   - 'error'    → operation failed
 */
const state = ref('confirm');

/** Holds the error message to display when the merge operation fails. */
const error_message = ref('');

const merge_stats = ref({ updated: 0, not_found: 0, errors: 0 });
/** Template ref for the underlying <modal> component instance. */
const modal_id = ref(null);

/* ****************************************************** */

const showed = () => { };

const on_hidden = () => {
    state.value = 'confirm';
    error_message.value = '';
    merge_stats.value = { updated: 0, not_found: 0, errors: 0 };
};

const show = () => {
    state.value = 'confirm';
    error_message.value = '';
    merge_stats.value = { updated: 0, not_found: 0, errors: 0 };
    modal_id.value.show();
};


/**
 * Handles the user's confirmation click.
 * Transitions the modal to the "loading" state and emits the "merge" event
 * so the parent component can execute the actual merge operation.
 */
const on_confirm = () => {
    state.value = 'loading';
    emit('merge');
};

/**
 * Transitions the modal to the "success" state.
 * Should be called by the parent after a successful merge operation.
 */
const show_success = (stats = {}) => {
    merge_stats.value = {
        updated: stats.updated ?? 0,
        not_found: stats.not_found ?? 0,
        errors: stats.errors ?? 0,
    };
    state.value = 'success';
};


/**
 * Transitions the modal to the "error" state and sets the error message.
 * Should be called by the parent when the merge operation fails.
 */
const show_error = (message) => {
    error_message.value = message;
    state.value = 'error';
};

/**
 * Programmatically closes the modal dialog.
 * Useful for allowing the parent to dismiss the modal after post-merge cleanup.
 */
const close = () => {
    modal_id.value.close();
};

/**
 * show(): open the modal in confirmation state
 * close(): close the modal
 * show_success(): transition to success state
 * show_error(): transition to error state with a message
 */
defineExpose({ show, close, show_success, show_error });
</script>
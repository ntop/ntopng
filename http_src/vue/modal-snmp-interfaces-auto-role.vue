<!-- (C) 2013-26 - ntop.org -->
<template>
    <modal @showed="showed()" ref="modal_id">
        <!-- Modal title -->
        <template v-slot:title>{{ _i18n("snmp.snmp_interfaces_auto_role") }}</template>

        <template v-slot:body>
            <!-- Confirmation state: warns the user before proceeding -->
            <div v-if="state == 'confirm'" class="alert alert-warning text-start">
                {{ _i18n("snmp.auto_assign_role_confirm") }}
            </div>

            <!-- Loading state: shown while the operation is in progress -->
            <div v-if="state == 'loading'" class="d-flex align-items-center gap-2">
                <div class="spinner-border spinner-border-sm text-primary" role="status"></div>
                <span>{{ _i18n("loading") }}</span>
            </div>

            <!-- Success state: shows how many interfaces were updated -->
            <div v-if="state == 'success'" class="alert alert-success text-start">
                <i class="fas fa-check-circle me-1"></i>
                {{ _i18n("snmp.auto_assign_role_success") }}
                <span class="fw-bold">{{ updated_count }}</span>
            </div>

            <!-- Error state: shown when the operation fails -->
            <div v-if="state == 'error'" class="alert alert-danger text-start">
                <i class="fas fa-exclamation-triangle me-1"></i>
                {{ error_message }}
            </div>
        </template>

        <template v-slot:footer>
            <!--
              Confirm button: visible only during the confirmation state.
              Triggers on_confirm(), which transitions to "loading" and
              emits the "confirm" event to the parent component.
            -->
            <button v-if="state == 'confirm'" type="button" @click="on_confirm"
                class="btn btn-primary">
                <i class="fas fa-save me-1"></i>
                {{ _i18n("save_settings") }}
            </button>

            <!--
              Close button: visible after a terminal state (success or error).
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
 * confirm: fired when the user confirms the save action. The parent is
 * responsible for performing the REST call and calling show_success()
 * or show_error() accordingly.
 */
const emit = defineEmits(["confirm"]);

/**
 * state: tracks the current phase of the modal workflow.
 * Possible values:
 *   - 'confirm'  → awaiting user confirmation
 *   - 'loading'  → save operation is in progress
 *   - 'success'  → operation completed successfully
 *   - 'error'    → operation failed
 */
const state = ref('confirm');

/** Holds the error message to display when the operation fails. */
const error_message = ref('');

/** Number of interfaces that were assigned the role. */
const updated_count = ref(0);

/** Template ref for the underlying <modal> component instance. */
const modal_id = ref(null);

/* ****************************************************** */

const showed = () => { };

const reset_state = () => {
    state.value = 'confirm';
    error_message.value = '';
    updated_count.value = 0;
};

const show = () => {
    reset_state();
    modal_id.value.show();
};

/**
 * Handles the user's confirmation click.
 * Transitions the modal to the "loading" state and emits the "confirm" event
 * so the parent component can execute the actual save operation.
 */
const on_confirm = () => {
    state.value = 'loading';
    emit('confirm');
};

/**
 * Transitions the modal to the "success" state with result stats.
 * Should be called by the parent after a successful operation.
 */
const show_success = (updated = 0) => {
    updated_count.value = updated ?? 0;
    state.value = 'success';
};

/**
 * Transitions the modal to the "error" state and sets the error message.
 * Should be called by the parent when the operation fails.
 */
const show_error = (message) => {
    error_message.value = message;
    state.value = 'error';
};

/**
 * Programmatically closes the modal dialog.
 */
const close = () => {
    modal_id.value.close();
};

/**
 * show(): open the modal in confirmation state
 * close(): close the modal
 * show_success(updated): transition to success state with the number of updated interfaces
 * show_error(message): transition to error state with a message
 */
defineExpose({ show, close, show_success, show_error });
</script>

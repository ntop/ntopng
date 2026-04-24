<!-- (C) 2013-26 - ntop.org -->
<template>
    <modal @showed="showed()" ref="modal_id">
        <template v-slot:title>{{ _i18n('delete') }} {{ policy_name }}</template>
        <template v-slot:body>
            <span v-html="body_text" />
        </template>
        <template v-slot:footer>
            <button type="button" @click="confirm_delete" class="btn btn-danger">
                {{ _i18n('delete') }}
            </button>
        </template>
    </modal>
</template>

<script setup>
import { ref } from "vue";
import { default as modal } from "./modal.vue";

const _i18n = (t) => i18n(t);
const modal_id   = ref(null);
const policy_name = ref("");
const body_text   = ref("");

const emit = defineEmits(['delete']);

const showed = () => {};

const show = (policy) => {
    policy_name.value = policy.name || "";
    body_text.value   = `Are you sure you want to delete policy <b>${policy.name}</b>? This action cannot be undone.`;
    modal_id.value.show();
};

const confirm_delete = () => {
    emit('delete');
    modal_id.value.close();
};

const close = () => modal_id.value.close();

defineExpose({ show, close });
</script>

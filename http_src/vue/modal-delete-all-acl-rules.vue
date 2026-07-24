<!-- (C) 2022 - ntop.org     -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>
            {{ _i18n("acl_page.delete_all_rules") }}
        </template>
        <template v-slot:body>
            {{ message }}
        </template><!-- modal-body -->
        <template v-slot:footer>
            <div v-if="show_feedback" class="me-auto w-100 text-danger" v-html="error"></div>
            <div v-if="show_feedback" class="mt-1 notes bg-danger me-auto w-100 bg-opacity-25" v-html="feedback">
            </div>
            <button type="button" @click="delete_host" class="btn btn-danger">{{ _i18n("delete") }}</button>
        </template>
    </modal>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const message = ref(i18n('acl_page.delete_all_confirmation'))
const emit = defineEmits(["delete_rules"]);
const show_feedback = ref(null)
const feedback = ref(null)
const props = defineProps({
    context: Object,
});

onMounted(() => { });

async function delete_host() {
    const url = `${http_prefix}/lua/pro/rest/v2/delete/system/access_control_list_all.lua`;
    const params = {
        csrf: props.context.csrf,
    };

    let headers = {
        'Content-Type': 'application/json'
    };
    const rsp = await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
    if (rsp.result == 'ok') {
        show_feedback.value = false;
        emit('delete_rules', params);
        close();
    } else {
        show_feedback.value = true;
        feedback.value = rsp.result;
    }
}

const show = () => {
    feedback.value = null;
    show_feedback.value = null;
    modal_id.value.show();
};

const close = () => {
    modal_id.value.close();
};

defineExpose({ show, close });

</script>

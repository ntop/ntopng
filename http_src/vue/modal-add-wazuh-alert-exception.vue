<!-- (C) 2026 - ntop.org -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>{{ title }}</template>
        <template v-slot:body>
            <form>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.rule_id') }}</b></label>
                    <div class="col-8">
                        <input ref="rule_id" class="form-control" type="number" min="0">
                        <small class="form-text text-muted">{{ _i18n('wazuh_alert_config.rule_id_hint') }}</small>
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.agent_name') }}</b></label>
                    <div class="col-8">
                        <input ref="agent_name" class="form-control" type="text"
                            :placeholder="_i18n('wazuh_alert_config.glob_placeholder')">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.src_ip') }}</b></label>
                    <div class="col-8">
                        <input ref="src_ip" class="form-control" type="text">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.dst_ip') }}</b></label>
                    <div class="col-8">
                        <input ref="dst_ip" class="form-control" type="text">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.username') }}</b></label>
                    <div class="col-8">
                        <input ref="username" class="form-control" type="text"
                            :placeholder="_i18n('wazuh_alert_config.glob_placeholder')">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.process') }}</b></label>
                    <div class="col-8">
                        <input ref="process_" class="form-control" type="text"
                            :placeholder="_i18n('wazuh_alert_config.glob_placeholder')">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.rule_group') }}</b></label>
                    <div class="col-8">
                        <input ref="rule_group" class="form-control" type="text"
                            :placeholder="_i18n('wazuh_alert_config.glob_placeholder')">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.enabled') }}</b></label>
                    <div class="col-8">
                        <div class="form-check form-switch">
                            <input ref="enabled" class="form-check-input" type="checkbox">
                        </div>
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('comment') }}</b></label>
                    <div class="col-8">
                        <textarea ref="comment" class="form-control" rows="2"></textarea>
                    </div>
                </div>
            </form>
        </template>
        <template v-slot:footer>
            <div v-if="show_feedback" class="me-auto w-100 text-danger">{{ feedback }}</div>
            <div>
                <Spinner :show="activate_add_spinner" size="1rem" class="me-2"></Spinner>
                <button :disabled="activate_add_spinner" type="button" @click="add_" class="btn btn-primary">{{
                    add_button_title }}</button>
            </div>
        </template>
    </modal>
</template>

<script setup>
import { ref } from "vue";
import { default as modal } from "./modal.vue";
import { default as Spinner } from "./spinner.vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { v4 as uuidv4 } from "uuid";

const _i18n = (t) => i18n(t);
const modal_id = ref(null);
const emit = defineEmits(['add']);

const props = defineProps({
    context: Object,
    url_request: String,
});

const rule_id = ref(null);
const agent_name = ref(null);
const src_ip = ref(null);
const dst_ip = ref(null);
const username = ref(null);
const process_ = ref(null);
const rule_group = ref(null);
const enabled = ref(null);
const comment = ref(null);

const row = ref(null);
const title = ref(i18n('wazuh_alert_config.add_exception'));
const add_button_title = ref(i18n('add'));
const show_feedback = ref(false);
const feedback = ref('');
const activate_add_spinner = ref(false);

/* ************************************** */

function reset_modal_form() {
    row.value = null;
    title.value = i18n('wazuh_alert_config.add_exception');
    add_button_title.value = i18n('add');
    show_feedback.value = false;
    rule_id.value.value = 0;
    agent_name.value.value = '';
    src_ip.value.value = '';
    dst_ip.value.value = '';
    username.value.value = '';
    process_.value.value = '';
    rule_group.value.value = '';
    enabled.value.checked = true;
    comment.value.value = '';
}

/* ************************************** */

function format_edit() {
    title.value = i18n('wazuh_alert_config.edit_exception');
    add_button_title.value = i18n('edit');

    rule_id.value.value = row.value.rule_id ?? 0;
    agent_name.value.value = row.value.agent_name ?? '';
    src_ip.value.value = row.value.src_ip ?? '';
    dst_ip.value.value = row.value.dst_ip ?? '';
    username.value.value = row.value.username ?? '';
    process_.value.value = row.value.process ?? '';
    rule_group.value.value = row.value.rule_group ?? '';
    enabled.value.checked = row.value.enabled !== 0;
    comment.value.value = row.value.comment ?? '';
}

/* ************************************** */

const show = (_row) => {
    reset_modal_form();
    if (_row) {
        row.value = _row;
        format_edit();
    }
    modal_id.value.show();
};

/* ************************************** */

const close = () => {
    modal_id.value.close();
};

/* ************************************** */

const add_ = async () => {
    activate_add_spinner.value = true;

    let params = {
        csrf: props.context.csrf,
        wazuh_exception_rule_id: rule_id.value.value,
        wazuh_exception_agent_name: agent_name.value.value,
        wazuh_exception_src_ip: src_ip.value.value,
        wazuh_exception_dst_ip: dst_ip.value.value,
        wazuh_exception_username: username.value.value,
        wazuh_exception_process: process_.value.value,
        wazuh_exception_rule_group: rule_group.value.value,
        wazuh_exception_enabled: enabled.value.checked ? 1 : 0,
        wazuh_exception_comment: comment.value.value,
    };

    let url = props.url_request.add;

    if (row.value) {
        url = props.url_request.edit;
        params.wazuh_exception_id = row.value.id;
    } else {
        params.wazuh_exception_id = uuidv4();
    }

    const rsp = await ntopng_utility.http_post_request(url, params);
    activate_add_spinner.value = false;

    if (rsp && rsp.result == 'ok') {
        show_feedback.value = false;
        emit('add');
        close();
    } else {
        show_feedback.value = true;
        feedback.value = (rsp && rsp.result) || i18n('request_failed_message');
    }
};

defineExpose({ show, close });
</script>

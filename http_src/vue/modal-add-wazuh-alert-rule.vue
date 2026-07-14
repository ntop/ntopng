<!-- (C) 2026 - ntop.org -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>{{ title }}</template>
        <template v-slot:body>
            <form>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.priority') }}</b></label>
                    <div class="col-8">
                        <input ref="priority" class="form-control" type="number" min="0">
                        <small class="form-text text-muted">{{ _i18n('wazuh_alert_config.priority_hint') }}</small>
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.min_level') }}</b></label>
                    <div class="col-8">
                        <input ref="min_level" class="form-control" type="number" min="0" max="16">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.groups') }}</b></label>
                    <div class="col-8">
                        <input ref="groups" class="form-control" type="text"
                            :placeholder="_i18n('wazuh_alert_config.groups_placeholder')">
                        <small class="form-text text-muted">
                            {{ _i18n('wazuh_alert_config.groups_hint') }}
                            <a href="https://documentation.wazuh.com/current/user-manual/ruleset/ruleset-xml-syntax/rules.html#group"
                                target="_blank" rel="noopener noreferrer">{{ _i18n('wazuh_alert_config.groups_docs_link') }}</a>
                        </small>
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.subject') }}</b></label>
                    <div class="col-8">
                        <input ref="subject" class="form-control" type="text">
                    </div>
                </div>
                <div class="form-group mb-3 row">
                    <label class="col-4 col-form-label"><b>{{ _i18n('wazuh_alert_config.immediate') }}</b></label>
                    <div class="col-8">
                        <div class="form-check form-switch">
                            <input ref="immediate" class="form-check-input" type="checkbox">
                        </div>
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
    url_request: Object,
});

const priority = ref(null);
const min_level = ref(null);
const groups = ref(null);
const subject = ref(null);
const immediate = ref(null);
const enabled = ref(null);
const comment = ref(null);

const row = ref(null);
const title = ref(i18n('wazuh_alert_config.add_rule'));
const add_button_title = ref(i18n('add'));
const show_feedback = ref(false);
const feedback = ref('');
const activate_add_spinner = ref(false);

/* ************************************** */

function reset_modal_form() {
    row.value = null;
    title.value = i18n('wazuh_alert_config.add_rule');
    add_button_title.value = i18n('add');
    show_feedback.value = false;
    priority.value.value = 100;
    min_level.value.value = 0;
    groups.value.value = '';
    subject.value.value = '[Wazuh] Alert digest';
    immediate.value.checked = false;
    enabled.value.checked = true;
    comment.value.value = '';
}

/* ************************************** */

function format_edit() {
    title.value = i18n('wazuh_alert_config.edit_rule');
    add_button_title.value = i18n('edit');

    priority.value.value = row.value.priority ?? 100;
    min_level.value.value = row.value.min_level ?? 0;
    groups.value.value = (row.value.groups || []).join(',');
    subject.value.value = row.value.subject ?? '';
    immediate.value.checked = !!row.value.immediate;
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
        wazuh_rule_priority: priority.value.value,
        wazuh_rule_min_level: min_level.value.value,
        wazuh_rule_groups: groups.value.value,
        wazuh_rule_subject: subject.value.value,
        wazuh_rule_immediate: immediate.value.checked ? 1 : 0,
        wazuh_rule_enabled: enabled.value.checked ? 1 : 0,
        wazuh_rule_comment: comment.value.value,
    };

    let url = props.url_request.add;

    if (row.value) {
        url = props.url_request.edit;
        params.wazuh_rule_id = row.value.id;
    } else {
        params.wazuh_rule_id = uuidv4();
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

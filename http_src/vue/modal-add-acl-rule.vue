<!-- (C) 2022 - ntop.org     -->
<template>
  <modal ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <form>
        <div class="row">
          <label class="col-form-label col-sm-3 pe-0" id="advanced-view">
            <b>{{ advanced_settings }}</b>
          </label>
          <div class="col-sm-2 ps-0">
            <div class="form-check form-switch mt-2" id="advanced-view">
              <input v-model="advanced_settings_enabled" name="show_advanced_settings" class="form-check-input"
                type="checkbox" role="switch">
            </div>
          </div>
        </div>
        <template v-if="advanced_settings_enabled">
          <div class="form-group ms-2 me-2 mt-2 row">
            <textarea rows="10" cols="10" style="width: 100%; height: 100%;" v-model="rules_to_add"></textarea>
          </div>
        </template>
        <template v-else>
          <template v-for="(single_rule, index) in new_rules_array">
            <div class="row mt-4">
              <div class="col-sm-2 pe-0 me-1">
                <SelectSearch v-model:selected_option="single_rule.selected_l4_proto" :options="props.l4_proto_list"
                  @select-option="change_arp(index)">
                </SelectSearch>
              </div>
              <template v-if="single_rule.selected_l4_proto.id !== 'arp'">
                <div class="col-sm-2 p-0 me-1">
                  <input v-model="single_rule.client" class="form-control" type="text"
                    :placeholder="client_ip_place_holder" required />
                </div>
                <div class="col-sm-2 p-0">
                  <input v-model="single_rule.server" class="form-control" type="text"
                    :placeholder="server_ip_place_holder" required />
                </div>
                <template v-if="single_rule.selected_l4_proto.id == 6 || single_rule.selected_l4_proto.id == 17">
                  <div v-if="single_rule.rule_application_type" class="col-sm-2 p-0 ms-1">
                    <SelectSearch v-model:selected_option="single_rule.selected_l7_proto"
                      :options="props.l7_proto_list">
                    </SelectSearch>
                  </div>
                  <div v-else class="col-sm-2 p-0 ms-1">
                    <input v-model="single_rule.port" class="form-control" type="text"
                      :placeholder="port_place_holder" />
                  </div>
                  <div class="btn-group m-auto align-items-center col-2" role="group">
                    <input :id="'use_port_' + index" class="btn-check btn-primary" type="radio"
                      @click="change_to_port_type(index)" />
                    <label :id="'use_port_label_' + index" class="btn btn-sm btn-primary" :for="'use_port_' + index">{{
                      _i18n('acl_page.use_port')
                      }}</label>
                    <input :id="'use_application_' + index" class="btn-check btn-primary" type="radio"
                      @click="change_to_app_type(index)" />
                    <label :id="'use_application_label_' + index" class="btn btn-sm btn-secondary"
                      :for="'use_application_' + index">{{
                        _i18n('acl_page.use_application') }}</label>
                  </div>
                </template>
              </template>
              <template v-else>
                <div class="col-sm-4 p-0 me-1">
                  <input v-model="single_rule.client" class="form-control" type="text"
                    :placeholder="client_mac_place_holder" required />
                </div>
              </template>
              <div class="col-sm-8 mt-2">
                <input v-model="single_rule.notes" class="form-control" type="text" :placeholder="notes_placeholder" />
              </div>
              <div v-if="index !== 0" class="col-sm-1 mt-2 me-4 ms-auto">
                <button class="btn btn-danger btn-sm" type="button" @click="remove_row(index)">
                  <i class="fas fa fa-trash" data-bs-toggle="tooltip" data-bs-placement="top"
                    :data-bs-original-title="_i18n('acl_page.remove_rule')"></i>
                </button>
              </div>
            </div>
          </template>
          <div class="row">
            <div class="mt-3 ps-0">
              <button class="btn btn-link" type="button" @click="add_row">
                <i class="fas fa-plus"></i>
              </button>
            </div>
          </div>
        </template>
      </form>
      <div class="form-group">
        <template v-if="!advanced_settings_enabled">
          <NoteList :note_list="note_list"></NoteList>
        </template>
        <template v-else>
          <NoteList v-if=advanced_settings_enabled :note_list="note_list_advanced_settings"></NoteList>
        </template>
      </div>
    </template>
    <template v-slot:footer>
      <div v-if="show_feedback" class="me-auto w-100 text-danger">{{ error }}</div>
      <div v-if="show_feedback" class="mt-1 notes bg-danger me-auto w-100 bg-opacity-25">
        {{ feedback }}
      </div>
      <div>
        <Spinner :show="activate_add_spinner" size="1rem" class="me-2"></Spinner>
        <button type="button" @click="add_" class="btn btn-primary" :disabled="disable_add">{{ _i18n('add') }}</button>
      </div>
    </template>
  </modal>
</template>

<script setup>
import { ref, onBeforeMount, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";
import { default as Spinner } from "./spinner.vue";
import dataUtils from "../utilities/data-utils"

const modal_id = ref(null);
const emit = defineEmits(['add']);
const _i18n = (t) => i18n(t);
const disable_add = ref(false)
const rules_to_add = ref('')
const advanced_settings_enabled = ref(false)
const advanced_settings = ref(i18n('acl_page.advanced_settings'))
const show_feedback = ref(false);
const activate_add_spinner = ref(false);
const feedback = ref('');
const error = ref(i18n('acl_page.error_detected'))
const title = ref(i18n('acl_page.add_acl_rule'));
const new_rules_array = ref([])
const client_ip_place_holder = ref(_i18n('db_search.tags.cli_ip'))
const client_mac_place_holder = ref(_i18n('db_search.tags.cli_mac'))
const server_ip_place_holder = ref(_i18n('db_search.tags.srv_ip'))
const notes_placeholder = ref(_i18n('acl_page.notes'))
const port_place_holder = ref(_i18n('port'))

const note_list_advanced_settings = [
  _i18n("acl_page.advanced_settings_one_rule_per_line"),
  _i18n("acl_page.advanced_settings_rule_format"),
  _i18n("acl_page.advanced_settings_l7_proto_port"),
  _i18n("acl_page.advanced_settings_select_one_parameter"),
  _i18n("acl_page.advanced_settings_parameters_separator"),
]

const note_list = [
  _i18n("acl_page.edit_acl_required"),
  _i18n("acl_page.edit_acl_notes"),
  _i18n("acl_page.edit_arp_only_client"),
  _i18n("acl_page.edit_arp_tcp_udp"),
  _i18n("acl_page.all_ports"),
  _i18n("acl_page.ports_range"),
  _i18n("acl_page.add_save"),
  _i18n("acl_page.add_rule_plus"),
  _i18n("acl_page.add_rule_arp"),
  _i18n("acl_page.add_rule_advanced_rules"),
]

/* ************************************** */

const props = defineProps({
  context: Object,
  url_request: String,
  l4_proto_list: Array,
  l7_proto_list: Array,
});


/* ************************************** */

function change_to_port_type(index) {
  new_rules_array.value[index].rule_port_type = true;
  new_rules_array.value[index].rule_application_type = false;

  const port_id = "use_port_label_" + index
  const app_id = "use_application_label_" + index

  $('#' + port_id).addClass('btn-primary')
  $('#' + port_id).removeClass('btn-secondary')

  $('#' + app_id).removeClass('btn-primary')
  $('#' + app_id).addClass('btn-secondary')
}

/* ************************************** */

function change_to_app_type(index) {
  new_rules_array.value[index].rule_port_type = false;
  new_rules_array.value[index].rule_application_type = true;
  new_rules_array.value[index].selected_l7_proto = props.l7_proto_list[0]

  const port_id = "use_port_label_" + index
  const app_id = "use_application_label_" + index

  $('#' + app_id).addClass('btn-primary')
  $('#' + app_id).removeClass('btn-secondary')

  $('#' + port_id).removeClass('btn-primary')
  $('#' + port_id).addClass('btn-secondary')
}

/* ************************************** */

function reset_modal_form() {
  activate_add_spinner.value = false;
  show_feedback.value = false;
  rules_to_add.value = '';
  feedback.value = '';
  new_rules_array.value = [{
    selected_l4_proto: props.l4_proto_list[1],
    selected_l7_proto: props.l7_proto_list[0],
    port: null,
    client: null,
    server: null,
    is_arp_proto: false,
    notes: null,
    rule_port_type: true,
    rule_application_type: false,
  }]
}

/* ************************************** */

function change_arp(index) {
  if (new_rules_array[index].selected_l4_proto.id == 'arp') {
    new_rules_array[index].is_arp_proto = true
  } else {
    new_rules_array[index].is_arp_proto = false
  }
}

/* ************************************** */

function remove_row(index) {
  new_rules_array.value = new_rules_array.value.filter((_, i) => i !== index)
}

/* ************************************** */

function add_row() {
  new_rules_array.value.push({
    selected_l4_proto: props.l4_proto_list[1],
    selected_l7_proto: props.l7_proto_list[0],
    port: null,
    client: null,
    server: null,
    is_arp_proto: false,
    notes: null,
    rule_port_type: true,
    rule_application_type: false,
  })
}

/* ************************************** */

const show = (row) => {
  reset_modal_form();
  modal_id.value.show();
};

/* ************************************** */

function calculate_rules_to_add() {
  if (advanced_settings_enabled.value) {
    return rules_to_add.value
  } else {
    let new_rules = ''
    new_rules_array.value.forEach((el, index) => {
      let new_single_rule = ''
      if (!dataUtils.isEmptyOrNull(el.selected_l4_proto)) {
        new_single_rule = new_single_rule + '' + el.selected_l4_proto.label
      }
      if (!dataUtils.isEmptyOrNull(el.client)) {
        new_single_rule = new_single_rule + ';' + el.client
      }
      if (!dataUtils.isEmptyOrNull(el.server) && !el.is_arp_proto) {
        new_single_rule = new_single_rule + ';' + el.server
      }
      if (!dataUtils.isEmptyOrNull(el.port) && el.rule_port_type && !el.is_arp_proto) {
        new_single_rule = new_single_rule + ';' + el.port
      }
      if (!dataUtils.isEmptyArrayOrNull(el.selected_l7_proto) && el.rule_application_type && !el.is_arp_proto) {
        new_single_rule = new_single_rule + ';' + el.selected_l7_proto.label
      }
      if (!dataUtils.isEmptyOrNull(el.notes)) {
        new_single_rule = new_single_rule + '#' + el.notes
      }
      new_rules = new_rules + new_single_rule + "\n"
    })
    new_rules = new_rules.slice(0, -1);
    return new_rules
  }
}

/* ************************************** */

const add_ = async () => {
  activate_add_spinner.value = true;
  const new_rules_to_add = calculate_rules_to_add()
  const params = {
    csrf: props.context.csrf,
    rules: new_rules_to_add
  }
  const rsp = await ntopng_utility.http_post_request(props.url_request, params);
  activate_add_spinner.value = false;
  if (rsp.result == 'ok') {
    show_feedback.value = false;
    emit('add', params);
    close();
  } else {
    show_feedback.value = true;
    feedback.value = rsp.result;
  }
};

/* ************************************** */

const close = () => {
  modal_id.value.close();
};

/* ************************************** */

onBeforeMount(() => { })

defineExpose({ show, close });


</script>

<style scoped></style>

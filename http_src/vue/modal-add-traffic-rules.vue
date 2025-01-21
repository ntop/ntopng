<!-- (C) 2022 - ntop.org     -->
<template>
  <modal @showed="showed()" ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>

      <div v-if="invalid_add" class="alert alert-info alert-dismissable">
        <span class="text-info me-1"></span>
        <span> {{ _i18n('rule_already_present') }}</span>
      </div>
      <!-- Target information, here an IP is put -->
      <div class="form-group ms-2 me-2 mt-3 row">

        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.add_rules_type") }}</b>
        </label>
        <div class="col-sm-10">
          <div class="btn-group btn-group-toggle" data-bs-toggle="buttons">
            <label class="btn " :class="[rule_type == 'Host' ? 'btn-primary active' : 'btn-secondary']">
              <input class="btn-check" type="radio" name="rule_type" value="hosts" @click="set_rule_type('Host')"> {{
                _i18n("if_stats_config.add_rules_type_host") }}
            </label>
            <label class="btn " :class="[rule_type == 'interface' ? 'btn-primary active' : 'btn-secondary']">
              <input @click="set_rule_type('interface')" class="btn-check" type="radio" name="rule_type"
                value="interface"> {{ _i18n("if_stats_config.add_rules_type_interface") }}
            </label>
            <label v-if="flow_device_timeseries_available == true" class="btn "
              :class="[rule_type == 'exporter' ? 'btn-primary active' : 'btn-secondary']">
              <input @click="set_rule_type('exporter')" class="btn-check" type="radio" name="rule_type" value="exporter">
              {{ _i18n("if_stats_config.add_rules_type_flow_exporter") }}
            </label>
            <label v-if="has_host_pools == true" class="btn "
              :class="[rule_type == 'host_pool' ? 'btn-primary active' : 'btn-secondary']">
              <input @click="set_rule_type('host_pool')" class="btn-check" type="radio" name="rule_type"
                value="host_pool"> {{ _i18n("if_stats_config.add_rules_type_host_pool") }}
            </label>
            <label v-if="has_cidr == true" class="btn "
              :class="[rule_type == 'CIDR' ? 'btn-primary active' : 'btn-secondary']">
              <input @click="set_rule_type('CIDR')" class="btn-check" type="radio" name="rule_type" value="CIDR"> {{
                _i18n("if_stats_config.add_rules_type_cidr") }}
            </label>
            <label v-if="props.has_vlans == true" class="btn "
              :class="[rule_type == 'vlan' ? 'btn-primary active' : 'btn-secondary']">
              <input @click="set_rule_type('vlan')" class="btn-check" type="radio" name="rule_type" value="vlan"> {{
                _i18n("if_stats_config.add_rules_type_vlans") }}
            </label>
            <label v-if="props.has_profiles == true" class="btn "
              :class="[rule_type == 'profiles' ? 'btn-primary active' : 'btn-secondary']">
              <input @click="set_rule_type('profiles')" class="btn-check" type="radio" name="rule_type" value="profiles"> {{
                _i18n("if_stats_config.add_rules_type_profiles") }}
            </label>
          </div>
        </div>
      </div>

      <div v-if="rule_type == 'Host'" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.target") }}</b>
        </label>
        <div class="col-sm-10">
          <input v-model="host" @input="check_empty_host" class="form-control" type="text" :placeholder="host_placeholder"
            required>
        </div>
      </div>

      <div v-if="rule_type == 'CIDR'" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.target") }}</b>
        </label>

        <div class="col-sm-10">
          <SelectSearch v-model:selected_option="selected_network" :options="network_list">
          </SelectSearch>
        </div>
      </div>

      <div v-if="rule_type == 'host_pool'" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.target") }}</b>
        </label>

        <div class="col-sm-10">
          <SelectSearch v-model:selected_option="selected_host_pool" :options="host_pool_list">
          </SelectSearch>
        </div>
      </div>
      <div v-if="rule_type == 'interface'" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.target_interface") }}</b>
        </label>
        <div class="col-10">

          <SelectSearch v-model:selected_option="selected_ifid" :options="ifid_list">
          </SelectSearch>
        </div>
      </div>

      <div v-if="rule_type == 'exporter' && flow_device_timeseries_available == true"
        class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.target_exporter_device") }}</b>
        </label>
        <div class="col-10">

          <SelectSearch v-model:selected_option="selected_exporter_device" :options="flow_exporter_devices"
            @select_option="change_exporter_interfaces">
          </SelectSearch>
        </div>

        <template v-if="selected_exporter_device.id != '*'">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.target_exporter_device_ifid") }}</b>
        </label>
        <div class="col-10">

          <SelectSearch v-model:selected_option="selected_exporter_device_ifid" :options="flow_exporter_device_ifid_list">
          </SelectSearch>
        </div>
      </template>
      </div>

      <div v-if="rule_type == 'vlan'" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.target_vlan") }}</b>
        </label>
        <div class="col-10">

          <SelectSearch v-model:selected_option="selected_vlan" :options="vlan_list">
          </SelectSearch>
        </div>
      </div>

      <!-- Traffic Profiles -->
      <div v-if="rule_type == 'profiles'" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.target_profile") }}</b>
        </label>
        <div class="col-10">
          <SelectSearch v-model:selected_option="selected_profile" :options="profiles_list">
          </SelectSearch>
        </div>
      </div>

      <!-- Metric information, here a metric is selected (e.g. DNS traffic) -->
      <div v-if="metrics_ready" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.metric") }}</b>
        </label>
        <template v-if="rule_type == 'Host'">
          <div class="col-10">
            <SelectSearch v-model:selected_option="selected_metric" @select_option="change_threshold()"
              :options="metric_list">
            </SelectSearch>
          </div>
        </template>
        <template v-else-if="rule_type == 'interface'">
          <div class="col-10">
            <SelectSearch v-model:selected_option="selected_interface_metric"
              @select_option="change_interface_threshold()" :options="interface_metric_list">
            </SelectSearch>
          </div>
        </template>
        <template v-else-if="rule_type == 'exporter'">
          <div class="col-10">
            <SelectSearch v-model:selected_option="selected_flow_device_metric"
              @select_option="change_metric_type_exporter" :options="flow_device_metric_list">
            </SelectSearch>
          </div>
        </template>
        <template v-else-if="rule_type == 'host_pool'">
          <div class="col-10">
            <SelectSearch v-model:selected_option="selected_host_pool_metric" @select_option="change_metric_type_hp()"
              :options="host_pool_metric_list">
            </SelectSearch>
          </div>
        </template>

        <template v-else-if="rule_type == 'CIDR'">
          <div class="col-10">
            <SelectSearch v-model:selected_option="selected_network_metric" @select_option="change_metric_type_hp()"
              :options="network_metric_list">
            </SelectSearch>
          </div>
        </template>
        <template v-else-if="rule_type == 'vlan'">
          <div class="col-10">
            <SelectSearch v-model:selected_option="selected_vlan_metric" 
              :options="vlan_metric_list" @select_option="change_vlan_threshold">
            </SelectSearch>
          </div>
        </template>
        <template v-else-if="rule_type == 'profiles'">
          <div class="col-10">
            <SelectSearch v-model:selected_option="selected_profile_metric" 
              :options="profiles_metric_list">
            </SelectSearch>
          </div>
        </template>
      </div>

      <!-- Frequency information, a frequency of 1 day, 5 minute or 1 hour for example -->
      <div v-if="metrics_ready" class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.frequency") }}</b>
        </label>
        <div class="col-10">
          <SelectSearch v-model:selected_option="selected_frequency" :options="frequency_list">
          </SelectSearch>
        </div>
      </div>

      <!-- Threshold information, maximum amount of bytes -->
      <div class="form-group ms-2 me-2 mt-3 row" style="margin-top:3px">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.threshold") }}</b>
        </label>
        <template v-if="visible">
          <div class="col-sm-3">
            <SelectSearch v-model:selected_option="metric_type" :options="active_metric_type_list">
            </SelectSearch>
          </div>
          <div class="col-3" :class="[metric_type.id == 'throughput' ? 'p-0' : '']">
            <div class="btn-group float-end btn-group-toggle" data-bs-toggle="buttons">
              <template v-if="metric_type.id == 'throughput'" v-for="measure in throughput_threshold_list">
                <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off"
                  ref="threshold_measure" name="threshold_measure">
                <label class="btn " :id="measure.id" @click="set_active_radio"
                  v-bind:class="[measure.active ? 'btn-primary active' : 'btn-secondary']" :for="measure.id">{{
                    measure.label }}</label>
              </template>
              <template v-if="metric_type.id == 'percentage'" v-for="measure in percentage_threshold_list">
                <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off"
                  ref="threshold_measure" name="threshold_measure">
                <label class="btn " :id="measure.id" @click="set_active_radio"
                  v-bind:class="[measure.active ? 'btn-primary active' : 'btn-secondary']" :for="measure.id">{{
                    measure.label }}</label>
              </template>
              <template v-if="metric_type.id == 'volume'" v-for="measure in volume_threshold_list">
                <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off"
                  ref="threshold_measure" name="threshold_measure">
                <label class="btn " :id="measure.id" @click="set_active_radio"
                  v-bind:class="[measure.active ? 'btn-primary active' : 'btn-secondary']" :for="measure.id">{{
                    measure.label }}</label>
              </template>
            </div>
          </div>


          <div class="col-sm-2 btn-group float-end btn-group-toggle" data-bs-toggle="buttons">
            <template v-for="measure in sign_threshold_list">
              <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off"
                ref="threshold_sign" name="threshold_sign">
              <label class="btn " :id="measure.id" @click="set_active_sign_radio"
                v-bind:class="[measure.active ? 'btn-primary active' : 'btn-secondary']" :for="measure.id">{{
                  measure.label }}</label>
            </template>
          </div>

        </template>

        <div :class="[visible ? 'col-sm-2' : 'col-sm-8']">
          <template v-if="metric_type.id == 'percentage'">
            <input value="1" ref="threshold" type="number" name="threshold" class="form-control" max="100" min="1"
              required>
          </template>
          <template v-else>
            <input value="1" ref="threshold" type="number" name="threshold" class="form-control" max="1023" min="1"
              required>
          </template>
        </div>
      </div>
      <template v-if="metric_type.id == 'percentage'">
        <div class="message alert alert-warning mt-3">
          {{ _i18n("show_alerts.traffic_rules_percentage") }}
        </div>
      </template>
    </template>
    <template v-slot:footer>
      <NoteList :note_list="note_list" :add_sub_notes="true" :sub_note_list="sub_notes_list">
      </NoteList>
      <template v-if="is_edit_page == false">
        <button type="button" @click="add_" class="btn btn-primary" :disabled="disable_add && rule_type == 'Host'">{{
          _i18n('add') }}</button>
      </template>
      <template v-else>
        <button type="button" @click="edit_" class="btn btn-primary" :disabled="disable_add && rule_type == 'Host'">{{
          _i18n('apply') }}</button>
      </template>
    </template>
  </modal>
</template>

<script setup>
import { ref, onBeforeMount } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";
import regexValidation from "../utilities/regex-validation.js";
import NtopUtils from "../utilities/ntop-utils.js";
import dataUtils from "../utilities/data-utils.js"
import { default as sortingFunctions } from "../utilities/sorting-utils.js";

const input_mac_list = ref("");
const input_trigger_alerts = ref("");


let has_host_pools = ref(false);
let has_cidr = ref(false);
const modal_id = ref(null);
const emit = defineEmits(['add', 'edit']);
let title = i18n('if_stats_config.add_traffic_rules_title');
const host_placeholder = i18n('if_stats_config.host_placeholder')

const metrics_ready = ref(false)
const _i18n = (t) => i18n(t);
const metric_list = ref([])
const init_func = ref(null);
const delete_row = ref(null);
const ifid_list = ref([])
const flow_exporter_devices = ref([])
const flow_exporter_device_ifid_list = ref([])
const interface_metric_list = ref([])
const host_pool_metric_list = ref([])
const flow_device_metric_list = ref([])
const frequency_list = ref([])
const threshold_measure = ref(null)
const threshold_sign = ref(null)
const selected_metric = ref({})
const selected_frequency = ref({})
const selected_ifid = ref({})
const selected_exporter_device = ref({})
const selected_exporter_device_ifid = ref({})
const selected_interface_metric = ref({})
const selected_host_pool_metric = ref({})
const selected_flow_device_metric = ref({})
const disable_add = ref(true)
const metric_type = ref({})
const visible = ref(true)
const rule_type = ref("hosts");
const flow_device_timeseries_available = ref(false);
const is_edit_page = ref(false)
const page_csrf_ = ref(null);
const row_to_edit_id = ref(null);
const invalid_add = ref(false);
const host_pool_list = ref(null);
const network_list = ref(null);
const selected_host_pool = ref({});
const selected_network = ref({});
const selected_network_metric = ref({});
const network_metric_list = ref(null);
const vlan_list = ref([]);
const selected_vlan = ref({});
const vlan_metric_list = ref(null);
const selected_vlan_metric = ref({});
const profiles_list = ref([]);
const selected_profile = ref({});
const profiles_metric_list = ref(null);
const selected_profile_metric = ref({});

let active_metric_type_list = ref([]);


const note_list = [
  _i18n('if_stats_config.note_1'),
  _i18n('if_stats_config.note_2'),
  _i18n('if_stats_config.note_3'),
  _i18n('if_stats_config.note_4'),
];

const sub_notes_list = [
  _i18n('if_stats_config.note_5')
];

const metric_type_list = ref([
  { title: _i18n('volume'), label: _i18n('volume'), id: 'volume', active: true },
  { title: _i18n('throughput'), label: _i18n('throughput'), id: 'throughput', active: false },
  { title: _i18n('percentage'), label: _i18n('percentage'), id: 'percentage', active: false },
])

/* Currently disabled the percentage */
const exporter_metric_type_list = ref([
  { title: _i18n('volume'), label: _i18n('volume'), id: 'volume', active: true },
  { title: _i18n('throughput'), label: _i18n('throughput'), id: 'throughput', active: false },
  { title: _i18n('percentage'), label: _i18n('percentage'), id: 'percentage', active: false },
])

const pool_metric_type_list = ref([
  { title: _i18n('volume'), label: _i18n('volume'), id: 'volume', active: true, measure_unit: 'bps' },
  { title: _i18n('throughput'), label: _i18n('throughput'), id: 'throughput', active: false, measure_unit: 'bps' },
  { title: _i18n('percentage'), label: _i18n('percentage'), id: 'percentage', active: false, measure_unit: 'number' },
  { title: _i18n('value'), label: _i18n('value'), id: 'value', active: false, measure_unit: 'number' }
])

const exporter_usage_type_list = ref([
  { title: _i18n('percentage'), label: _i18n('percentage'), id: 'absolute_percentage', active: false, measure_unit: 'number' },
])

const volume_threshold_list = ref([
  { title: _i18n('kb'), label: _i18n('kb'), id: 'kb', value: 1024, active: false },
  { title: _i18n('mb'), label: _i18n('mb'), id: 'mb', value: 1048576, active: false },
  { title: _i18n('gb'), label: _i18n('gb'), id: 'gb', value: 1073741824, active: true, default_active: true },
]);

const throughput_threshold_list = ref([
  { title: _i18n('kbps'), label: _i18n('kbps'), id: 'kbps', value: 1000, active: false },
  { title: _i18n('mbps'), label: _i18n('mbps'), id: 'mbps', value: 1000000, active: false },
  { title: _i18n('gbps'), label: _i18n('gbps'), id: 'gbps', value: 1000000000, active: true, default_active: true },
]);

const sign_threshold_list = ref([
  { title: "+", label: ">", id: 'plus', value: 1, active: false },
  { title: "-", label: "<", id: 'minus', value: -1, active: true, default_active: true },
]);

const percentage_threshold_list = [
  { title: "+", label: "%", id: 'plus', value: 1, active: true },
]

const host = ref(null)
const threshold = ref(null)

const showed = () => { };

const props = defineProps({
  metric_list: Array,
  ifid_list: Array,
  flow_exporter_devices: Array,
  interface_metric_list: Array,
  flow_device_metric_list: Array,
  frequency_list: Array,
  has_vlans: Boolean,
  has_profiles: Boolean,
  init_func: Function,
  page_csrf: String,
});

const rest_params = {
  csrf: props.page_csrf
}

function reset_radio_selection(radio_array) {

  radio_array.forEach((item) => item.active = item.default_active == true);
}

/**
 * 
 * Reset fields in modal form 
 */
const reset_modal_form = async function () {
  invalid_add.value = false;
  host.value = "";
  rule_type.value = "Host";
  selected_ifid.value = ifid_list.value[0];
  selected_metric.value = metric_list.value[0];
  selected_interface_metric.value = interface_metric_list.value[0];
  selected_flow_device_metric.value = flow_device_metric_list.value[0];

  is_edit_page.value = false;
  title = i18n('if_stats_config.add_traffic_rules_title');
  selected_frequency.value = frequency_list.value[0];
  metric_type.value = metric_type_list.value[0];
  selected_exporter_device.value = flow_exporter_devices.value[1];
  if (selected_exporter_device.value != null) {
    update_exporter_interfaces()
  }

  // reset metric_type_list
  metric_type_list.value.forEach((t) => t.active = false);
  metric_type_list.value[0].active = true;

  if (host_pool_list.value != null)
    selected_host_pool.value = host_pool_list.value[0];

  selected_host_pool_metric.value = host_pool_metric_list.value[0];

  if (network_list.value != null)
    selected_network.value = network_list.value[0];
  if (network_metric_list.value != null)
    selected_network_metric.value = network_metric_list.value[0];


  reset_radio_selection(volume_threshold_list.value);
  reset_radio_selection(throughput_threshold_list.value);
  reset_radio_selection(sign_threshold_list.value);

  rule_type.value = "Host";

  disable_add.value = true;

  threshold.value.value = 1;

  row_to_edit_id.value = null;

  active_metric_type_list.value = metric_type_list.value;

  if (rule_type == 'Host' || rule_type == 'interface') {
    metric_type.vale = metric_type_list.value[0];
  } else {
    metric_type.value = active_metric_type_list.value[0];
  }

  if (props.has_vlans) {
    selected_vlan.value = vlan_list.value[0];
    selected_vlan_metric.value = vlan_metric_list.value[0];
  }

}

const set_rule_type = (type) => {
  rule_type.value = type;

  active_metric_type_list.value = metric_type_list.value;

  if (type == "host_pool" || type == "CIDR") {
    change_metric_type_hp();

    if (type == "host_pool") {
      metric_type.value = active_metric_type_list.value[1];
    } else {
      metric_type.value = active_metric_type_list.value[0];
    }

    visible.value = true;

  } else {
    metric_type.value = metric_type_list.value[0];

    if (type == "Host") {
      change_threshold();
    } else if (type == "interface") {
      change_interface_threshold();
    } else if (type == "vlan") {
      change_vlan_threshold();
    } else {
      visible.value = true;
    }
    
  }
}


const change_metric_type_exporter = () => {
  let tmp_metric_type_list = [];
  if ((selected_flow_device_metric.value.id == "flowdev_port:usage")) {
    exporter_usage_type_list.value.forEach((item) => {
      if (item.measure_unit == 'number') {
        tmp_metric_type_list.push(item);
      }
    })
    active_metric_type_list.value = tmp_metric_type_list;
  } else {
    exporter_metric_type_list.value.forEach((item) => {
      if (item.id != 'value') {
        tmp_metric_type_list.push(item);
      }
    })
    active_metric_type_list.value = tmp_metric_type_list;
  }
  metric_type.value = active_metric_type_list.value[0];
}


const change_metric_type_hp = (set_active_one) => {
  let tmp_metric_type_list = [];
  if ((rule_type.value == "host_pool" && selected_host_pool_metric.value.measure_unit != "bps") || (rule_type.value == "CIDR" && selected_network_metric.value.measure_unit != "bps")) {

    pool_metric_type_list.value.forEach((item) => {
      if (item.measure_unit == 'number') {
        tmp_metric_type_list.push(item);
      }
    })

    active_metric_type_list.value = tmp_metric_type_list;

  } else {

    pool_metric_type_list.value.forEach((item) => {
      if (item.id != 'value') {
        tmp_metric_type_list.push(item);
      }
    })
    active_metric_type_list.value = tmp_metric_type_list;

  }
  if (set_active_one == null || set_active_one == false) {
    metric_type.value = active_metric_type_list.value[0];
  }

}


/**
 * 
 * Set row to edit 
 */
const set_row_to_edit = (row) => {

  if (row != null) {
    title = _i18n('if_stats_config.edit_traffic_rules_title');
    is_edit_page.value = true;

    row_to_edit_id.value = row.row_id;

    disable_add.value = false;

    // set threshold sign
    sign_threshold_list.value.forEach((t) => {
      t.active = (t.value == row.threshold_sign)
    })

    // set metric_type
    metric_type_list.value.forEach((t) => {
      if (t.id == row.metric_type) {
        t.active = true;
        metric_type.value = t;
      } else {
        t.active = false;
      }
    })

    active_metric_type_list.value = metric_type_list.value;

    // set threshold
    if (row.metric_type == 'volume')
      volume_threshold_list.value.forEach((t) => {
        if ((row.threshold % t.value) == 0) {
          let row_threshold_value = row.threshold / t.value;
          if (row_threshold_value < 1024) {
            t.active = true;
            threshold.value.value = row_threshold_value == 0 ? 1 : row_threshold_value;
          } else {
            t.active = false;
          }
        } else {
          t.active = false;
        }
      })
    else
      if (row.metric_type == 'throughput') {
        //row.threshold = row.threshold * 8;
        throughput_threshold_list.value.forEach((t) => {
          if ((row.threshold % t.value) == 0) {
            let row_threshold_value = row.threshold / t.value;
            if (row_threshold_value < 1000) {
              t.active = true;
              threshold.value.value = row_threshold_value == 0 ? 1 : row_threshold_value;
            } else {
              t.active = false;
            }
          } else {
            t.active = false;
          }
        })
      } else if (row.metric_type == 'percentage') {

        //percentage case
        threshold.value.value = row.threshold;
      } else if (row.metric_type == 'value' || row.metric_type == 'absolute_percentage') {
        threshold.value.value = row.threshold * (row.threshold_sign);
      }

    // set rule_type
    rule_type.value = row.rule_type;

    if (rule_type.value == 'interface') {

      // set ifid
      ifid_list.value.forEach((t) => {
        if (t.id == row.target)
          selected_ifid.value = t;
      })

      // set metric
      if (row.extra_metric != null) {
        interface_metric_list.value.forEach((t) => {
          if (t.id == row.metric && t.extra_metric == row.extra_metric) {
            selected_interface_metric.value = t;
          }
        })

      } else {
        interface_metric_list.value.forEach((t) => {
          if (t.id == row.metric) {
            selected_interface_metric.value = t;
          }
        })
      }
    } else if (rule_type.value == 'exporter') {
      flow_exporter_devices.value.forEach((item) => {
        if (item.id == row.target)
          selected_exporter_device.value = item
      })
      flow_exporter_device_ifid_list.value.forEach((item) => {
        if (item.id == row.flow_exp_ifid)
          selected_exporter_device_ifid.value = item
      })
    } else if (rule_type.value == 'Host') {

      //set host
      host.value = row.target;

      //set metric
      if (row.extra_metric != null) {

        metric_list.value.forEach((t) => {
          if (row.metric.contains(t.id) && t.extra_metric == row.extra_metric)
            selected_metric.value = t;
        })
      } else {
        metric_list.value.forEach((t) => {
          if (t.id == row.metric)
            selected_metric.value = t;
        })
      }
    } else if (rule_type.value == 'CIDR') {
      network_list.value.forEach((item) => {
        if (item.id == row.target) {
          selected_network.value = item;
        }
      })

      network_metric_list.value.forEach((item) => {
        if (item.label == row.metric_label) {
          selected_network_metric.value = item;
        }
      })

      change_metric_type_hp(true);

      active_metric_type_list.value.forEach((item) => {
        if (item.id == row.metric_type) {
          metric_type.value = item;
        }
      })


    } else if (rule_type.value == 'host_pool') {
      host_pool_list.value.forEach((item) => {
        if (item.id == row.target) {
          selected_host_pool.value = item;
        }
      })

      host_pool_metric_list.value.forEach((item) => {
        if (item.label == row.metric_label) {
          selected_host_pool_metric.value = item;
        }
      })
      change_metric_type_hp();

      active_metric_type_list.value.forEach((item) => {
        if (item.id == row.metric_type) {
          metric_type.value = item;
        }
      })

    } else if (rule_type.value == 'vlan') {
      selected_vlan.value = vlan_list.value.find((item) => item.id == row.target);
      
      vlan_metric_list.value.forEach((item) => {
        if(item.schema == row.metric) {
          selected_vlan_metric.value = item;
        }
      });

    } else if (rule_type.value == 'profiles') {
      selected_profile.value = profiles_list.value.find((item) => item.id == row.target);
      
      selected_profile_metric.value = profiles_metric_list.value.find((item) => 
        item.schema == row.metric
      );
    }
  }
}

const show = (row) => {
  if (row != null) {
    set_row_to_edit(row);
  } else {
    reset_modal_form();
  }


  modal_id.value.show();
};

const change_threshold = () => {
  (selected_metric.value.show_volume == true) ? visible.value = true : visible.value = false
}

const change_interface_threshold = () => {
  (selected_interface_metric.value.show_volume == true) ? visible.value = true : visible.value = false
}

const change_vlan_threshold = () => {
  (selected_vlan_metric.value.show_volume == true) ? visible.value = true : visible.value = false
}

const check_empty_host = () => {
  let regex = new RegExp(regexValidation.get_data_pattern('ip'));
  disable_add.value = !(regex.test(host.value) || host.value === '*');
}

const set_active_sign_radio = (selected_radio) => {
  const id = selected_radio.target.id;
  sign_threshold_list.value.forEach((measure) => {
    (measure.id === id) ? measure.active = true : measure.active = false;
  })

}

/**
 * 
 * Set the metric type
 */
const set_active_radio = (selected_radio) => {
  const id = selected_radio.target.id;

  if (metric_type.value.id == 'throughput') {
    throughput_threshold_list.value.forEach((measure) => {
      (measure.id === id) ? measure.active = true : measure.active = false;
    })
  } else if (metric_type.value.id == 'volume') {
    volume_threshold_list.value.forEach((measure) => {
      (measure.id === id) ? measure.active = true : measure.active = false;
    })
  } else if (metric_type.value.id == 'percentage') {
    percentage_threshold_list.forEach((measure) => {
      (measure.id === id) ? measure.active = true : measure.active = false;
    })
  }

}


/**
 * Function to add rule to rules list
 */
const add_ = (is_edit) => {
  let tmp_host = ''
  if (rule_type.value != 'interface')
    tmp_host = host.value;

  const tmp_frequency = selected_frequency.value.id;
  let tmp_metric = selected_metric.value.id;
  let tmp_metric_label = selected_metric.value.label;
 
  const tmp_rule_type = rule_type.value;

  let tmp_metric_type = metric_type.value.id;
  let tmp_extra_metric 
  let basic_value;
  let basic_sign_value;
  let tmp_threshold;
  let tmp_sign_value;

  let tmp_edit_row_id = (is_edit) ? row_to_edit_id.value : null;

  if (visible.value === false) {
    tmp_metric_type = ''
    tmp_extra_metric = ''
    tmp_threshold = threshold.value.value;
  }


  if (tmp_metric_type == 'throughput') {
    sign_threshold_list.value.forEach((measure) => { if (measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    throughput_threshold_list.value.forEach((measure) => { if (measure.active) basic_value = measure.value; })
    tmp_threshold = basic_value * parseInt(threshold.value.value);
    /* The throughput is in bit, the volume in Bytes!! */
  } else if (tmp_metric_type == 'volume') {
    sign_threshold_list.value.forEach((measure) => { if (measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    volume_threshold_list.value.forEach((measure) => { if (measure.active) basic_value = measure.value; })
    tmp_threshold = basic_value * parseInt(threshold.value.value);
  } else if (tmp_metric_type == 'percentage') {
    sign_threshold_list.value.forEach((measure) => { if (measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    tmp_threshold = parseInt(threshold.value.value);
  } else if (tmp_metric_type == 'value' || tmp_metric_type == 'absolute_percentage') {
    sign_threshold_list.value.forEach((measure) => { if (measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    tmp_threshold = tmp_sign_value * parseInt(threshold.value.value);
  }
  let emit_name = 'add';

  if (is_edit == true)
    emit_name = 'edit';


  if (rule_type.value == 'Host') {

    tmp_extra_metric = (selected_metric.value.extra_metric) ? selected_metric.value.extra_metric : null;

    emit(emit_name, {
      host: tmp_host,
      frequency: tmp_frequency,
      metric: tmp_metric,
      metric_label: tmp_metric_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      extra_metric: tmp_extra_metric,
      rule_type: tmp_rule_type,
      rule_threshold_sign: tmp_sign_value,
      rule_id: tmp_edit_row_id

    });
  } else if (rule_type.value == 'interface') {
    tmp_extra_metric = ((selected_interface_metric.value.extra_metric) ? selected_interface_metric.value.extra_metric : null)
    tmp_metric = selected_interface_metric.value.id
    tmp_metric_label = selected_interface_metric.value.label;
    const tmp_interface_metric = selected_interface_metric.value.id;
    const tmp_interface = selected_ifid.value.id;
    emit(emit_name, {
      frequency: tmp_frequency,
      metric: tmp_interface_metric,
      metric_label: tmp_metric_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      extra_metric: tmp_extra_metric,
      rule_type: tmp_rule_type,
      interface: tmp_interface,
      rule_threshold_sign: tmp_sign_value,
      rule_id: tmp_edit_row_id

    });
  } else if (rule_type.value == "exporter") {
    let flow_device_ifindex = selected_exporter_device_ifid.value.id;
    const flow_device_ifindex_name = selected_exporter_device_ifid.value.label;
    const flow_device_ip = selected_exporter_device.value.id;
    if (flow_device_ip == '*') 
      flow_device_ifindex = '*';
    const ifid = selected_exporter_device.value.ifid;
    let metric_exp;

    if (!selected_flow_device_metric.value.id) {
      metric_exp = flow_device_metric_list.value.find((item) => item.id === null);
      /* In case no metric id is found, it means it's the traffic one */
      if (flow_device_ifindex != null && flow_device_ifindex != '*') {
        metric_exp = selected_flow_device_metric.value;
        metric_exp.id = "flowdev_port:traffic";
      }
      else {
        metric_exp = selected_flow_device_metric.value;
        metric_exp.id = "flowdev:traffic";
      }
    } else {
      metric_exp = flow_device_metric_list.value.find((item) => item.id == selected_flow_device_metric.value.id)
    }


    let metric_exp_label = metric_exp.label;

    emit(emit_name, {
      host: flow_device_ip,
      frequency: tmp_frequency,
      metric: metric_exp.id,
      metric_label: metric_exp_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      rule_type: tmp_rule_type,
      interface: flow_device_ifindex,
      rule_ifid: ifid,
      rule_threshold_sign: tmp_sign_value,
      rule_id: tmp_edit_row_id
      
    });
  } else if (rule_type.value == "CIDR") {

    tmp_metric = selected_network_metric.value.schema;
    tmp_metric_label = selected_network_metric.value.label;
    tmp_host = selected_network.value.id;
    const network_id = selected_network.value.network_id;
    emit(emit_name, {
      host: tmp_host,
      frequency: tmp_frequency,
      metric: tmp_metric,
      metric_label: tmp_metric_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      extra_metric: tmp_extra_metric,
      rule_type: tmp_rule_type,
      rule_threshold_sign: tmp_sign_value,
      rule_id: tmp_edit_row_id,
      network: network_id

    });
  } else if (rule_type.value == "host_pool") {

    tmp_metric = selected_host_pool_metric.value.schema;
    tmp_metric_label = selected_host_pool_metric.value.label;
    const tmp_host_pool_id = selected_host_pool.value.id;
    const tmp_host_pool_label = selected_host_pool.value.label;

    emit(emit_name, {
      host_pool_id: tmp_host_pool_id,
      host_pool_label: tmp_host_pool_label,
      frequency: tmp_frequency,
      metric: tmp_metric,
      metric_label: tmp_metric_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      extra_metric: tmp_extra_metric,
      rule_type: tmp_rule_type,
      rule_threshold_sign: tmp_sign_value,
      rule_id: tmp_edit_row_id

    });

  } else if (rule_type.value == "vlan") {

    tmp_metric = selected_vlan_metric.value.schema;
    tmp_metric_label = selected_vlan_metric.value.label;
    const tmp_vlan_id = selected_vlan.value.id;
    const tmp_vlan_label = selected_vlan.value.label;

    emit(emit_name, {
      vlan_id: tmp_vlan_id,
      vlan_label: tmp_vlan_label,
      frequency: tmp_frequency,
      metric: tmp_metric,
      metric_label: tmp_metric_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      extra_metric: tmp_extra_metric,
      rule_type: tmp_rule_type,
      rule_threshold_sign: tmp_sign_value,
      rule_id: tmp_edit_row_id

    });
  } else if (rule_type.value == "profiles") {

    tmp_metric = selected_profile_metric.value.schema;
    tmp_metric_label = selected_profile_metric.value.label;
    const tmp_profile = selected_profile.value.id;

    emit(emit_name, {
      profile: tmp_profile,
      frequency: tmp_frequency,
      metric: tmp_metric,
      metric_label: tmp_metric_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      extra_metric: tmp_extra_metric,
      rule_type: tmp_rule_type,
      rule_threshold_sign: tmp_sign_value,
      rule_id: tmp_edit_row_id
    });
  }

};


const edit_ = () => {
  add_(true);
}

const close = () => {
  is_edit_page.value = false;
  invalid_add.value = false;
  modal_id.value.close();
};

const invalidAdd = () => {
  invalid_add.value = true;
};

const compare_labels = function (a,b) {
  let x = a.label.toLowerCase();
  let y = b.label.toLowerCase();

  if (x < y) { return -1; }
  if (x > y) { return 1; }
  return 0;
}

/**
 * 
 * Function to format ifid list
 */
const format_ifid_list = function (data) {
  let _ifid_list = []
  data.forEach((ifid) => {
    let item = { id: ifid.ifid, label: ifid.name };
    _ifid_list.push(item);
  })
  _ifid_list.sort((a, b) => compare_labels(a,b));
  return _ifid_list
}

const metricsLoaded = async (_metric_list, _ifid_list, _interface_metric_list, _flow_exporter_devices, _flow_exporter_devices_metric_list, 
                             page_csrf, _init_func, _delete_row, _host_pool_list, _network_list, _host_pool_metric_list, _network_metric_list, 
                             _vlan_list, _vlan_metric_list, _profiles_list, _profiles_metric_list) => {
  metrics_ready.value = true;
  metric_list.value = _metric_list;
  interface_metric_list.value = _interface_metric_list;
  ifid_list.value = format_ifid_list(_ifid_list);

  frequency_list.value = props.frequency_list;
  selected_frequency.value = frequency_list.value[0];
  selected_metric.value = metric_list.value[0];
  selected_ifid.value = ifid_list.value[0];
  page_csrf_.value = page_csrf;
  if (_init_func) {
    init_func.value = _init_func;
  }

  if (_delete_row) {
    delete_row.value = _delete_row;
  }

  flow_exporter_devices.value = format_flow_exporter_device_list(_flow_exporter_devices);
  
  if (!dataUtils.isEmptyArrayOrNull(_host_pool_list)) {
    has_host_pools.value = true;
  }
  host_pool_list.value = _host_pool_list;
  host_pool_metric_list.value = _host_pool_metric_list;

  if (!dataUtils.isEmptyArrayOrNull(_network_list)) {
    has_cidr.value = true;
  }
  network_list.value = _network_list;
  network_metric_list.value = _network_metric_list;
  flow_device_metric_list.value = _flow_exporter_devices_metric_list;

  selected_exporter_device.value = flow_exporter_devices.value[1];
  if (selected_exporter_device.value != null) {
    update_exporter_interfaces()
  }
  if (props.has_vlans) {
    vlan_list.value = format_vlan_list(_vlan_list);
    selected_vlan.value = vlan_list.value[0];
    vlan_metric_list.value = _vlan_metric_list;
    selected_vlan_metric.value = vlan_metric_list.value[1];
  }
  if (props.has_profiles) {
    profiles_list.value = format_profile_list(_profiles_list);
    selected_profile.value = profiles_list.value[0];
    profiles_metric_list.value = _profiles_metric_list;
    selected_profile_metric.value = profiles_metric_list.value[0];
  }
}

/* *************************************************** */

/* This function updates the exporter interfaces list, 
 * by requesting to the back end the list of interfaces for the selected exporter 
 */
async function update_exporter_interfaces() {
  let interfaces_list = [];
  if (selected_exporter_device.value.id == '*') {
    return;
  }

  const url_device_exporter_details =
    NtopUtils.buildURL(`${http_prefix}/lua/pro/rest/v2/get/flowdevice/stats.lua?exporter_uuid=${selected_exporter_device.value.id}&ifid=${selected_exporter_device.value.ifid}&ip=${selected_exporter_device.value.ip}`);

  await $.get(url_device_exporter_details, function (response, status) {
    interfaces_list = response.rsp;
  });

  const exporter_interfaces = [
    { id: "*", value: "*", label: "*", timeseries_available: interfaces_list[0]?.timeseries_available }
  ];

  interfaces_list.forEach((rsp) => {
    exporter_interfaces.push({ id: rsp.ifindex, label: rsp.snmp_ifname, timeseries_available: rsp.timeseries_available });
  })
  flow_exporter_device_ifid_list.value = exporter_interfaces;
  selected_exporter_device_ifid.value = flow_exporter_device_ifid_list.value[1];
}

/* *************************************************** */


/**
 * Function to format flow exporter device list 
 */
const format_flow_exporter_device_list = function (data) {
  const _f_exp_dev_list = [
    { id: "*", value: "*", label: "*" }
  ];

  data.forEach((dev) => {
    const unique_source_id = dev.unique_source_id;
    _f_exp_dev_list.push({
      id: unique_source_id,
      label: dev.name,
      ip: dev.ip,
      value: unique_source_id,
      ifid: dev.ifid
    });
  })
  
  _f_exp_dev_list.sort((a, b) => sortingFunctions.sortByIP(
    a.label,
    b.label,
    1 /* by default asc */
  ));
  return _f_exp_dev_list;
}

/**
 * Function to format vlan list 
 */
const format_vlan_list = function(data) {
  const f_vlan_list = [];
  data.forEach((vlan) => {
    if (vlan.key != 0) {
      let vlan_label = vlan.key;
      let tag_splitted = vlan.column_vlan.split(">")
      let graphs_splitterd = tag_splitted[1].split("[");
      if (graphs_splitterd.length > 1) {
        vlan_label = tag_splitted[1].split("<")[0];
      }
      f_vlan_list.push({
        id: vlan.key,
        label: vlan_label,
        value: vlan.key,
      })
    }
    
  });

  f_vlan_list.sort((a, b) => sortingFunctions.sortByName(
    a.label,
    b.label,
    1 /* by default asc */
  ));
  return f_vlan_list;
}

/**
 * Function to format profile list 
 */
const format_profile_list = function(data) {
  const f_profile_list = [];
  data.forEach((profile) => {
    if (profile.column_profile != "") {
      f_profile_list.push({
        id: profile.column_profile,
        label: profile.column_profile,
        value: profile.column_profile,
      })
    }
    
  });

  f_profile_list.sort((a, b) => sortingFunctions.sortByName(
    a.id,
    b.id,
    1 /* by default asc */
  ));
  return f_profile_list;
}

/* *************************************************** */

/* This function is automatically called whenever a different exporter is selected
 * in order to update the interfaces select dropdown
 */
const change_exporter_interfaces = function () {
  update_exporter_interfaces();
}

/* *************************************************** */

onBeforeMount(async() => {
  metric_type_list.value.forEach((t) => {
    if (t.active) {
      metric_type.value = t;
    }

  })
  invalid_add.value = false;
  await $.get(http_prefix + '/lua/pro/rest/v2/get/flowdevice/timeseries_enabled.lua', function (rsp, status) {
    flow_device_timeseries_available.value = rsp.rsp
  });
})

defineExpose({ show, close, metricsLoaded, invalidAdd });


</script>

<style scoped></style>

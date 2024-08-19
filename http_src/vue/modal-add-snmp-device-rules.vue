<!-- (C) 2022 - ntop.org     -->
<template>
  <modal @showed="showed()" ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <!-- Target information, here an IP is put -->


      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.snmp_device") }}</b>
        </label>
        <div class="col-10">

          <SelectSearch v-model:selected_option="selected_snmp_device" @select_option="change_interfaces()"
            :options="snmp_devices_list">
          </SelectSearch>
        </div>
      </div>

      <template v-if="enable_interfaces == true">
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-2">
            <b>{{ _i18n("if_stats_config.snmp_interface") }}</b>
          </label>
          <div class="col-10">

            <SelectSearch v-model:selected_option="selected_snmp_interface" :options="snmp_interfaces_list">
            </SelectSearch>
          </div>
        </div>
      </template>

      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-2">
          <b>{{ _i18n("if_stats_config.metric") }}</b>
        </label>
        <div class="col-10">
          <SelectSearch v-model:selected_option="selected_snmp_device_metric" @select_option="change_active_threshold()"
            :options="snmp_metric_list">
          </SelectSearch>
        </div>
      </div>

      <!-- Frequency information, a frequency of 1 day, 5 minute or 1 hour for example -->
      <div class="form-group ms-2 me-2 mt-3 row">
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
          <template v-if="metric_type.id == 'percentage_change' || metric_type.id == 'percentage_absolute'">

            <div class="col-sm-4">
              <SelectSearch v-model:selected_option="metric_type" :options="metric_type_active_list">
              </SelectSearch>
            </div>
          </template>
          <template v-else>

            <div class="col-sm-3">
              <SelectSearch v-model:selected_option="metric_type" :options="metric_type_active_list">
              </SelectSearch>
            </div>
          </template>

          <template v-if="metric_type.id == 'throughput' && metric_type.id != 'packets'">
            <div class="col-3" :class="[metric_type.id == 'throughput' ? 'p-0' : '']">
              <div class="btn-group float-end btn-group-toggle" data-bs-toggle="buttons">

                <template v-for="measure in throughput_threshold_list">
                  <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off"
                    ref="threshold_measure" name="threshold_measure">
                  <label class="btn " :id="measure.id" @click="set_active_radio"
                    v-bind:class="[measure.active ? 'btn-primary active' : 'btn-secondary']" :for="measure.id">{{
                      measure.label }}</label>
                </template>

              </div>
            </div>
          </template>
          <template
            v-if="(metric_type.id == 'percentage_change' || metric_type.id == 'percentage_absolute') && metric_type.id != 'packets'">
            <div class="col-2" :class="[metric_type.id == 'throughput' ? 'p-0' : '']">
              <div class="btn-group float-end btn-group-toggle" data-bs-toggle="buttons"
                :hidden="metric_type.id == 'percentage_absolute'">

                <template v-for="measure in percentage_threshold_list">
                  <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off"
                    ref="threshold_measure" name="threshold_measure">
                  <label class="btn " :id="measure.id" @click="set_active_radio"
                    v-bind:class="[measure.active ? 'btn-primary active' : 'btn-secondary']" :for="measure.id">{{
                      measure.label }}</label>
                </template>

              </div>
            </div>
          </template>

          <template v-if="metric_type.id == 'volume' && metric_type.id != 'packets'">
            <div class="col-3" :class="[metric_type.id == 'throughput' ? 'p-0' : '']">
              <div class="btn-group float-end btn-group-toggle" data-bs-toggle="buttons">

                <template v-for="measure in volume_threshold_list">
                  <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off"
                    ref="threshold_measure" name="threshold_measure">
                  <label class="btn " :id="measure.id" @click="set_active_radio"
                    v-bind:class="[measure.active ? 'btn-primary active' : 'btn-secondary']" :for="measure.id">{{
                      measure.label }}</label>
                </template>

              </div>
            </div>
          </template>



          <template v-if="metric_type.id != 'packets'">
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
          <template v-else>
            <div class="col-sm-2 btn-group float-end btn-group-toggle" data-bs-toggle="buttons">
              <template v-for="measure in sign_absolute_value">
                <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off"
                  ref="threshold_sign" name="threshold_sign">
                <label class="btn " :id="measure.id"
                  v-bind:class="[measure.absolute_value ? 'btn-primary active' : 'btn-secondary']" :for="measure.id">{{
                    measure.label }}</label>
              </template>
            </div>
          </template>


        </template>

        <div :class="[visible ? 'col-sm-2' : 'col-sm-8']">
          <template v-if="metric_type.id == 'percentage_change' || metric_type.id == 'percentage_absolute'">
            <input value="1" ref="threshold" type="number" name="threshold" class="form-control" max="100" min="1"
              required>
          </template>
          <template v-else>
            <input value="1" ref="threshold" type="number" name="threshold" class="form-control" max="1023" min="1"
              required>
          </template>
        </div>
      </div>
      <template v-if="selected_snmp_device_metric.id != 'usage' && metric_type.id == 'percentage_change'">
        <div class="message alert alert-warning mt-3">
          {{ _i18n("show_alerts.host_rules_percentage") }}
        </div>
      </template>
      <template v-if="metric_type.id == 'percentage_absolute'">
        <div class="message alert alert-info mt-3">
          {{ _i18n("show_alerts.host_rules_percentage_absolute") }}
        </div>
      </template>
    </template>
    <template v-slot:footer>
      <NoteList :note_list="note_list" :add_sub_notes="true" :sub_note_list="sub_notes_list">
      </NoteList>
      <template v-if="is_edit_page == false">
        <button type="button" @click="add_" class="btn btn-primary">{{ _i18n('add') }}</button>
      </template>
      <template v-else>
        <button type="button" @click="edit_" class="btn btn-primary">{{ _i18n('apply') }}</button>
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
import NtopUtils from "../utilities/ntop-utils";

const input_mac_list = ref("");
const input_trigger_alerts = ref("");

const modal_id = ref(null);
const emit = defineEmits(['add', 'edit']);
const _i18n = (t) => i18n(t);
const init_func = ref(null);
const delete_row = ref(null);
const snmp_metric_list = ref([])
const snmp_devices_list = ref([])
let snmp_interfaces_list = ref([])
let enable_interfaces = ref(true);
const snmp_interfaces_url = `${http_prefix}/lua/pro/rest/v2/get/snmp/device/available_interfaces.lua`

const frequency_list = ref([])
const threshold_measure = ref(null)
const threshold_sign = ref(null)
const selected_metric = ref({})
const selected_snmp_device = ref({})
const selected_snmp_interface = ref({})

const selected_snmp_device_metric = ref({})
const selected_frequency = ref({})
const disable_add = ref(true)
const metric_type = ref({})
const visible = ref(true)
const rule_type = ref("snmp");
const is_edit_page = ref(false)
const page_csrf_ = ref(null);
let metric_type_active_list = ref([]);

let title = _i18n('if_stats_config.add_host_rules_title');


const note_list = [
  _i18n('if_stats_config.note_snmp_device_rules.note_1'),
  _i18n('if_stats_config.note_snmp_device_rules.note_2'),
  _i18n('if_stats_config.note_snmp_device_rules.note_3'),
  _i18n('if_stats_config.note_3'),
  _i18n('if_stats_config.note_4')
]

const sub_notes_list = [
  _i18n('if_stats_config.note_5'),
  _i18n('if_stats_config.note_6')
];

const metric_type_list = ref([
  { title: _i18n('volume'), label: _i18n('volume'), id: 'volume', active: true },
  { title: _i18n('throughput'), label: _i18n('throughput'), id: 'throughput', active: false },
  { title: _i18n('packets'), label: _i18n('packets'), id: 'packets', active: false },
  { title: _i18n('percentage_change'), label: _i18n('percentage_change'), id: 'percentage_change', active: false },
  { title: _i18n('percentage_absolute'), label: _i18n('percentage_absolute'), id: 'percentage_absolute', active: false }

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
  { title: "+", label: ">", id: 'plus', value: 1, active: false, absolute_value: true },
  { title: "-", label: "<", id: 'minus', value: -1, active: true, default_active: true },
]);

const sign_absolute_value = ref([
  { title: "+", label: ">", id: 'plus', value: 1, active: true, absolute_value: true },
]);

const percentage_threshold_list = [
  { title: "+", label: "%", id: 'plus', value: 1, active: true },
]


const host = ref(null)
const threshold = ref(null)

const showed = () => { };

const props = defineProps({
  ifid_list: Array,
  snmp_devices_list: Array,
  snmp_metric_list: Array,
  frequency_list: Array,
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

  host.value = "";
  selected_metric.value = snmp_metric_list.value[0];
  selected_snmp_device.value = null;
  selected_snmp_device.value = snmp_devices_list.value[0];
  change_interfaces();

  selected_snmp_device_metric.value = snmp_metric_list.value[0];
  change_active_threshold()

  selected_frequency.value = frequency_list.value[0];
  metric_type.value = metric_type_list.value[0];

  // reset metric_type_list
  metric_type_list.value.forEach((t) => t.active = false);
  metric_type_list.value[0].active = true;

  reset_radio_selection(volume_threshold_list.value);
  reset_radio_selection(throughput_threshold_list.value);
  reset_radio_selection(sign_threshold_list.value);

  rule_type.value = "snmp";

  disable_add.value = true;
  enable_interfaces.value = false;

  threshold.value.value = 1;
  is_edit_page.value = false;
  title = _i18n('if_stats_config.add_host_rules_title');

}




/**
 * 
 * Set row to edit 
 */
const set_row_to_edit = (row) => {
  if (row != null) {
    is_edit_page.value = true;
    title = _i18n('if_stats_config.edit_host_rules_title');

    disable_add.value = false;

    snmp_devices_list.value.forEach((item) => {
      if (item.label_to_insert == row.device.id)
        selected_snmp_device.value = item;
    })

    // set threshold sign
    sign_threshold_list.value.forEach((t) => {
      t.active = (t.value == row.threshold.sign)
    })

    snmp_metric_list.value.forEach((t) => {
      if (t.id == row.metric.id)
        selected_snmp_device_metric.value = t;
    })

    // set threshold
    if (row.metric.type == 'volume')
      volume_threshold_list.value.forEach((t) => {
        if ((row.threshold.value % t.value) == 0) {
          let row_threshold_value = row.threshold.value / t.value;
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
    else if (row.metric.type == 'throughput') {
      row.threshold.value = row.threshold.value * 8;
      throughput_threshold_list.value.forEach((t) => {
        if ((row.threshold % t.value) == 0) {
          let row_threshold_value = row.threshold.value / t.value;
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
    } else {

      //percentage case
      threshold.value.value = row.threshold.value * row.threshold.sign;

    }
    change_active_threshold();
    metric_type_active_list.value.forEach((item) => {
      if (item.id == row.metric.type) {
        metric_type.value = item;
        item.active = true;
      } else
        item.active = false;
    })

    snmp_devices_list.value.forEach((t) => {
      if (t.label == row.device.id)
        selected_snmp_device.value = t;
    })

    frequency_list.value.forEach((item) => {
      if (item.id == row.frequency)
        selected_frequency.value = item;
    });

    change_interfaces(row.interface.id);

  }
}

const show = (row) => {
  if (row != null) {
    set_row_to_edit(row.row);
  } else {
    reset_modal_form();
  }
  modal_id.value.show();
};


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
  } else if (metric_type.value.id == 'percentage_change' || metric_type.value.id == 'percentage_absolute') {
    percentage_threshold_list.forEach((measure) => {
      (measure.id === id) ? measure.active = true : measure.active = false;
    })
  } else if (metric_type.value.id == 'packets') {

  }

}


async function change_interfaces(interface_id) {
  const url = NtopUtils.buildURL(snmp_interfaces_url + "?host=" + selected_snmp_device.value.label_to_insert, rest_params)
  let interfaces_list = []
  await $.get(url, function (rsp, status) {
    interfaces_list = rsp.rsp;
  });
  let result_interfaces = []

  interfaces_list.forEach(iface => {
    if (iface.name != null && iface.name != "" && iface.name != iface.id)
      result_interfaces.push({ label: iface.name + " (" + iface.id + ")", id: iface.id, name: iface.name })
    else
      result_interfaces.push({ label: iface.id, id: iface.id, name: iface.id })
  })
  result_interfaces.push({ label: "*", id: "*", name: "*" })
  result_interfaces.sort(function (a, b) { return (a.label.toLowerCase() > b.label.toLowerCase() ? 1 : (a.label.toLowerCase() < b.label.toLowerCase()) ? -1 : 0); });

  if (interface_id != null)
    result_interfaces.forEach((t) => {
      if (t.id == interface_id)
        selected_snmp_interface.value = t;
    })
  snmp_interfaces_list.value = result_interfaces;
  // debugger;
  if (selected_snmp_device.value.label_to_insert == "all")
    enable_interfaces.value = false;
  else
    enable_interfaces.value = true;

}

function change_active_threshold() {
  let list_metrics_active = [];
  let list_sign_active = []
  if (selected_snmp_device_metric.value.id == 'packets' || selected_snmp_device_metric.value.id == 'usage') {
    metric_type_list.value.forEach((t) => {
      if (t.id != 'percentage_absolute')
        t.active = false;
      else {
        t.active = true;
        list_metrics_active.push(t);
        metric_type.value = t;
      }
    })
  } else if (selected_snmp_device_metric.value.id == 'errors') {
    metric_type_list.value.forEach((t) => {
      if (t.id != 'packets')
        t.active = false;
      else {
        t.active = true;
        list_metrics_active.push(t);
        metric_type.value = t;
      }
    })

  } else {
    metric_type_list.value.forEach((t) => {
      if (t.id == 'packets')
        t.active = false;
      else {
        list_metrics_active.push(t);
      }
    })
  }


  metric_type_active_list.value = list_metrics_active;
}



/**
 * Function to add rule to rules list
 */
const add_ = (is_edit) => {
  let tmp_host = ''
  rule_type.value = 'snmp';
  tmp_host = host.value;

  const tmp_frequency = selected_frequency.value.id;
  const tmp_metric = selected_snmp_device_metric.value.id;
  const tmp_metric_label = selected_snmp_device_metric.value.label;
  const tmp_device = selected_snmp_device.value.label_to_insert;
  const tmp_device_label = selected_snmp_device.value.label;
  const tmp_device_ifid = selected_snmp_interface.value == null || Object.entries(selected_snmp_interface.value).length === 0 || tmp_device_label === "*" ? "*" : selected_snmp_interface.value.id;
  const tmp_device_ifid_label = selected_snmp_interface.value == null || Object.entries(selected_snmp_interface.value).length === 0 || tmp_device_label === "*" ? "*" : selected_snmp_interface.value.label;

  let tmp_metric_type = metric_type.value.id;
  let basic_value;
  let measure_unit_label;
  let basic_sign_value;
  let tmp_threshold;
  let tmp_sign_value;

  if (visible.value === false) {
    tmp_metric_type = ''
    tmp_extra_metric = ''
    tmp_threshold = threshold.value.value;
  }
  if (tmp_metric_type == 'throughput') {

    sign_threshold_list.value.forEach((measure) => { if (measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    throughput_threshold_list.value.forEach((measure) => { if (measure.active) { basic_value = measure.value; measure_unit_label = measure.label; } })
    tmp_threshold = basic_value * parseInt(threshold.value.value) / 8;
    /* The throughput is in bit, the volume in Bytes!! */
  } else if (tmp_metric_type == 'volume') {
    sign_threshold_list.value.forEach((measure) => { if (measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    volume_threshold_list.value.forEach((measure) => { if (measure.active) { basic_value = measure.value; measure_unit_label = measure.label; } })
    tmp_threshold = basic_value * parseInt(threshold.value.value);
  } else if (tmp_metric_type == 'percentage_change' || tmp_metric_type == 'percentage_absolute') {
    sign_threshold_list.value.forEach((measure) => { if (measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    tmp_threshold = tmp_sign_value * parseInt(threshold.value.value);
    measure_unit_label = "%";
  } else {
    tmp_sign_value = 1;
    tmp_threshold = parseInt(threshold.value.value);
  }
  let emit_name = 'add';

  if (is_edit == true)
    emit_name = 'edit';

  emit(emit_name, {
    frequency: tmp_frequency,
    metric: tmp_metric,
    metric_label: tmp_metric_label,
    threshold: tmp_threshold,
    metric_type: tmp_metric_type,
    snmp_device: tmp_device,
    snmp_device_label: tmp_device_label,
    snmp_device_port: tmp_device_ifid,
    snmp_device_port_label: tmp_device_ifid_label,
    rule_threshold_sign: tmp_sign_value,
    snmp_threshold_value: threshold.value.value,
    snmp_threshold_unit: measure_unit_label,
    snmp_metric_type_label: metric_type.value.title
  });



  close();
};


const edit_ = () => {
  add_(true);
}

const close = () => {
  modal_id.value.close();
};

const format_snmp_devices_list = function (_snmp_devices_list) {
  let devices_list = [];
  _snmp_devices_list.forEach(item => {
    if (item.column_name != null && item.column_name != "" && item.column_name != "all")
      devices_list.push({ label: item.column_name + " (" + item.column_key + ")", label_to_insert: item.column_key });
    else {
      if (item.column_name == "all")
        devices_list.push({ label: item.column_key, label_to_insert: item.column_name });
      else
        devices_list.push({ label: item.column_key, label_to_insert: item.column_key });
    }

  })
  const ip2int = str => str
    .split('.')
    .reduce((acc, byte) => acc + byte.padStart(3, 0), '');

  devices_list.sort(function (a, b) { return (a.label.toLowerCase() > b.label.toLowerCase() ? 1 : (a.label.toLowerCase() < b.label.toLowerCase()) ? -1 : 0); });
  return devices_list;
}

const metricsLoaded = (_snmp_devices_list, _snmp_metric_list, page_csrf) => {

  snmp_devices_list.value = format_snmp_devices_list(_snmp_devices_list);
  snmp_metric_list.value = _snmp_metric_list;
  frequency_list.value = props.frequency_list;
  selected_frequency.value = frequency_list.value[0];
  selected_metric.value = snmp_metric_list.value[0];
  page_csrf_.value = page_csrf;


}


onBeforeMount(() => {
  metric_type_list.value.forEach((t) => {
    if (t.active) {
      metric_type.value = t;
    }

  })
})

defineExpose({ show, close, metricsLoaded });


</script>

<style scoped></style>

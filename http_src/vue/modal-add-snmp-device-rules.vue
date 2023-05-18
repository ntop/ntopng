<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    <!-- Target information, here an IP is put -->
  <div class="form-group ms-2 me-2 mt-3 row">

  <label class="col-form-label col-sm-2">
    <b>{{ _i18n("if_stats_config.add_rules_type") }}</b>
  </label>
    <div class="col-sm-10">
	  <div class="btn-group btn-group-toggle" data-bs-toggle="buttons">
	    <label class="btn " :class="[rule_type == 'snmp'?'btn-primary active':'btn-secondary']">
	      <input  class="btn-check" type="radio" name="rule_type" value="snmp" @click="set_rule_type('snmp')"> {{ _i18n("if_stats_config.add_rules_type_snmp") }}
	    </label>
	  </div>
	</div>
  </div>

    <div class="form-group ms-2 me-2 mt-3 row">
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("if_stats_config.snmp_device")}}</b>
	    </label>
      <div class="col-10">

	    <SelectSearch v-model:selected_option="selected_snmp_device"
      			  @select_option="change_interfaces()"
              :options="snmp_devices_list">
        </SelectSearch>
        </div>
    </div>

     <div class="form-group ms-2 me-2 mt-3 row">
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("if_stats_config.snmp_interface")}}</b>
	    </label>
      <div class="col-10">

	    <SelectSearch v-model:selected_option="selected_snmp_interface"
              :options="snmp_interfaces_list">
        </SelectSearch>
        </div>
    </div>

    <div  class="form-group ms-2 me-2 mt-3 row">
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("if_stats_config.metric")}}</b>
	    </label>
        <div class="col-10">
          <SelectSearch v-model:selected_option="selected_snmp_device_metric"
            @select_option="change_active_threshold()"

            :options="snmp_metric_list">
          </SelectSearch>
        </div>
    </div>

    <!-- Frequency information, a frequency of 1 day, 5 minute or 1 hour for example -->
    <div class="form-group ms-2 me-2 mt-3 row">
      <label class="col-form-label col-sm-2" >
        <b>{{_i18n("if_stats_config.frequency")}}</b>
      </label>
      <div class="col-10">
        <SelectSearch v-model:selected_option="selected_frequency"
          :options="frequency_list">
			  </SelectSearch>
      </div>
    </div>

    <!-- Threshold information, maximum amount of bytes -->
    <div class="form-group ms-2 me-2 mt-3 row" style="margin-top:3px">
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("if_stats_config.threshold")}}</b>
	    </label>
      <template v-if="visible">
        <div class="col-sm-3">
          <SelectSearch v-model:selected_option="metric_type"
            :options="metric_type_active_list">
          </SelectSearch>  
        </div>
        <div class="col-3" :class="[ metric_type.id == 'throughput' ? 'p-0' : '']" >
          <div class="btn-group float-end btn-group-toggle" data-bs-toggle="buttons">
            <template v-if="metric_type.id == 'throughput'" v-for="measure in throughput_threshold_list" >
              <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off" ref="threshold_measure" name="threshold_measure">
              <label class="btn " :id="measure.id" @click="set_active_radio" v-bind:class="[ measure.active ? 'btn-primary active' : 'btn-secondary' ]" :for="measure.id">{{ measure.label }}</label>
            </template>
            <template v-if="metric_type.id == 'percentage'" v-for="measure in percentage_threshold_list">
              <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off" ref="threshold_measure" name="threshold_measure">
              <label class="btn " :id="measure.id" @click="set_active_radio" v-bind:class="[ measure.active ? 'btn-primary active' : 'btn-secondary' ]" :for="measure.id">{{ measure.label }}</label>
            </template>
            <template v-if="metric_type.id == 'volume'" v-for="measure in volume_threshold_list" >
              <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off" ref="threshold_measure" name="threshold_measure">
              <label class="btn " :id="measure.id" @click="set_active_radio" v-bind:class="[ measure.active ? 'btn-primary active' : 'btn-secondary' ]" :for="measure.id">{{ measure.label }}</label>
            </template>
          </div>
        </div>


        <div class="col-sm-2 btn-group float-end btn-group-toggle" data-bs-toggle="buttons">
          <template v-for="measure in sign_threshold_list" >
            <input :value="measure.value" :id="measure.id" type="radio" class="btn-check" autocomplete="off" ref="threshold_sign" name="threshold_sign">
            <label class="btn " :id="measure.id" @click="set_active_sign_radio" v-bind:class="[ measure.active ? 'btn-primary active' : 'btn-secondary' ]" :for="measure.id">{{ measure.label }}</label>
          </template>
        </div>
        
      </template>

      <div :class="[visible ? 'col-sm-2' : 'col-sm-8']">
        <template v-if="metric_type.id == 'percentage'">
          <input value="1" ref="threshold" type="number" name="threshold" class="form-control" max="100" min="1" required>
        </template>
        <template v-else> 
          <input value="1" ref="threshold" type="number" name="threshold" class="form-control" max="1023" min="1" required>
        </template>
      </div>
    </div>
      <template v-if="metric_type.id == 'percentage'">
        <div class="message alert alert-warning mt-3">
          {{ _i18n("show_alerts.host_rules_percentage") }}
        </div>
      </template>
  </template>
  <template v-slot:footer>
    <NoteList
    :note_list="note_list">
    </NoteList>
    <template v-if="is_edit_page == false">
    <button type="button" @click="add_" class="btn btn-primary"  :disabled="disable_add && rule_type == 'Host'">{{_i18n('add')}}</button>
    </template>
    <template v-else>
    <button type="button" @click="edit_" class="btn btn-primary"  :disabled="disable_add && rule_type == 'Host'">{{_i18n('apply')}}</button>
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
const emit = defineEmits(['add','edit']);
const _i18n = (t) => i18n(t);
const init_func = ref(null);
const delete_row = ref(null);
const snmp_metric_list = ref([])
const snmp_devices_list = ref([])
let snmp_interfaces_list = ref([])
const snmp_interfaces_url = `${http_prefix}/lua/pro/rest/v2/get/snmp/device/available_interfaces.lua`

const frequency_list = ref([])
const threshold_measure = ref(null)
const threshold_sign = ref(null)
const selected_metric = ref({})
const selected_snmp_device = ref(null)
const selected_snmp_interface = ref(null)

const selected_snmp_device_metric = ref({})
const selected_frequency = ref({})
const disable_add = ref(true)
const metric_type = ref({})
const visible = ref(true)
const rule_type = ref("snmp");
const is_edit_page = ref(false)
const page_csrf_ = ref(null);
let metric_type_active_list = ref([]);

let title =  _i18n('if_stats_config.add_host_rules_title');


const note_list = [
  _i18n('if_stats_config.note_snmp_device_rules.note_1'),
  _i18n('if_stats_config.note_snmp_device_rules.note_2'),
  _i18n('if_stats_config.note_snmp_device_rules.note_3'),
  _i18n('if_stats_config.note_3'),
  _i18n('if_stats_config.note_4'),
  _i18n('if_stats_config.note_5')
]

const metric_type_list = ref([
  { title: _i18n('volume'), label: _i18n('volume'), id: 'volume', active: true },
  { title: _i18n('throughput'), label: _i18n('throughput'), id: 'throughput', active: false },
  { title: _i18n('percentage'), label: _i18n('percentage'), id: 'percentage', acrive: false },
])

const volume_threshold_list = ref([
  { title: _i18n('kb'), label: _i18n('kb'), id: 'kb', value: 1024, active: false },
  { title: _i18n('mb'), label: _i18n('mb'), id: 'mb', value: 1048576, active: false },
  { title: _i18n('gb'), label: _i18n('gb'), id: 'gb', value: 1073741824, active: true, default_active: true},
]);

const throughput_threshold_list = ref([
  { title: _i18n('kbps'), label: _i18n('kbps'), id: 'kbps', value: 1000, active: false },
  { title: _i18n('mbps'), label: _i18n('mbps'), id: 'mbps', value: 1000000, active: false },
  { title: _i18n('gbps'), label: _i18n('gbps'), id: 'gbps', value: 1000000000, active: true, default_active: true},
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

const showed = () => {};

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

  radio_array.forEach((item) => item.active = item.default_active == true );
}

/**
 * 
 * Reset fields in modal form 
 */
const reset_modal_form = async function() {
  if (!is_edit_page.value) {

    host.value = "";
    selected_metric.value = snmp_metric_list.value[0];
    selected_snmp_device.value = null;
    selected_snmp_device.value = snmp_devices_list.value[0];
    change_interfaces();

    selected_snmp_device_metric.value = snmp_metric_list.value[2];
    change_active_threshold()
    
    selected_frequency.value = frequency_list.value[0];
    metric_type.value = metric_type_list.value[2];

    // reset metric_type_list
    metric_type_list.value.forEach((t) => t.active = false);
    metric_type_list.value[2].active = true;
    
    reset_radio_selection(volume_threshold_list.value);
    reset_radio_selection(throughput_threshold_list.value);
    reset_radio_selection(sign_threshold_list.value);

    rule_type.value = "snmp";

    disable_add.value = true;

    threshold.value.value = 1;
  }
}

const set_rule_type = (type) => {
    rule_type.value = type;
}



/**
 * 
 * Set row to edit 
 */
const set_row_to_edit = (row) => {

  if(row != null) {
    is_edit_page.value = true;
    title = _i18n('if_stats_config.edit_host_rules_title');

    disable_add.value = false;

    snmp_devices_list.value.forEach((item) => {
      if(item.label_to_insert == row.device)
        selected_snmp_device.value = item;
    } )

    // set threshold sign
    sign_threshold_list.value.forEach((t) => {
      t.active = (t.value == row.threshold_sign)
    })

    snmp_metric_list.value.forEach((t) => {
      if(t.id == row.metric)
        selected_snmp_device_metric.value = t;
    })

    // set threshold
    if(row.metric_type == 'volume')
      volume_threshold_list.value.forEach((t) => {
        if ( (row.threshold % t.value) == 0 ) {
          let row_threshold_value = row.threshold / t.value;
          if( row_threshold_value < 1024) {
            t.active = true;
            threshold.value.value = row_threshold_value == 0 ? 1 : row_threshold_value;
          } else {
            t.active = false;
          }
        } else {
          t.active = false;
        }
      })
    else if(row.metric_type == 'throughput') {
      row.threshold = row.threshold * 8;
      throughput_threshold_list.value.forEach((t) => {
          if ( (row.threshold % t.value) == 0 ) {
            let row_threshold_value = row.threshold / t.value;
            if( row_threshold_value < 1000) {
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
      threshold.value.value = row.threshold;
    }
    change_active_threshold();
    metric_type_active_list.value.forEach((item) => {
      if(item.id == row.metric_type) {
        metric_type.value = item;
        item.active = true;
      } else 
        item.active = false;
    })

    // set rule_type
    rule_type.value = row.rule_type;
    debugger;
    snmp_devices_list.value.forEach((t) => {
      if(t.label == row.device)
        selected_snmp_device.value = t;
    })

    frequency_list.value.forEach((item) => {
      if(item.id == row.frequency)
        selected_frequency.value = item;
    });

    change_interfaces(row.device_port);
  
    
  }
}

const show = (row) => {
  if(row != null)
    set_row_to_edit(row);
  else
    reset_modal_form();

  
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

  if(metric_type.value.id == 'throughput') {
    throughput_threshold_list.value.forEach((measure) => {
      (measure.id === id) ? measure.active = true : measure.active = false;
    })
  } else if (metric_type.value.id == 'volume') {
    volume_threshold_list.value.forEach((measure) => {
      (measure.id === id) ? measure.active = true : measure.active = false;
    })
  } else if (metric_type.value.id == 'percentage'){
    percentage_threshold_list.forEach((measure) => {
      (measure.id === id) ? measure.active = true : measure.active = false;
    })
  } 
  
}


async function change_interfaces(interface_id) {
  const url = NtopUtils.buildURL(snmp_interfaces_url+"?host="+selected_snmp_device.value.label_to_insert, rest_params)
  let interfaces_list = []
  await $.get(url, function(rsp, status){
    interfaces_list = rsp.rsp;
  });
  let result_interfaces = []

  interfaces_list.forEach(iface => {
    if(iface.name != null && iface.name != "" && iface.name != iface.id)
      result_interfaces.push({label: iface.name + " ("+iface.id+")", id: iface.id, name: iface.name })
    else
      result_interfaces.push({label: iface.id, id: iface.id,  name: iface.id})
  })

  result_interfaces.sort(function(a,b) {return (a.label.toLowerCase() > b.label.toLowerCase() ? 1 : (a.label.toLowerCase() < b.label.toLowerCase()) ? -1 : 0);});

  if (interface_id != null)
    result_interfaces.forEach((t) => {
      if(t.id == interface_id)
        selected_snmp_interface.value = t;
    })

  snmp_interfaces_list.value = result_interfaces;
}

function change_active_threshold() {
  let list_metrics_active = [];
  if(selected_snmp_device_metric.value.id == 'packets' || selected_snmp_device_metric.value.id == 'errors' ) {
    metric_type_list.value.forEach((t) => {
      if(t.id != 'percentage')
        t.active = false;
      else {
        list_metrics_active.push(t);
        t.active = true;
        metric_type.value = t;
      }
    })
  } else {
    list_metrics_active = metric_type_list.value;
  }

  metric_type_active_list.value = list_metrics_active;
}



/**
 * Function to add rule to rules list
 */
const add_ = (is_edit) => {
  let tmp_host = ''
  if(rule_type.value == 'snmp')
    tmp_host = host.value;

  const tmp_frequency = selected_frequency.value.id;
  const tmp_metric = selected_snmp_device_metric.value.id;
  const tmp_metric_label = selected_snmp_device_metric.value.label;
  debugger;
  const tmp_device = selected_snmp_device.value.label_to_insert;
  const tmp_device_label = selected_snmp_device.value.label;
  const tmp_device_ifid = selected_snmp_interface.value.id;
  const tmp_device_ifid_label = selected_snmp_interface.value.label;
  console.log(threshold)
  let tmp_metric_type = metric_type.value.id;
  let basic_value;
  let measure_unit_label;
  let basic_sign_value;
  let tmp_threshold;
  let tmp_sign_value;

  if(visible.value === false) {
    tmp_metric_type = ''
    tmp_extra_metric = ''
    tmp_threshold = threshold.value.value;
  }
  debugger;
  if(tmp_metric_type == 'throughput') {

    sign_threshold_list.value.forEach((measure) => { if(measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    throughput_threshold_list.value.forEach((measure) => { if(measure.active) { basic_value = measure.value; measure_unit_label = measure.label; }})
    tmp_threshold = basic_value * parseInt(threshold.value.value) / 8;
    /* The throughput is in bit, the volume in Bytes!! */
  } else if(tmp_metric_type == 'volume') {
    sign_threshold_list.value.forEach((measure) => { if(measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    volume_threshold_list.value.forEach((measure) => { if(measure.active) {basic_value = measure.value; measure_unit_label = measure.label;} })
    tmp_threshold = basic_value * parseInt(threshold.value.value);
  } else if(tmp_metric_type == 'percentage') {
    sign_threshold_list.value.forEach((measure) => { if(measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    tmp_threshold = tmp_sign_value * parseInt(threshold.value.value);
    measure_unit_label = "%";
  } else {
    tmp_sign_value = 1;
  }
  let emit_name = 'add';

  if(is_edit == true) 
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

const format_snmp_devices_list = function(_snmp_devices_list) {
  let devices_list = [];
  _snmp_devices_list.data.forEach(item => {
    if(item.column_name != null && item.column_name != "")
      devices_list.push({label : item.column_name + " ("+item.column_key+")" , label_to_insert: item.column_key});
    else
      devices_list.push({label : item.column_key, label_to_insert: item.column_key});

  })
  debugger;
  const ip2int = str => str
    .split('.')
    .reduce((acc, byte) => acc + byte.padStart(3, 0), '');

  devices_list.sort(function(a, b) {return (a.label.toLowerCase() > b.label.toLowerCase() ? 1 : (a.label.toLowerCase() < b.label.toLowerCase()) ? -1 : 0);});
  return devices_list;
}

const metricsLoaded =(_snmp_devices_list, _snmp_metric_list, page_csrf) => {

  snmp_devices_list.value = format_snmp_devices_list(_snmp_devices_list);
  snmp_metric_list.value = _snmp_metric_list;
  frequency_list.value = props.frequency_list;
  selected_frequency.value = frequency_list.value[0];
  selected_metric.value = snmp_metric_list.value[0];
  page_csrf_.value = page_csrf;
  
  
}


onBeforeMount(() => {
  metric_type_list.value.forEach((t) => {
    if(t.active) {
      metric_type.value = t;
    }

  })
})

defineExpose({ show, close, metricsLoaded });


</script>

<style scoped>
</style>

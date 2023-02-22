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
	    <label class="btn " :class="[rule_type == 'Host'?'btn-primary active':'btn-secondary']">
	      <input  class="btn-check" type="radio" name="rule_type" value="hosts" @click="set_rule_type('Host')"> {{ _i18n("if_stats_config.add_rules_type_host") }}
	    </label>
	    <label class="btn " :class="[rule_type == 'interface'?'btn-primary active':'btn-secondary']">
	      <input @click="set_rule_type('interface')" class="btn-check"  type="radio" name="rule_type" value="interface"> {{ _i18n("if_stats_config.add_rules_type_interface") }}
	    </label>
	  </div>
	</div>
  </div>

    <div v-if="rule_type == 'Host'" class="form-group ms-2 me-2 mt-3 row">
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("if_stats_config.target")}}</b>
	    </label>
	    <div class="col-sm-10" >
	      <input v-model="host"  @input="check_empty_host" class="form-control" type="text" :placeholder="host_placeholder" required>
	    </div>
    </div>

    <div v-if="rule_type == 'interface'" class="form-group ms-2 me-2 mt-3 row">
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("if_stats_config.target_interface")}}</b>
	    </label>
      <div class="col-10">
        
        <SelectSearch v-model:selected_option="selected_ifid"
              :options="ifid_list">
        </SelectSearch> 
      </div> 
    </div>


    <!-- Metric information, here a metric is selected (e.g. DNS traffic) -->
    <div v-if="metrics_ready" class="form-group ms-2 me-2 mt-3 row">
	    <label class="col-form-label col-sm-2" >
        <b>{{_i18n("if_stats_config.metric")}}</b>
	    </label>
      <template v-if="rule_type == 'Host'">
        <div class="col-10">
          <SelectSearch v-model:selected_option="selected_metric"
            @select_option="change_threshold()"
            :options="metric_list">
          </SelectSearch>
        </div>
      </template>
      <template v-else>
        <div class="col-10">
          <SelectSearch v-model:selected_option="selected_interface_metric"
            @select_option="change_interface_threshold()"
            :options="interface_metric_list">
          </SelectSearch>
        </div>
      </template>
    </div>

    <!-- Frequency information, a frequency of 1 day, 5 minute or 1 hour for example -->
    <div v-if="metrics_ready" class="form-group ms-2 me-2 mt-3 row">
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
            :options="metric_type_list">
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
    <button type="button" @click="edit_" class="btn btn-primary"  :disabled="disable_add && rule_type == 'Host'">{{_i18n('edit')}}</button>
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

const input_mac_list = ref("");
const input_trigger_alerts = ref("");

const modal_id = ref(null);
const emit = defineEmits(['add'])
const title = i18n('if_stats_config.add_host_rules_title')
const host_placeholder = i18n('if_stats_config.host_placeholder')
const metrics_ready = ref(false)
const _i18n = (t) => i18n(t);
const metric_list = ref([])
const init_func = ref(null);
const delete_row = ref(null);
const ifid_list = ref([])
const interface_metric_list = ref([])
const frequency_list = ref([])
const threshold_measure = ref(null)
const threshold_sign = ref(null)
const selected_metric = ref({})
const selected_frequency = ref({})
const selected_ifid = ref({})
const selected_interface_metric = ref({})
const disable_add = ref(true)
const metric_type = ref({})
const visible = ref(true)
const rule_type = ref("hosts");
const is_edit_page = ref(false)



const note_list = [
  _i18n('if_stats_config.note_1'),
  _i18n('if_stats_config.note_2'),
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
  metric_list: Array,
  ifid_list: Array,
  interface_metric_list: Array,
  frequency_list: Array,
  init_func: Function,
});

function reset_radio_selection(radio_array) {

  radio_array.forEach((item) => item.active = item.default_active == true );
}

function reset_modal_form() {
    host.value = "";
    selected_ifid.value = ifid_list.value[0];
    selected_metric.value = metric_list.value[0];
    selected_interface_metric.value = interface_metric_list.value[0];
    selected_frequency.value = frequency_list.value[0];
    metric_type.value = metric_type_list.value[0];

    // reset metric_type_list
    metric_type_list.value.forEach((t) => t.active = false);
    metric_type_list.value[0].active = true;

    reset_radio_selection(volume_threshold_list.value);
    reset_radio_selection(throughput_threshold_list.value);
    reset_radio_selection(sign_threshold_list.value);

    rule_type.value = "Host";

    disable_add.value = true;

    threshold.value.value = 1;
}

const set_rule_type = (type) => {
    rule_type.value = type;
}

const set_row_to_edit = () => {
  let row = init_func.value();

  if(row != null) {
    is_edit_page.value = true;

    disable_add.value = false;

    // set threshold sign
    sign_threshold_list.value.forEach((t) => {
      t.active = (t.value == row.threshold_sign)
    })

    // set metric_type
    metric_type_list.value.forEach((t) => {
      if(t.id == row.metric_type) {
        t.active = true;
        metric_type.value = t;
      } else {
        t.active = false;
      }
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

    // set rule_type
    rule_type.value = row.rule_type;
    
    if(rule_type.value == 'interface') {
      
      // set ifid
      ifid_list.value.forEach((t) => {
        if(t.id == row.target)
          selected_ifid.value = t;
      })
      
      // set metric
      if(row.extra_metric != null) {
        interface_metric_list.value.forEach((t) => {
          if(t.id == row.metric && t.extra_metric == row.extra_metric) {
            selected_interface_metric.value = t;
          }
        })

      } else {
        interface_metric_list.value.forEach((t) => {
          if(t.id == row.metric) {
            selected_interface_metric.value = t;
          }
        })
      }
    } else {

      //set host
      host.value = row.target;
      
      //set metric
      if(row.extra_metric != null) {
        metric_list.value.forEach((t) => {
          if(t.id == row.metric && t.extra_metric == row.extra_metric)
            selected_metric.value = t;
          })
      } else {
        metric_list.value.forEach((t) => {
          if(t.id == row.metric)
            selected_metric.value = t;  
        })
      }
    }
  }
}

const show = () => {
  reset_modal_form();
  if(init_func != null && init_func.value != null) {
    set_row_to_edit();
  }
  modal_id.value.show();
};

const change_threshold = () => {
  (selected_metric.value.show_volume == true) ? visible.value = true : visible.value = false
}

const change_interface_threshold = () => {
  (selected_interface_metric.value.show_volume == true) ? visible.value = true : visible.value = false
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



const add_ = () => {
  let tmp_host = ''
  if(rule_type.value == 'Host')
    tmp_host = host.value;

  const tmp_frequency = selected_frequency.value.id;
  const tmp_metric = selected_metric.value.id;
  const tmp_metric_label = (rule_type.value == 'Host')? selected_metric.value.label : selected_interface_metric.value.label;
  const tmp_interface_metric = selected_interface_metric.value.id;
  const tmp_rule_type = rule_type.value;
  const tmp_interface = selected_ifid.value.id;
  const tmp_interface_name = selected_ifid.value.label;
  let tmp_metric_type = metric_type.value.id;
  let tmp_extra_metric = (rule_type.value == 'Host')? ((selected_metric.value.extra_metric) ? selected_metric.value.extra_metric : null ) : ((selected_interface_metric.value.extra_metric) ? selected_interface_metric.value.extra_metric : null )
  let basic_value;
  let basic_sign_value;
  let tmp_threshold;
  let tmp_sign_value;

  if(visible.value === false) {
    tmp_metric_type = ''
    tmp_extra_metric = ''
    tmp_threshold = threshold.value.value;
  }
  

  if(tmp_metric_type == 'throughput') {
    sign_threshold_list.value.forEach((measure) => { if(measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    throughput_threshold_list.value.forEach((measure) => { if(measure.active) basic_value = measure.value; })
    tmp_threshold = basic_value * parseInt(threshold.value.value) / 8;
    /* The throughput is in bit, the volume in Bytes!! */
  } else if(tmp_metric_type == 'volume') {
    sign_threshold_list.value.forEach((measure) => { if(measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    volume_threshold_list.value.forEach((measure) => { if(measure.active) basic_value = measure.value; })
    tmp_threshold = basic_value * parseInt(threshold.value.value);
  } else if(tmp_metric_type == 'percentage') {
    sign_threshold_list.value.forEach((measure) => { if(measure.active) basic_sign_value = measure.value; })
    tmp_sign_value = parseInt(basic_sign_value);
    tmp_threshold = tmp_sign_value * parseInt(threshold.value.value);
  } else {
    tmp_sign_value = 1;
  }

  if (rule_type.value == 'Host')
    emit('add', { 
      host: tmp_host, 
      frequency: tmp_frequency, 
      metric: tmp_metric,
      metric_label: tmp_metric_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      extra_metric: tmp_extra_metric,
      rule_type: tmp_rule_type,
      rule_threshold_sign: tmp_sign_value
    });
  else
    emit('add', { 
      frequency: tmp_frequency, 
      metric: tmp_interface_metric,
      metric_label: tmp_metric_label,
      threshold: tmp_threshold,
      metric_type: tmp_metric_type,
      extra_metric: tmp_extra_metric,
      rule_type: tmp_rule_type,
      interface: tmp_interface,
      ifname: tmp_interface_name,
      rule_threshold_sign: tmp_sign_value
    });

  close();
};


const edit_ = () => {
  delete_row.value();
  add_();
}

const close = () => {
  modal_id.value.close();
};

const format_ifid_list = function(data) {
  let _ifid_list = []
  data.forEach((ifid) => {
    let item = {id: ifid.ifid, label: ifid.name};
    _ifid_list.push(item);
  }) 
  return _ifid_list
}

const metricsLoaded = (_metric_list, _ifid_list, _interface_metric_list, _init_func, _delete_row) => {
  metrics_ready.value = true;
  metric_list.value = _metric_list;
  interface_metric_list.value = _interface_metric_list;
  ifid_list.value = format_ifid_list(_ifid_list);
  frequency_list.value = props.frequency_list;
  selected_frequency.value = frequency_list.value[0];
  selected_metric.value = metric_list.value[0];
  selected_ifid.value = ifid_list.value[0];
  if(_init_func) {
    init_func.value = _init_func;
  }

  if(_delete_row) {
    delete_row.value = _delete_row;
  }
  
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

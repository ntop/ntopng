<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="d-flex align-items-center justify-content-between">
    <div>
        <a :href="link_url">
            <h4 class="fw-normal text-white"><span :title="counter_title">{{ counter }}</span><span v-if="secondary_counter" :title="secondary_counter_title"> / {{ secondary_counter }}</span></h4>
            <p class="subtitle text-white text-sm text mb-0" :class="label_size">{{ name }}</p>
        </a>
    </div>
    <div class="flex-shrink-0 ms-3">
        <i class="text-white" :class="icon"></i>
    </div>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch } from "vue";
import { ntopng_custom_events, ntopng_events_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils";

const _i18n = (t) => i18n(t);

const counter = ref('')
const secondary_counter = ref('')
const counter_title = ref('')
const secondary_counter_title = ref('')
const name = ref('')
const icon = ref('')
const link_url = ref('#')
const label_size = ref('h5')

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data (REST) */
    set_component_attr: Function, /* Callback to set component attributes (e.g. Box active color) */
    filters: Object
});

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], (cur_value, old_value) => {
  refresh_component();
}, { flush: 'pre', deep: true });

onBeforeMount(() => {
  init();
});

onMounted(() => {
});

function init() {
  if (props.params.i18n_name) {
    name.value = _i18n(props.params.i18n_name);
  }

  if (props.params.icon) {
    icon.value = props.params.icon + ' fa-2xl';
  }

  if (props.max_width && props.max_width <= 2) {
    label_size.value = 'h6';
  }

  refresh_component();
}

async function refresh_component() {
  /* Refresh component */

  if (props.params.url) {

    const url_params = {
      ifid: props.ifid,
      epoch_begin: props.epoch_begin,
      epoch_end: props.epoch_end,
      ...props.params.url_params,
      ...props.filters
    }

    let data = await props.get_component_data(`${http_prefix}${props.params.url}`, url_params, undefined, props.epoch_begin);
    if(props.params.badge_index) {
      data = data[props.params.badge_index]
    }
    /* TODO handle dot-separated path for non-flat json */
    let counter_value = data[props.params.counter_path];
    if (props.params.i18n_counter_title) {
      counter_title.value = _i18n(props.params.i18n_counter_title);
    }
    if(props.params.i18n_counter_title_path) {
      name.value = _i18n(data[props.params.i18n_counter_title_path]);
    }
    let has_secondary_counter = false;
    let secondary_counter_value = '';
    if (props.params.secondary_counter_path) {
      has_secondary_counter = true;
      secondary_counter_value = data[props.params.secondary_counter_path];
      if (props.params.i18n_secondary_counter_title) {
        secondary_counter_title.value = _i18n(props.params.i18n_secondary_counter_title);
      }
    }

    if(props.params.counter_formatter == "no_formatting") {
       counter.value = counter_value;
       if (has_secondary_counter) {
         secondary_counter.value = secondary_counter_value;
       }
    } else {
      let counter_formatter = props.params.counter_formatter;
      if (!counter_formatter) {
        counter_formatter = "number";
      }

      let formatCounter = formatterUtils.getFormatter(counter_formatter);
      counter.value = formatCounter(counter_value);
      if (has_secondary_counter) {
        secondary_counter.value = formatCounter(secondary_counter_value);
      }

      if (counter_value) {
        props.set_component_attr('active', true);
      }

      if (props.params.link) {
        const link_url_params = {
          ifid: props.ifid,
          epoch_begin: props.epoch_begin,
          epoch_end: props.epoch_end,
          ...props.params.link.url_params
        }

        const link_query_params = ntopng_url_manager.obj_to_url_params(link_url_params);
        link_url.value = `${http_prefix}${props.params.link.url}?${link_query_params}`;
      }
      if (props.params.link_path && data[props.params.link_path]) {
        link_url.value = `${http_prefix}${data[props.params.link_path]}`;
      }
    }
  }
}
</script>

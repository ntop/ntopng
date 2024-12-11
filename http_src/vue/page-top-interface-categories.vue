<!-- (C) 2024 - ntop.org     -->
<template>
  <div class="m-2 mb-3">
    <div class="row ms-3" id="interface_categories">
      <div class="col-12 widget-box row">
        <h3 class="widget-name">{{ _i18n('since_startup') }}</h3>
        <template v-for="chart_option in chart_options_since_startup">
          <div class="col-12">
            <h5 class="widget-name">{{ chart_option.title }}</h5>
            <Chart :id="chart_option.id" :chart_type="chart_option.type"
              :get_params_url_request="get_params_url_request" :base_url_request="chart_option.url"
              :register_on_status_change="false">
            </Chart>
          </div>
        </template>
      </div>
    </div>
    <TableWithConfig :key="recreate_table" ref="table_top_cat" :table_id="table_id" :csrf="context.csrf"
      :f_map_columns="map_table_def_columns" :get_extra_params_obj="get_extra_params_obj" :f_sort_rows="columns_sorting"
      @custom_event="on_table_custom_event">
    </TableWithConfig>
  </div>
</template>

<script setup>
import { default as Chart } from "./chart.vue";
import { ref, onMounted } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { ntopng_url_manager } from '../services/context/ntopng_globals_services';
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";

const _i18n = (t) => i18n(t);

/* ************************************** */

const props = defineProps({
  context: Object,
});

/* ************************************** */

const table_id = ref('top_interface_categories');
const table_top_cat = ref([]);
const recreate_table = ref(false);
const chart_options_since_startup = ref([
  {
    title: i18n('top_l7_cat'),
    type: ntopChartApex.typeChart.DONUT,
    url: `${http_prefix}/lua/rest/v2/get/interface/l7/stats.lua`,
    extra_params: { ndpi_category: true, ndpistats_mode: "sinceStartup", ifid: props.context.ifid },
    tab: `applications`,
    id: `top_l7_categories`,
  }])

/* ************************************** */

function column_data(col, row) {
  return row[col.data.data_field];
}

/* ************************************** */

function get_params_url_request(status) {
  if (status.id) {
    let array_element = chart_options_since_startup.value.find((el) => el.id === status.id);
    if (!array_element) array_element = chart_options_live.value.find((el) => el.id === status.id);
    const params = array_element.extra_params;
    return ntopng_url_manager.obj_to_url_params(params);
  }
  return "";
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
  if (col != null) {
    let r0_col = column_data(col, r0);
    let r1_col = column_data(col, r1);

    /* In case the values are the same, sort by IP */
    if (col.id == "category") {
      let val0 = r0_col
      let val1 = r1_col
      if (r0_col) val0 = r0_col.name
      if (r1_col) val1 = r1_col.name
      return sortingFunctions.sortByName(val0, val1, col.sort);
    } else if (col.id == "total_bytes") {
      return sortingFunctions.sortByNumberWithNormalizationValue(r0.bytes.total, r1.bytes.total, col.sort);
    } else if (col.id == "bytes_sent") {
      return sortingFunctions.sortByNumberWithNormalizationValue(r0.bytes.sent, r1.bytes.sent, col.sort);
    } else if (col.id == "bytes_rcvd") {
      return sortingFunctions.sortByNumberWithNormalizationValue(r0.bytes.rcvd, r1.bytes.rcvd, col.sort);
    }
  }
}

/* ************************************** */

const map_table_def_columns = (columns) => {
  const bytes_formatter = formatterUtils.getFormatter("bytes")
  let map_columns = {
    "category": (value, row) => {
      return value.name
    },
    "applications_list": (value, row) => {
      return value
    },
    "total_bytes": (value, row) => {
      return bytes_formatter(row.bytes.total)
    },
    "bytes_sent": (value, row) => {
      return bytes_formatter(row.bytes.sent)
    },
    "bytes_rcvd": (value, row) => {
      return bytes_formatter(row.bytes.rcvd)
    },
    "percentage": (value, row) => {
      return NtopUtils.createProgressBar(row.bytes.percentage)
    }
  };

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
    if (c.id == "actions") {
      const visible_dict = {
        historical_flows: props.context.historical_available,
        live_flows: true,
        timeseries: props.context.l7_timeseries_enabled,
      };
      c.button_def_array.forEach((b) => {
        if (!visible_dict[b.id]) {
          b.class.push("link-disabled");
        }
      });
    }
  });

  return columns;
};

/* ************************************** */

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ************************************** */

function create_historical_flows_url_link(row) {
  const epoch_begin = Math.floor(new Date().getTime() / 1000) - props.context.uptime
  return `${http_prefix}/lua/pro/db_search.lua?ifid=${props.context.ifid}&l7cat=${row.category.id};eq&epoch_begin=${epoch_begin}&epoch_end=${Math.floor(new Date().getTime() / 1000)}`
}

/* ************************************** */

function create_live_flows_url_link(row) {
  return `${http_prefix}/lua/flows_stats.lua?ifid=${props.context.ifid}&application=cat_${row.category.id}`
}

/* ************************************** */

function create_timeseries_url_link(row) {
  const epoch_begin = Math.floor(new Date().getTime() / 1000) - props.context.uptime
  return `${http_prefix}/lua/if_stats.lua?ifid=${props.context.ifid}&page=historical&epoch_begin=${epoch_begin}&epoch_end=${Math.floor(new Date().getTime() / 1000)}&timeseries_groups_mode=1_chart_x_metric&timeseries_groups=interface;${props.context.ifid};top:iface:ndpi_categories%2bcategory:${row.category.name};bytes%3Dtrue:true:false:false`
}

/* ************************************** */

function click_button_historical_flows(event) {
  const row = event.row;
  window.open(create_historical_flows_url_link(row), "_self");
}

/* ************************************** */

function click_button_live_flows(event) {
  const row = event.row;
  window.open(create_live_flows_url_link(row), "_self");
}

/* ************************************** */

function click_button_timeseries(event) {
  const row = event.row;
  window.open(create_timeseries_url_link(row), "_self");
}

/* ************************************** */

function on_table_custom_event(event) {
  let events_managed = {
    "click_button_historical_flows": click_button_historical_flows,
    "click_button_live_flows": click_button_live_flows,
    "click_button_timeseries": click_button_timeseries,
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

/* ************************************** */

function refresh_table() {
  table_top_cat.value.refresh_table(true);
}

/* ************************************** */

onMounted(async () => { });

/* ************************************** */

</script>

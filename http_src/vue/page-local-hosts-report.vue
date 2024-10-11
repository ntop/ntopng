<!--
  (C) 2013-24 - ntop.org
-->

<template>
  <DateTimeRangePicker class="mt-1 mb-2" :id="id_date_time_picker" :enable_refresh="false" ref="date_time_picker"
    @epoch_change="epoch_change" :custom_time_interval_list="time_preset_list" min_time_interval_id="hour"
    :custom_change_select_time="custom_change_select_time" :round_time="true">
  </DateTimeRangePicker>
  <div class="card h-100 overflow-hidden">
    <div class="m-2 mb-3">
      <TableWithConfig ref="table_local_hosts_report" :table_id="table_id" :f_map_columns="map_table_def_columns"
        :get_extra_params_obj="get_extra_params_obj" @custom_event="on_table_custom_event">
        <template v-slot:custom_header>
          <div class="dropdown me-3 d-inline-block" v-for="item in filters">
            <span class="no-wrap d-flex align-items-center filters-label"><b>{{ item["basic_label"]
                }}</b></span>
            <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5" dropdown_size="small"
              :options="item['options']" @select_option="add_table_filter">
            </SelectSearch>
          </div>
        </template> <!-- Dropdown filters -->
      </TableWithConfig>
    </div>
    <NoteList :note_list="note_list"></NoteList>
  </div>
</template>

<script setup>
import { ref, onBeforeMount } from "vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import formatterUtils from "../utilities/formatter-utils";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";

/* ************************************** */

const props = defineProps({
  context: Object,
});

/* ************************************** */

const table_id = ref('local_hosts_report')
const date_time_picker = ref(null);
const table_local_hosts_report = ref(null);
let id_date_time_picker = "date_time_picker";
const note_list = ref([i18n('local_hosts_report_description')]);

/* ************************************** */

const time_preset_list = [
  { value: "hour", label: i18n('show_alerts.presets.hour'), currently_active: false },
  { value: "day", label: i18n('show_alerts.presets.day'), currently_active: false },
  { value: "week", label: i18n('show_alerts.presets.week'), currently_active: false },
  { value: "month", label: i18n('show_alerts.presets.month'), currently_active: false },
  { value: "year", label: i18n('show_alerts.presets.year'), currently_active: false },
  { value: "custom", label: i18n('show_alerts.presets.custom'), currently_active: false, disabled: true, },
];

const filters = ref([{
  id: "host_visibility",
  label: i18n('hosts'),
  title: i18n('hosts'),
  options: [
    { key: "host_visibility", value: "visible", label: i18n('visible'), currently_active: true },
    { key: "host_visibility", value: "hidden", label: i18n('hidden'), currently_active: false },
    { key: "host_visibility", value: "no_traffic", label: i18n('no_traffic'), currently_active: false },
    { key: "host_visibility", value: "only_traffic", label: i18n('only_traffic'), currently_active: false }
  ],
}])

const gradient_color = [
  "#d3d3d3",
  "#39d353",
  "#26a641",
  "#006d32",
]

/* ************************************** */

async function click_button_hide_host(event) {
  const row = event.row;
  const params = {
    host: row.ip,
    hide: true
  }
  const url_params = ntopng_url_manager.obj_to_url_params(params);
  const url = `${http_prefix}/lua/pro/rest/v2/get/host/hide_host.lua?${url_params}`;

  await ntopng_utility.http_request(url);
  epoch_change(); // reload
}

/* ************************************** */

async function click_button_show_host(event) {
  const row = event.row;
  const params = {
    host: row.ip,
    hide: false
  }
  const url_params = ntopng_url_manager.obj_to_url_params(params);
  const url = `${http_prefix}/lua/pro/rest/v2/get/host/hide_host.lua?${url_params}`;

  await ntopng_utility.http_request(url);
  epoch_change(); // reload
}

/* ************************************** */

function on_table_custom_event(event) {
  let events_managed = {
    "click_button_hide_host": click_button_hide_host,
    "click_button_show_host": click_button_show_host
  };
  if (events_managed[event.event_id] == null) {
    return;
  }
  events_managed[event.event_id](event);
}

/* ************************************** */

const get_extra_params_obj = () => {
  let extra_params = ntopng_url_manager.get_url_object();
  return extra_params;
};

/* ************************************** */

async function epoch_change() {
  if (table_local_hosts_report.value) {
    table_local_hosts_report.value.refresh_table(false);
  }
}

/* ************************************** */

function getMonday(d) {
  const date = new Date(d);
  const day = date.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  date.setDate(date.getDate() + diff);
  date.setHours(0, 0, 0, 0);
  return date;
}

/* ************************************** */

function custom_change_select_time(timeframe_id) {
  const now = new Date();

  let epoch_begin = 0;
  let epoch_end = 0;
  switch (timeframe_id) {
    case 'hour':
      const currentHour = now.getHours();
      const currentMinutes = now.getMinutes();
      const nextHour = currentMinutes === 0 ? currentHour : currentHour + 1;
      const previousHour = currentHour;
      const previousHourDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), previousHour, 0, 0, 0);
      const nextHourDate = new Date(now.getFullYear(), now.getMonth(), now.getDate(), nextHour, 0, 0, 0);
      epoch_begin = previousHourDate.getTime();
      epoch_end = nextHourDate.getTime();
      break;
    case 'day':
      const todayMidnight = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);
      const nextDayMidnight = new Date(todayMidnight);
      nextDayMidnight.setDate(todayMidnight.getDate() + 1);
      epoch_begin = todayMidnight.getTime();
      epoch_end = nextDayMidnight.getTime();
      break;
    case 'week':
      const currentMonday = getMonday(now);
      const nextMonday = new Date(currentMonday);
      nextMonday.setDate(currentMonday.getDate() + 7);
      epoch_begin = currentMonday.getTime();
      epoch_end = nextMonday.getTime();
      break;
    case 'month':
      const currentMonthFirstDay = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
      const nextMonthFirstDay = new Date(currentMonthFirstDay);
      nextMonthFirstDay.setMonth(currentMonthFirstDay.getMonth() + 1);
      epoch_begin = currentMonthFirstDay.getTime();
      epoch_end = nextMonthFirstDay.getTime();
      break;
    case 'year':
      const currentYearFirstDay = new Date(now.getFullYear(), 1, 0, 0, 0, 0, 0);
      const nextYearFirstDay = new Date(currentYearFirstDay);
      nextYearFirstDay.setFullYear(nextYearFirstDay.getFullYear() + 1);
      epoch_begin = currentYearFirstDay.getTime();
      epoch_end = nextYearFirstDay.getTime();
      break;

    default:
      break;
  }
  ntopng_url_manager.set_key_to_url("preset", timeframe_id);

  return [epoch_begin / 1000, epoch_end / 1000]
}

/* ************************************** */

function calculate_gradient(value, max_value) {
  if (!value || value == 0) {
    return gradient_color[0]
  } else if(value > (max_value / 3 * 2)) {
    return gradient_color[3]
  } else if(value > (max_value / 3 * 2)) {
    return gradient_color[2]
  } else {
    return gradient_color[1]
  }
}

/* ************************************** */

const map_table_def_columns = (columns) => {
  const formatter = formatterUtils.getFormatter("bytes");
  let map_columns = {
    "ip": (value, row) => {
      const url = `${http_prefix}/lua/host_details.lua?host=${value}`
      if (row.online) {
        return `<a href=${url}>${value}</a>`
      }
      return value;
    },
    "name": (value, row) => {
      return value;
    },
    "availability": (value, row) => {
      const squareLength = 7, squareHeight = 20;
      let svg = `<svg width='${squareLength * value.length + value.length * 2}' height='20' viewBox='0 0 ${squareLength * value.length + value.length * 2} 20'>`;

      value.forEach((el, index) => {
        const rect = $(document.createElementNS("http://www.w3.org/2000/svg", "rect"));
        rect.attr('x', index * (squareLength + 2)).attr('y', 0).attr('width', squareLength).attr('height', squareHeight);
        rect.attr('fill', calculate_gradient(el, row.max_value_per_point[index]));
        svg = `${svg}${rect[0].outerHTML}`;
      })
      svg = `${svg}</svg>`
      return svg;
    },
    "bytes_sent": (value, row) => {
      return formatter(value);
    },
    "bytes_rcvd": (value, row) => {
      return formatter(value);
    },
    "total_traffic": (value, row) => {
      return formatter(value);
    },
  }

  columns.forEach((c) => {
    c.render_func = map_columns[c.data_field];
    if (c.id == "actions") {
      c.button_def_array.forEach((b, i) => {
        b.f_map_class = (current_class, row) => {
          const visibility = ntopng_url_manager.get_url_entry("host_visibility");
          if (visibility == "visible") {
            if (b.id != "hide_host") {
              current_class.push("link-disabled");
            }
          } else {
            if (b.id != "show_host") {
              current_class.push("link-disabled");
            }
          }
          return current_class;
        }
      });
    }
  });

  return columns;
};

/* ************************************** */

function add_table_filter(opt) {
  ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
  table_local_hosts_report.value.refresh_table();
}

/* ************************************** */

onBeforeMount(() => {
  let current_epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
  let current_epoch_end = ntopng_url_manager.get_url_entry("epoch_end");
  let [epoch_begin, epoch_end] = custom_change_select_time("hour");
  if (!current_epoch_begin) {
    ntopng_url_manager.set_key_to_url("epoch_begin", `${epoch_begin}`);
  }
  if (!current_epoch_end) {
    ntopng_url_manager.set_key_to_url("epoch_end", `${epoch_end}`);
  }
  if (!current_epoch_begin && !current_epoch_end) {
    ntopng_url_manager.set_key_to_url("preset", "hour");
    time_preset_list[0].currently_active = true;
  }
  const visibility = ntopng_url_manager.get_url_entry("host_visibility");
  filters.value.forEach((item) => {
    let selected_option
    item.options.forEach((item2) => {
      if (visibility == item2.value) {
        item2.currently_active = true
        selected_option = item2
      } else {
        item2.currently_active = false
      }
    })
    if (!selected_option) {
      item.options[0].currently_active = true;
      selected_option = item.options[0];
    }
    item.current_option = selected_option;
  })
})

</script>

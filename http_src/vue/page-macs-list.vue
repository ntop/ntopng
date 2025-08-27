<!-- (C) 2025 - ntop.org -->
<template>
  <div class="m-2 mb-3">
    <TableWithConfig ref="table_macs_list" :table_id="table_id" :csrf="csrf" :showLoading="true"
      :f_map_columns="map_table_def_columns"
      :get_extra_params_obj="get_extra_params_obj"
      :f_sort_rows="columns_sorting"
      @rows_loaded="change_filter_labels">
      
      <template v-slot:custom_header>
        <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
          <span class="no-wrap d-flex align-items-center my-auto me-2 filters-label"><b>{{ item["basic_label"] }}</b></span>
          <SelectSearch v-model:selected_option="item['current_option']"
            theme="bootstrap-5"
            dropdown_size="small"
            :disabled="loading"
            :options="item.options"
            @select_option="add_table_filter">
          </SelectSearch>
        </div>

        <div class="d-flex justify-content-center align-items-center">
          <div class="btn btn-sm btn-primary mt-2 me-3" @click="reset_filters">
            {{ _i18n('reset') }}
          </div>
          <Spinner :show="loading" size="1rem" class="me-1"></Spinner>
        </div>
      </template>
    </TableWithConfig>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as SelectSearch } from "./select-search.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import { default as Spinner } from "./spinner.vue";
import formatterUtils from "../utilities/formatter-utils";

/* ************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({ context: Object });

/* ************************************** */
const loading = ref(false);
const mac_filters_key = ref(0);
const table_id = ref("macs_list");
const table_macs_list = ref(null);
const filter_table_array = ref([]);
const csrf = props.context.csrf;

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "mac": (value, row) => {
            return value
        },
        "manufacturer": (value, row) => {
            let name = value
            if (!dataUtils.isEmptyOrNull(value.alt_name)) {
                name = value.alt_name
                if (value.alt_name != value.name && !dataUtils.isEmptyOrNull(value.name)) {
                    name = `${name} [${value.name}]`
                }
            }

            return name
        },
        "device_type": (value, row) => {
            let name = value
            if (!dataUtils.isEmptyOrNull(value.alt_name)) {
                name = value.alt_name
                if (value.alt_name != value.name && !dataUtils.isEmptyOrNull(value.name)) {
                    name = `${name} [${value.name}]`
                }
            }
            return value
        },
        "name": (value, row) => {
            return value
        },
        "hosts": (value, row) => {
            return formatterUtils.getFormatter("full_number")(value)
        },
        "arp": (value, row) => {
            return formatterUtils.getFormatter("full_number")(value)
        },
        "seen_since": (value, row) => {
            if (value > 0) {
                return NtopUtils.secondsToTime((Math.round(new Date().getTime() / 1000)) - value)
            }
            return ''
        },
        "traffic_breakdown": (value, row) => {
            const sent_pctg = row.bytes.sent * 100 / row.bytes.total
            const rcvd_pctg = row.bytes.rcvd * 100 / row.bytes.total
            return NtopUtils.createBreakdown(sent_pctg, rcvd_pctg, _i18n('sent'), _i18n('rcvd'))
        },
        "throughput": (value, row) => {
            let return_value = ''
            if (row.throughput_type === 'bps' && !dataUtils.isEmptyOrNull(value)) {
                return_value = formatterUtils.getFormatter("bps")(value)
            } else if (row.throughput_type === 'pps' && !dataUtils.isEmptyOrNull(value)) {
                return_value = formatterUtils.getFormatter("pps")(value)
            }
            return return_value
        },
        "traffic": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value)
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
    });

    return columns;
};

/* ************************************** */

function set_filter_array_label() {
    filter_table_array.value.forEach((el, index) => {
        /* Setting the basic label */
        if (el.basic_label == null) {
            el.basic_label = el.label;
        }

        /* Getting the currently selected filter */
        const url_entry = ntopng_url_manager.get_url_entry(el.id)
        el.options.forEach((option) => {
            if (option.value.toString() === url_entry) {
                el.current_option = option;
            }
        })
    })
}

/* ************************************** */

function change_filter_labels() {
    set_filter_array_label()
}

/* ************************************** */

async function add_table_filter(opt) {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    set_filter_array_label();
    table_macs_list.value.refresh_table();
    filter_table_array.value = await load_table_filters_array()
}

/* ************************************** */

async function load_table_filters(filter, filter_index) {
    filter.show_spinner = true;
    await nextTick();
    filter.options = filter_table_array.value.find((t) => t.id == filter.id).options;
    await nextTick();
    let dropdown = filter_table_dropdown_array.value[filter_index];
    dropdown.load_menu();
    filter.show_spinner = false;
}

/* ************************************** */

async function load_table_filters_array() {
    loading.value = true;
    let extra_params = get_extra_params_obj();
    let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/rest/v2/get/mac/mac_filters.lua?${url_params}`;
    let res = await ntopng_utility.http_request(url);
    mac_filters_key.value = mac_filters_key.value + 1
    loading.value = false;

    return res.map((t) => {
        const key_in_url = ntopng_url_manager.get_url_entry(t.name);
        if (dataUtils.isEmptyOrNull(key_in_url)) {
            ntopng_url_manager.set_key_to_url(t.name, ``);
        }
        return {
            id: t.name,
            label: t.label,
            title: t.tooltip,
            options: t.value,
            hidden: (t.value.length == 1)
        };
    });
}

/* ************************************** */

function reset_filters() {
    filter_table_array.value.forEach((el, index) => {
        /* Getting the currently selected filter */
        ntopng_url_manager.set_key_to_url(el.id, ``);
    })
    load_table_filters_array();
    refresh_table();
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
      if (col.id == "manufacturer") {
      return sortingFunctions.sortByName(r0.manufacturer, r1.manufacturer, col.sort);
    } else if (col.id == "mac") {
      return sortingFunctions.sortByMacAddress(r0.mac, r1.mac, col.sort);
    } else if (col.id == "hosts") {
      return sortingFunctions.sortByNumber(r0.hosts, r1.hosts, col.sort);
    } else if (col.id == "arp") {
      return sortingFunctions.sortByNumber(r0.arp, r1.arp, col.sort);
    } else if (col.id == "seen_since") {
      return sortingFunctions.sortByNumber(r0.seen_since, r1.seen_since, col.sort);
    } else if (col.id == "throughput") {
      return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
    } else if (col.id == "traffic") {
      return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
    }}
 }

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function refresh_table() {
    table_macs_list.value.refresh_table(true);
}

/* ************************************** */

onMounted(async () => {
    setInterval(refresh_table, 10000)
    filter_table_array.value = await load_table_filters_array();
    set_filter_array_label()
});

</script>

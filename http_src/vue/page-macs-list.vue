<!-- (C) 2025 - ntop.org -->
<template>
  <div class="m-2 mb-3">
    <TableWithConfig ref="table_macs_list" :table_id="table_id" :csrf="csrf" :showLoading="true"
      :f_map_columns="map_table_def_columns"
      :get_extra_params_obj="get_extra_params_obj"
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
const table_id = ref(props.context.isnEdge ? "nedge_macs_list" : "macs_list");
const table_macs_list = ref(null);
const filter_table_array = ref([]);
const csrf = props.context.csrf;

const workstation_icon = '<i class="fas fa-desktop fa-lg devtype-icon" aria-hidden="true"></i>';
const networking_icon = '<i class="fas fa-arrows-alt fa-lg devtype-icon" aria-hidden="true"></i>';
const tv_icon = '<i class="fas fa-tv fa-lg devtype-icon" aria-hidden="true"></i>';
const printer_icon = '<i class="fas fa-print fa-lg devtype-icon" aria-hidden="true"></i>';
const iot_icon = '<i class="fas fa-thermometer fa-lg devtype-icon" aria-hidden="true"></i>';
const multimedia_icon = '<i class="fas fa-music fa-lg devtype-icon" aria-hidden="true"></i>';
const tablet_icon = '<i class="fas fa-tablet fa-lg devtype-icon" aria-hidden="true"></i>';
const video_icon = '<i class="fas fa-video fa-lg devtype-icon" aria-hidden="true"></i>';
const wifi_icon = '<i class="fas fa-wifi fa-lg devtype-icon" aria-hidden="true"></i>';
const laptop_icon = '<i class="fas fa-laptop fa-lg devtype-icon" aria-hidden="true"></i>';
const phone_icon = '<i class="fas fa-mobile fa-lg devtype-icon" aria-hidden="true"></i>';
const nas_icon = '<i class="fas fa-database fa-lg devtype-icon" aria-hidden="true"></i>';

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "mac": (value, row) => {
            let mac_details_url = `${http_prefix}/lua/mac_details.lua?host=${value}`

            return `<a href=${mac_details_url}>${value}</a>`
        },
        "manufacturer": (value, row) => {
            return value
        },
        "device_type": (value, row) => {
            let device_type_label = value.device_type_label
            let icons = ''
            if (!dataUtils.isEmptyOrNull(value.workstation)) {
                icons = `${icons} ${workstation_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.networking)) {
                icons = `${icons} ${networking_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.tv)) {
                icons = `${icons} ${tv_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.printer)) {
                icons = `${icons} ${printer_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.iot)) {
                icons = `${icons} ${iot_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.multimedia)) {
                icons = `${icons} ${multimedia_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.tablet)) {
                icons = `${icons} ${tablet_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.video)) {
                icons = `${icons} ${video_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.wifi)) {
                icons = `${icons} ${wifi_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.laptop)) {
                icons = `${icons} ${laptop_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.phone)) {
                icons = `${icons} ${phone_icon}`
            }
            if (!dataUtils.isEmptyOrNull(value.nas)) {
                icons = `${icons} ${nas_icon}`
            }

            return `${device_type_label} ${icons}`
        },
        "name": (value, row) => {
            if(value.has_name === false){
                if(value.num_hosts > 0){
                    let url_first_device = `${http_prefix}/lua/host_details.lua?host=${value.host_label}`
                    let url_mac = `${http_prefix}/lua/hosts_stats.lua?mac=${row.mac}`
                    if(value.num_hosts == 1){
                        return `<a href=${url_first_device}>${value.host_label}</a>`
                    }
                    else if(value.num_hosts > 1) {
                        return `<a href=${url_first_device}>${value.host_label}</a> and <a href=${url_mac}>${value.num_hosts-1} more host(s)</a>`
                    }
                }
                else return ''
            }
            else return value.name
        },
        "hosts": (value, row) => {
            return formatterUtils.getFormatter("full_number")(value)
        },
        "location": (value, row) => {
            if (!dataUtils.isEmptyOrNull(value)) {
                return value.toUpperCase()
            }
            return ''
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
        "breakdown": (value, row) => {
            let traffic = row.bytes_sent + row.bytes_rcvd
            const sent_pctg = (row.bytes_sent / traffic) * 100
            const rcvd_pctg = (row.bytes_rcvd / traffic) * 100
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
        } else if (col.id == "location") {
            return sortingFunctions.sortByName(r0.location, r1.location, col.sort);
        } else if (col.id == "hosts") {
            return sortingFunctions.sortByNumber(r0.hosts, r1.hosts, col.sort);
        } else if (col.id == "arp") {
            return sortingFunctions.sortByNumber(r0.arp, r1.arp, col.sort);
        } else if (col.id == "seen_since") {
            /** 
             * R1 and R0 are inverted because we display the distance from seen_since to now rather
             * than the timestamp. Consequently, in ascending order, the first element will
             * be the one closest to the current time, which has the highest timestamp.
             */  
            return sortingFunctions.sortByNumber(r1.seen_since, r0.seen_since, col.sort);
        } else if (col.id == "throughput") {
            return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
        } else if (col.id == "traffic") {
            return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
        }
    }
 }

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

function refresh_table() {
    table_macs_list.value.refresh_table(false);
}

/* ************************************** */

onMounted(async () => {
    filter_table_array.value = await load_table_filters_array();
    set_filter_array_label()
});

</script>

<!-- (C) 2024 - ntop.org     -->
<template>
    <div class="m-2 mb-3">
        <TableWithConfig ref="table_blacklists" :table_id="table_id" :csrf="csrf" :f_map_columns="map_table_def_columns"
            :get_extra_params_obj="get_extra_params_obj" :f_sort_rows="columns_sorting"
            @custom_event="on_table_custom_event" @rows_loaded="change_filter_labels">
            <template v-slot:custom_header>
                <div class="dropdown me-3 d-inline-block" v-for="item in filter_table_array">
                    <span class="no-wrap d-flex align-items-center filters-label"><b>{{ item["basic_label"]
                            }}</b></span>
                    <SelectSearch v-model:selected_option="item['current_option']" theme="bootstrap-5"
                        dropdown_size="small" :disabled="loading" :options="item['options']"
                        @select_option="add_table_filter">
                    </SelectSearch>
                </div>
            </template> <!-- Dropdown filters -->
        </TableWithConfig>
    </div>

    <ModalEditBlacklist @edit_blacklist="edit_blacklist" ref="modal_edit_blacklist">
    </ModalEditBlacklist>
</template>
<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";
import { default as ModalEditBlacklist } from "./modal-edit-blacklist.vue";

/* ************************************** */

const _i18n = (t) => i18n(t);
const props = defineProps({
    context: Object,
});

/* ************************************** */

const table_id = ref('blacklists');
const table_blacklists = ref(null);
const csrf = props.context.csrf;
const filter_table_array = ref([]);
const filters = ref([]);
const loading = ref(false);
const blacklist_chart_url = `${http_prefix}/lua/admin/blacklists.lua?page=charts&ts_query=blacklist_name:_BS_NAME_&ts_schema=top:blacklist:hits`
const modal_edit_blacklist = ref(null);

/* ************************************** */
function column_data(col, row) {
    if (col.id == "column_err_interfaces") {
        return row["column_err_interfaces_num"];
    }
    return row[col.data.data_field];
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        let r0_col = column_data(col, r0);
        let r1_col = column_data(col, r1);

        if (col.id == "name" || col.id == "status" || col.id == "category") {
            return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
        } else {
            const lower_value = 0;
            return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
        }
    }
}

/* ************************************** */

const map_table_def_columns = (columns) => {
    let map_columns = {
        "name": (value, row) => {
            return value;
        },
        "status": (value, row) => {
            if (value === "enabled") {
                return `<span class="badge bg-success">${i18n("category_lists.enabled")}</span>`
            } else if (value === "disabled") {
                return `<span class="badge bg-danger">${i18n("nedge.status_disabled")}</span>`
            } else {
                return `<span class="badge bg-danger">${i18n("error")}</span>`
            }
        },
        "category": (value, row) => {
            return value;
        },
        "update_frequency": (value, row) => {
            if (value == 86400) {
                return i18n("alerts_thresholds_config.daily")
            } else if (value == 3600) {
                return i18n("alerts_thresholds_config.hourly")
            } else {
                return i18n("alerts_thresholds_config.manual")
            }
        },
        "last_update": (value, row) => {
            if (value > 0) {
                return NtopUtils.secondsToTime((Math.round(new Date().getTime() / 1000)) - value)
            }
            return ''
        },
        "entries": (value, row) => {
            if (value > 0) {
                let danger_icon = ''
                return `${formatterUtils.getFormatter("full_number")(value)}${danger_icon}`
            }
            return ''
        },
        "hits": (value, row) => {
            if (value > 0) {
                let danger_icon = ''
                return `${formatterUtils.getFormatter("full_number")(value)}${danger_icon}`
            }
            return ''
        },
    };
    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];

        if (c.id == "actions") {
            const visible_dict = {
                "chart_blacklist": true,
                "refresh_blacklist": true
            };
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    current_class = current_class.filter((class_item) => class_item != "link-disabled");
                    if ((row.status != "enabled" || row.hits == 0) && b.id == "chart_blacklist") {
                        current_class.push("link-disabled");
                    } else if((row.status != "error" && row.status !=  "enabled") && b.id == "refresh_blacklist") {
                        current_class.push("link-disabled");
                    }
                    return current_class;
                }
            });
        }
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

function add_filters_to_rows() {
    const filters = document.querySelectorAll('.tableFilter');
    filters.forEach(filter => {
        filter.addEventListener('click', add_filter_from_table_element);
    });
}

/* ************************************** */

function change_filter_labels() {
    add_filters_to_rows()
}

/* ************************************** */

function add_table_filter(opt) {
    ntopng_url_manager.set_key_to_url(opt.key, `${opt.value}`);
    table_blacklists.value.refresh_table();
    load_table_filters_array()
}

/* ************************************** */

function set_filters_list(res) {
    if (!res) {
        filter_table_array.value = filters.value.filter((t) => {
            if (t.show_with_key) {
                const key = ntopng_url_manager.get_url_entry(t.show_with_key)
                if (key !== t.show_with_value) {
                    return false
                }
            }
            return true
        })
    } else {
        filters.value = res.map((t) => {
            const key_in_url = ntopng_url_manager.get_url_entry(t.name);
            if (key_in_url === null) {
                ntopng_url_manager.set_key_to_url(t.name, t.value[0].value);
            }
            return {
                id: t.name,
                label: t.label,
                title: t.tooltip,
                options: t.value,
                show_with_key: t.show_with_key,
                show_with_value: t.show_with_value,
            };
        });
        set_filters_list();
        return;
    }
    set_filter_array_label();
}

/* ************************************** */

async function load_table_filters_array() {
    /* Clear the interval 2 times just in case, being this function async, 
        it could happen some strange behavior */
    loading.value = true;
    let extra_params = get_extra_params_obj();
    let url_params = ntopng_url_manager.obj_to_url_params(extra_params);
    const url = `${http_prefix}/lua/rest/v2/get/system/blacklists/blacklists_filters.lua?${url_params}`;
    const res = await ntopng_utility.http_request(url);
    set_filters_list(res)
    loading.value = false;
}

/* ************************************** */

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

/* ************************************** */

async function click_button_charts(event) {
    const row = event.row;
    window.open(blacklist_chart_url.replace("_BS_NAME_", row.name));
}

/* ************************************** */

async function edit_blacklist(params) {
    params.csrf = props.context.csrf;
    let url = `${http_prefix}/lua/rest/v2/edit/system/edit_blacklist.lua`;
    try {
        let headers = {
            'Content-Type': 'application/json'
        };
        await ntopng_utility.http_request(url, { method: 'post', headers, body: JSON.stringify(params) });
    } catch (err) {
        console.error(err);
    }
    setTimeout(() => { table_blacklists.value.refresh_table() }, 2000 /* resfresh after 5 seconds */)
}

/* ************************************** */

async function click_button_edit(event) {
    modal_edit_blacklist.value.show(event.row);
}

/* ************************************** */

async function click_button_refresh(event) {
    const row = event.row;
    const url = `${http_prefix}/lua/rest/v2/get/system/blacklists/update_blacklist.lua?list_name=${row.name}`;
    await ntopng_utility.http_request(url);
    table_blacklists.value.refresh_table();
    setTimeout(() => { table_blacklists.value.refresh_table() }, 2000 /* resfresh after 5 seconds */)
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_chart": click_button_charts,
        "click_edit": click_button_edit,
        "click_refresh": click_button_refresh,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

onBeforeMount(() => {
    load_table_filters_array();
})

/* ************************************** */

onMounted(() => { });

</script>

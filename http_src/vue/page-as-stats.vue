<template>
    <div>
        <div v-if="(showChart || !emptyData) && props.context.showTimeseries" class="mb-4 mt-3">
            <div v-if="showTitle "class="widget-name"><h6 class="m-0">{{ chart_title }}</h6></div>  
            <DashboardTimeseries :id="timeseries_id" :epoch_begin="epoch_begin"
                :epoch_end="epoch_end" :i18n_title="chart_title" :ifid="props.context.ifid.toString()" :max_width="12"
                :max_height="4" :params="params" :get_component_data="get_component_data"
                :set_component_attr="set_component_attr" :csrf="props.context.csrf">
            </DashboardTimeseries>
        </div>
        <TableWithConfig ref="table_as_stats" :table_id="table_id" :csrf="props.context.csrf"
            :f_map_columns="map_table_def_columns" :f_sort_rows="columns_sorting"
            :get_extra_params_obj="get_extra_params_obj" @custom_event="on_table_custom_event">
        </TableWithConfig>
    </div>
</template>


<script setup>
import { ref } from "vue";
import { default as sortingFunctions } from "../utilities/sorting-utils.js";
import { default as TableWithConfig } from "./table-with-config.vue";
import { default as DashboardTimeseries } from "./dashboard-timeseries.vue";
import { default as dataUtils } from "../utilities/data-utils.js";
import formatterUtils from "../utilities/formatter-utils";
import NtopUtils from "../utilities/ntop-utils.js";

const _i18n = (t) => i18n(t);

const props = defineProps({
    context: Object,
});

const current_time = Math.floor(Date.now() / 1000);
const seconds_one_week = 3600 * 24 * 7;
const table_id = ref('as_stats');
const chart_title = _i18n('top_active_asn')
const showTitle = ref(false);
const timeseries_id = ref('top_asn');
const table_as_stats = ref(null);
const epoch_begin = ref(current_time - seconds_one_week); // Get one week ago
const epoch_end = ref(current_time);
const showSankey = props.context.showSankey;
const showChart = ref(props.context.isEnterprise);
const emptyData = ref(false);
const params = {
    post_params: {
        limit: 180,
        version: 4,
        ts_requests: {
            "$IFID$": {
                ts_query: `ifid:$IFID$`,
                ts_schema: `top:asn:traffic`,
            }
        }
    },
    source_type: "interface"
}

const ts_query = {
    ts_query: `ifid:$IFID$,asn:$ASN$`,
    ts_schema: `asn:traffic`,
}

/* *************************************************** */

const set_component_attr = async (attr, value) => {
    component[attr] = value;
}

/* *************************************************** */

/* Callback to request REST data from components */
const get_component_data = async (url, query_params, post_params) => {
    query_params.csrf = props.context.csrf
    const url_params = ntopng_url_manager.obj_to_url_params(query_params);
    const top_url = `${http_prefix}/lua/rest/v2/get/asn/get_top_asn.lua?${url_params}`;
    const top_data = await ntopng_utility.http_request(top_url)
    const ts_requests = [];
    top_data?.forEach((el) => {
        const tmp_query = { ...ts_query };
        tmp_query.ts_query = tmp_query.ts_query.replace('$IFID$', props.context.ifid);
        tmp_query.ts_query = tmp_query.ts_query.replace('$ASN$', el.asn);
        tmp_query.tskey = `${el.asn}`;
        tmp_query.ts_unify = true
        ts_requests.push(tmp_query);
    })
    post_params.ts_requests = ts_requests;
    const data_url = `${http_prefix}/lua/pro/rest/v2/get/timeseries/ts_multi.lua?${url_params}`;
    const data = await ntopng_utility.http_post_request(data_url, post_params)
    if (data[0]?.series.length > 0) {
        emptyData.value = false;
        showTitle.value = true;
    } else {
        emptyData.value = true;
        showTitle.value = false;
    }
    return data;
};

const get_extra_params_obj = () => {
    let extra_params = ntopng_url_manager.get_url_object();
    return extra_params;
};

const map_table_def_columns = (columns) => {
    let map_columns = {
        "asname": (value, row) => {
            // value is ASNumber
            // row is the json element
            const asName = row["asname"];

            let return_value = "";

            if (asName.length > 0) {
                return_value += `${row["asname"]}`;
                if (row["asn"]!=0){
                    return_value += `[ <A class='ntopng-external-link' href='https://stat.ripe.net/app/launchpad/S1_${row["asn"]}_C13C31C4C34C9C22C28C20C6C7C26C29C30C14C17C2C21C33C16C10'>RIPEstat <i class='fas fa-external-link-alt fa-sm'></i></A>`;
                    return_value += ` | <A class='ntopng-external-link' href='https://www.peeringdb.com/asn/${row["asn"]}'>PeeringDB <i class='fas fa-external-link-alt fa-sm'></i></A> ]`;
                }
            }
            return return_value;
        },
        "asn": (value, row) => {
            let return_value = row["asn"]
            return return_value;
        },
        "hosts": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
        "seen_since": (value, row) => {
            // `seen_since` might require formatting, e.g., date formatting.
            const formattedDate = ntopng_utility.from_utc_to_server_date_format(value * 1000); // Example date formatting
            return formattedDate;
        },
        "score": (value, row) => {
            // Assuming `score` is a number that might require some formatting.
            return formatterUtils.getFormatter("number")(value);
        },
        "breakdown": (value, row) => {
            return NtopUtils.createBreakdown(value["bytes_sent"], value["bytes_rcvd"], "Sent", "Rcvd")
        },
        "throughput": (value, row) => {
            return formatterUtils.getFormatter("bps")(value);
        },
        "traffic": (value, row) => {
            return formatterUtils.getFormatter("bytes")(value);
        },
        "alerted_flows": (value, row) => {
            return formatterUtils.getFormatter("number")(value);
        },
    };

    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id == "actions") {
            const visible_dict = {
                host: true,
                flows: true,
                exporters_distro: showSankey,
                timeseries: props.context.showTimeseries,
            };
            c.button_def_array.forEach((b) => {
                b.f_map_class = (current_class, row) => {
                    // if is not defined is enabled
                    if (!visible_dict[b.id]) {
                        current_class.push("disabled");
                    }
                    return current_class;
                }
            });
        }
    });

    return columns;
};

/* ************************************** */

function click_button_exporters_distro(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/as_overview.lua?asn=${row["asn"]}`;
}

/* ************************************** */

function click_button_host(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/hosts_stats.lua?asn=${row["asn"]}`;
}

/* ************************************** */

function click_button_flows(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/flows_stats.lua?asn=${row["asn"]}`;
}

/* ************************************** */

function click_button_timeseries(event) {
    const row = event.row;
    window.location.href = `${http_prefix}/lua/as_stats.lua?asn=${row["asn"]}&page=historical`;
}

/* ************************************** */

function on_table_custom_event(event) {
    let events_managed = {
        "click_button_host": click_button_host,
        "click_button_flows": click_button_flows,
        "click_button_exporters_distro": click_button_exporters_distro,
        "click_button_timeseries": click_button_timeseries,
    };
    if (events_managed[event.event_id] == null) {
        return;
    }
    events_managed[event.event_id](event);
}

/* ************************************** */

function columns_sorting(col, r0, r1) {
    if (col != null) {
        if (col.id == "name") {
            return sortingFunctions.sortByName(r0.asname, r1.asname, col.sort);
        } if (col.id == "as_number") {
            return sortingFunctions.sortByNumber(r0.asn, r1.asn, col.sort);
        }else if (col.id == "num_hosts") {
            return sortingFunctions.sortByNumber(r0.num_hosts, r1.num_hosts, col.sort);
        } else if (col.id == "seen_since") {
            return sortingFunctions.sortByNumber(r0.seen_since, r1.seen_since, col.sort);
        } else if (col.id == "avg_host_score") {
            return sortingFunctions.sortByNumber(r0.avg_host_score, r1.avg_host_score, col.sort);
        } else if (col.id == "score") {
            return sortingFunctions.sortByNumber(r0.score, r1.score, col.sort);
        } else if (col.id == "throughput") {
            return sortingFunctions.sortByNumber(r0.throughput, r1.throughput, col.sort);
        } else if (col.id == "traffic") {
            return sortingFunctions.sortByNumber(r0.traffic, r1.traffic, col.sort);
        }
        else if (col.id == "alerted_flows") {
            return sortingFunctions.sortByNumber(r0.alerted_flows, r1.alerted_flows, col.sort);
        }
    }
}
</script>

<template>
    <div class="row g-3 mb-3 mt-0">
        <div class="col-lg-8">
            <DashboardCard :title="_i18n('sites_dashboard.traffic_time_series')" icon="bi bi-graph-up"
                :titleLink="titleLinks.snmp_traffic_time_series" noPadding>
                <div class="sites-dashboard-ts">
                    <DashboardTimeseries v-if="epochBegin && epochEnd"
                        :id="'sites_dashboard_snmp_iface_ts'" :ifid="ifid" :epoch_begin="epochBegin"
                        :epoch_end="epochEnd" :max_width="12" :max_height="4"
                        :params="timeseriesParams" :get_component_data="iface ? undefined : getDeviceTimeseriesData"
                        :csrf="csrf" />
                </div>
            </DashboardCard>
        </div>
        <div class="col-lg-4">
            <DashboardCard
                :title="_i18n(iface ? 'sites_dashboard.interface_information_snmp' : 'sites_dashboard.device_information_snmp')"
                icon="bi bi-info-circle">
                <NoData v-if="!loadingInfo && infoRows.length === 0" :show="true" />
                <dl v-else class="snmp-info-list mb-0">
                    <template v-for="row in infoRows" :key="row.label">
                        <dt>{{ row.label }}</dt>
                        <dd v-html="row.value"></dd>
                    </template>
                </dl>
            </DashboardCard>
        </div>
    </div>

    <div v-if="showAnalysis && !iface" class="row g-3 mb-3">
        <div class="col-lg-12">
            <DashboardCard :title="_i18n('sites_dashboard.snmp_interfaces')" icon="bi bi-diagram-3" noPadding>
                <div class="m-2">
                    <TableWithConfig ref="analysisTableRef" :table_id="'snmp_device_interfaces'" :csrf="csrf"
                        :showLoading="true" :f_map_columns="mapAnalysisColumns" :f_sort_rows="analysisColumnsSorting"
                        :get_extra_params_obj="getAnalysisExtraParams" @rows_loaded="onAnalysisRowsLoaded" />
                </div>
            </DashboardCard>
        </div>
    </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../../../services/context/ntopng_globals_services";
import formatterUtils from "../../../utilities/formatter-utils";
import NtopUtils from "../../../utilities/ntop-utils.js";
import { default as sortingFunctions } from "../../../utilities/sorting-utils.js";
import { default as DashboardCard } from "../dashboard-card.vue";
import { default as NoData } from "../no-data.vue";
import { default as TableWithConfig } from "../../table-with-config.vue";
import { default as DashboardTimeseries } from "../../dashboard-timeseries.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    ifid: { type: String, required: true },
    device: { type: Object, required: true },
    iface: { type: Object, default: null },
    epochBegin: { type: Number, default: null },
    epochEnd: { type: Number, default: null },
    titleLinks: { type: Object, default: () => ({}) },
    csrf: { type: String, default: null },
    /* Shows the per-interface Analysis table below the timeseries/info row.
       Only meaningful at device scope (iface === null): a bare SNMP device
       (no flow exporter) has no other way to list/drill into its interfaces. */
    showAnalysis: { type: Boolean, default: false },
});

const emit = defineEmits(["interfaces-loaded"]);

const SNMP_SYSTEM_IFID = "-1";

const DEVICE_INFO_URL = "/lua/pro/rest/v2/get/snmp/device/info.lua";
const IFACE_INFO_URL = "/lua/pro/rest/v2/get/snmp/interface/info.lua";

const loadingInfo = ref(false);
const deviceInfo = ref(null);
const ifaceInfo = ref(null);

const analysisTableRef = ref(null);

/* Interface admin/oper status codes, shared with page-snmp-interfaces.vue. */
const interface_status = {
    ["1"]: `<span class="text-success">${_i18n("snmp.status_up")}</span>`,
    ["101"]: `<span class="text-success">${_i18n("snmp.status_up_in_use")}</span>`,
    ["2"]: `<span class="text-danger">${_i18n("snmp.status_down")}</span>`,
    ["3"]: _i18n("snmp.testing"),
    ["4"]: _i18n("snmp.status_unknown"),
    ["5"]: _i18n("snmp.status_dormant"),
    ["6"]: _i18n("status_notpresent"),
    ["7"]: `<span class="text-danger">${_i18n("snmp.status_lowerlayerdown")}</span>`,
};

// Timeseries
/* Interface scope uses the per-interface schema. Device scope uses the same
   "top:snmp_if:traffic" / tskey:<device ip> query the real snmp_device_details.lua
   page sends (ranks interfaces of this device by traffic). Its returned series
   are keyed by the fixed metric name ("bytes"), not the ranked if_index, so
   batch.lua's label lookup can never resolve a per-interface name for it --
   getDeviceTimeseriesData() relabels those series client-side after the fetch
   using each series' own ext_label (the interface name, already resolved
   server-side from tags.if_index). */
const timeseriesParams = computed(() => {
    if (props.iface) {
        return {
            post_params: {
                limit: 180,
                version: 4,
                ts_requests: {
                    "$IFID$": {
                        ts_query: `ifid:${SNMP_SYSTEM_IFID},device:${props.device?.id},if_index:${props.iface?.ifindex}`,
                        ts_schema: `snmp_if:traffic`,
                    },
                },
            },
        };
    }
    return {
        post_params: {
            limit: 180,
            version: 4,
            ts_requests: {
                "$IFID$": {
                    ts_query: `ifid:${SNMP_SYSTEM_IFID},device:${props.device?.id}`,
                    ts_schema: `top:snmp_if:traffic`,
                    tskey: props.device?.id,
                },
            },
        },
    };
});

async function getDeviceTimeseriesData(url, query_params, post_params) {
    const data = await ntopng_utility.http_post_request(url, post_params);
    if (data?.results) {
        for (const res of Object.values(data.results)) {
            (res.series || []).forEach((s) => {
                if (s.ext_label) s.name = s.ext_label;
            });
        }
    }
    return data;
}

// Information panel
const infoRows = computed(() => {
    const rows = [];
    const push = (label, value) => {
        if (value !== undefined && value !== null && value !== "") {
            rows.push({ label, value });
        }
    };
    const status = (code) =>
        code != null && code !== "" ? (interface_status[String(code)] || escapeHtml(code)) : null;

    if (props.iface) {
        const info = ifaceInfo.value || {};
        const deviceName = info.device_name
            || (props.device?.name && props.device.name !== props.device?.id ? props.device.name : null);
        push(_i18n("snmp.device_name"), escapeHtml(deviceName));
        push(_i18n("snmp.device_ip"), escapeHtml(info.device_ip || props.device?.id));
        push(_i18n("sites_dashboard.interface_name"), escapeHtml(info.interface_name || props.iface.snmp_ifname));
        push(_i18n("snmp.ifindex"), escapeHtml(info.interface_id ?? props.iface.ifindex));
        push(_i18n("sites_dashboard.interface_type"), escapeHtml(info.type));
        push(_i18n("sites_dashboard.role"), escapeHtml(info.role));
        push(_i18n("admin_status"), status(info.admin_status));
        push(_i18n("sites_dashboard.oper_status"), status(info.interface_status));
        push(_i18n("sites_dashboard.uplink_speed"), formatSpeedValue(info.uplink_speed));
        push(_i18n("sites_dashboard.downlink_speed"), formatSpeedValue(info.downlink_speed));
        push(_i18n("snmp.last_change"), formatLastChange(info.last_change));
        return rows;
    }

    const info = deviceInfo.value || {};
    const deviceName = info.name
        || (props.device?.name && props.device.name !== props.device?.id ? props.device.name : null);
    push(_i18n("snmp.device_name"), escapeHtml(deviceName));
    push(_i18n("snmp.device_ip"), escapeHtml(props.device?.id));
    push(_i18n("model"), escapeHtml(info.model));
    push(_i18n("sites_dashboard.description"), escapeHtml(info.description));
    push(_i18n("location"), escapeHtml(info.location));
    push(_i18n("snmp.contact"), escapeHtml(info.contact));
    push(_i18n("sites_dashboard.uptime"), formatUptime(info.uptime));
    push(_i18n("snmp.snmp_device_last_poll"), formatLastPoll(info.last_poll));
    push(_i18n("sites_dashboard.snmp_interfaces"),
        info.num_interfaces != null ? String(info.num_interfaces) : null);
    push(_i18n("snmp.interfaces_with_errors"),
        info.num_interfaces_with_errors != null ? String(info.num_interfaces_with_errors) : null);
    return rows;
});

const duplex_status = {
    ["1"]: _i18n("unknown"),
    ["2"]: `<span class="text-warning">${_i18n("flow_devices.half_duplex")}</span>`,
    ["3"]: `<span class="text-success">${_i18n("flow_devices.full_duplex")}</span>`,
};

function mapAnalysisColumns(columns) {
    const map_columns = {
        interface_name: (value, row) => {
            const escaped = escapeHtml(value);
            const url = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.device_ip}&snmp_port_idx=${row.interface_id}`;
            return `<a href="${url}">${escaped}</a>`;
        },
        vlan: (value, row) => {
            const vlan_name = row.vlan_name ? `[${row.vlan_name}]` : "";
            return `${value} ${vlan_name}`;
        },
        admin_status: (value) => interface_status[String(value)] || "",
        status: (value) => interface_status[String(value)] || "",
        duplex_status: (value) => duplex_status[String(value)] || "",
        num_macs: (value, row) => {
            if (value > 0) {
                const url = `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?host=${row.device_ip}&snmp_port_idx=${row.interface_id}&page=layer_2`;
                return `<a href="${url}">${value}</a>`;
            }
            return "";
        },
        in_bytes: (value) => value > 0 ? formatterUtils.getFormatter("bytes")(value) : "",
        out_bytes: (value) => value > 0 ? formatterUtils.getFormatter("bytes")(value) : "",
        in_errors: (value) => value > 0 ? formatterUtils.getFormatter("full_number")(value) : "",
        out_errors: (value) => value > 0 ? formatterUtils.getFormatter("full_number")(value) : "",
        in_discards: (value) => value > 0 ? formatterUtils.getFormatter("full_number")(value) : "",
        throughput: (value) => value > 0 ? formatterUtils.getFormatter("bps")(value) : "",
        uplink_speed: (value) => formatterUtils.getFormatter("speed")(value),
        downlink_speed: (value) => formatterUtils.getFormatter("speed")(value),
        last_in_usage: (value) => value > 0 ? formatterUtils.getFormatter("percentage")(value) : "",
        last_out_usage: (value) => value > 0 ? formatterUtils.getFormatter("percentage")(value) : "",
        last_change: (_value, row) => row.last_change_string,
        ip_addr: (value) => {
            const arr = (value || "").split(",").filter(Boolean).map((ip) =>
                `<a href="${http_prefix}/lua/host_details.lua?host=${ip}&mode=restore&ifid=number">${ip}</a>`);
            return NtopUtils.arrayToListString(arr, 2);
        },
    };
    columns.forEach((c) => {
        c.render_func = map_columns[c.data_field];
        if (c.id === "actions") {
            // No configuration button in this embedded, read-only card view.
            c.button_def_array = [];
        }
    });
    return columns;
}

/* Same sorting rules as page-snmp-interfaces.vue's columns_sorting, trimmed
   to the columns actually present in the snmp_device_interfaces table. */
function analysisColumnsSorting(col, r0, r1) {
    if (col != null) {
        const r0_col = r0[col.data.data_field];
        const r1_col = r1[col.data.data_field];
        if (r0_col === r1_col) return sortingFunctions.sortByName(r0.interface_name, r1.interface_name, col ? col.sort : null);
        if (col.id === "interface_name") return sortingFunctions.sortByName(r0_col, r1_col, col.sort);
        const lower_value = -1;
        return sortingFunctions.sortByNumberWithNormalizationValue(r0_col, r1_col, col.sort, lower_value);
    }
    return sortingFunctions.sortByName(r0.interface_name, r1.interface_name, col ? col.sort : null);
}

/* Scopes the table to this device: snmp/metric/interfaces.lua's `host` filter. */
function getAnalysisExtraParams() {
    return { host: props.device?.id };
}

function onAnalysisRowsLoaded(res) {
    const rows = Array.isArray(res?.rows) ? res.rows : [];
    emit("interfaces-loaded", rows);
}

// Fetch
/* Fetches the info panel for the current scope: the interface info REST when an
   interface is selected, the device info REST otherwise. */
async function loadInfo() {
    if (!props.device?.id) return;
    loadingInfo.value = true;
    try {
        if (props.iface) {
            const p = ntopng_url_manager.obj_to_url_params({
                host: props.device.id,
                snmp_port_idx: props.iface.ifindex,
            });
            ifaceInfo.value = await ntopng_utility.http_request(`${http_prefix}${IFACE_INFO_URL}?${p}`) || null;
        } else {
            const p = ntopng_url_manager.obj_to_url_params({ host: props.device.id });
            deviceInfo.value = await ntopng_utility.http_request(`${http_prefix}${DEVICE_INFO_URL}?${p}`) || null;
        }
    } catch (err) {
        console.error("Error retrieving SNMP info:", err);
        if (props.iface) ifaceInfo.value = null; else deviceInfo.value = null;
    }
    loadingInfo.value = false;
}

/* uplink/downlink speed (bit/s) from the interface info REST, shown as two
   separate rows. */
function formatSpeedValue(v) {
    const n = Number(v);
    if (!n) return null;
    return formatterUtils.getFormatter("speed")(n);
}

/* info.lua returns last_change already as "seconds since last state change". */
function formatLastChange(v) {
    const secs = Number(v);
    if (!Number.isFinite(secs) || secs <= 0) return null;
    return NtopUtils.secondsToTime(secs);
}

/* sysUpTime, reported in seconds by the device info REST. */
function formatUptime(v) {
    const secs = Number(v);
    if (!Number.isFinite(secs) || secs <= 0) return null;
    return NtopUtils.secondsToTime(secs);
}

/* last_poll_time: render as "time since". Absolute epochs (large values) become
   now - value; anything already relative is shown as-is. */
function formatLastPoll(v) {
    const t = Number(v);
    if (!Number.isFinite(t) || t <= 0) return null;
    const now = Math.floor(Date.now() / 1000);
    const elapsed = t > 1000000000 ? Math.max(now - t, 0) : t;
    return NtopUtils.secondsToTime(elapsed);
}

function escapeHtml(v) {
    if (v === undefined || v === null || v === "") return v;
    return String(v)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}

async function refresh() {
    await loadInfo();
    if (props.showAnalysis && !props.iface) analysisTableRef.value?.refresh_table();
}

watch(() => [props.device?.id, props.iface?.ifindex], () => { refresh(); });
onMounted(() => { refresh(); });

defineExpose({ refresh, load: refresh });
</script>

<style scoped>
.snmp-info-list {
    display: grid;
    grid-template-columns: auto 1fr;
    column-gap: 1rem;
    row-gap: 0.4rem;
    margin: 0;
}

.snmp-info-list dt {
    font-weight: 600;
    color: var(--ntop-muted-text-color);
    white-space: nowrap;
}

.snmp-info-list dd {
    margin: 0;
    color: var(--ntop-text-color);
    word-break: break-word;
}
</style>

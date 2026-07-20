<template>
    <div v-if="iface" class="row g-3 mb-3 mt-0">
        <div class="col-lg-8">
            <DashboardCard :title="_i18n('sites_dashboard.traffic_time_series')" icon="bi bi-graph-up"
                :titleLink="titleLinks.snmp_traffic_time_series" noPadding>
                <div class="sites-dashboard-ts">
                    <DashboardTimeseries v-if="epochBegin && epochEnd" ref="ifaceChartRef"
                        :id="'sites_dashboard_snmp_iface_ts'" :ifid="ifid" :epoch_begin="epochBegin"
                        :epoch_end="epochEnd" :max_width="12" :max_height="4"
                        :params="timeseriesParams" :csrf="csrf" />
                </div>
            </DashboardCard>
        </div>
        <div class="col-lg-4">
            <DashboardCard :title="_i18n('sites_dashboard.interface_information_snmp')" icon="bi bi-info-circle">
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

    <div v-else class="row g-3 mb-3 mt-0">
        <div class="col-lg-6">
            <DashboardCard :title="_i18n('sites_dashboard.device_information_snmp')" icon="bi bi-info-circle">
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
</template>

<script setup>
import { ref, computed, watch } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../../../services/context/ntopng_globals_services";
import formatterUtils from "../../../utilities/formatter-utils";
import NtopUtils from "../../../utilities/ntop-utils.js";
import { default as DashboardCard } from "../dashboard-card.vue";
import { default as NoData } from "../no-data.vue";
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
});

const SNMP_SYSTEM_IFID = "-1";

const DEVICE_INFO_URL = "/lua/pro/rest/v2/get/snmp/device/info.lua";
const IFACE_INFO_URL = "/lua/pro/rest/v2/get/snmp/interface/info.lua";

const loadingInfo = ref(false);
const deviceInfo = ref(null);
const ifaceInfo = ref(null);

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
const timeseriesParams = computed(() => ({
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
}));

// Information panel
/* Builds the definition-list rows for the panel from whichever info REST
   applies to the current scope. Only rows with an actual value are emitted, so
   fields a given device does not report are silently skipped. */
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
        push(_i18n("speed"), formatSpeed(info.downlink_speed, info.uplink_speed));
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

/* uplink/downlink speeds (bit/s) from the interface info REST. Collapsed to a
   single value when both match (the common case), otherwise shown as
   "↓ downlink / ↑ uplink". */
function formatSpeed(downlink, uplink) {
    const fmt = formatterUtils.getFormatter("speed");
    const d = Number(downlink) || 0;
    const u = Number(uplink) || 0;
    if (!d && !u) return null;
    if (d === u) return fmt(d);
    return `↓ ${fmt(d)} / ↑ ${fmt(u)}`;
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
}

/* Refetch when the device or the selected interface changes (scope switch or
   drill-down both flip which REST is queried). */
watch(() => [props.device?.id, props.iface?.ifindex], () => { refresh(); });

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

<!--
  (C) 2026 - ntop.org
  Traffic detail panel shared by the exporter view (all interfaces) and the
  interface drill-down (single ifIndex) of the sites dashboard. Owns the
  interfaces table (exporter scope only), the KPI-feeding overview fetches
  (L7/L4 protocol breakdown, top local talkers/remote destinations) and the
  traffic time series, for whichever scope is currently selected.

  Props:
    - ifid: String — ambient interface id (for the timeseries component)
    - exporter: Object (required) — the selected exporter
    - iface: Object|null — the selected interface, or null for exporter scope
    - siteId: String|Number|null — the selected site, forwarded to the live flows
        count probe (flow/active_list.lua defaults its site filter to site 0,
        so it must be passed explicitly for every non-default site)
    - showInterfaces: Boolean — at exporter scope, show the interfaces table instead
        of the overview cards (the "Interfaces" tab vs. the default "Traffic Analysis"
        tab). Ignored at interface scope, which always shows the overview.
    - epochBegin/epochEnd: Number|null — historical/live window driving every fetch
    - showHistoricalWidgets: Boolean — ClickHouse-backed vs. live aggregation
    - overviewTableColClass: String — bootstrap col class for the talkers/destinations cards
    - titleLinks: Object — { traffic_time_series, top_l7_proto, top_l4_proto,
        top_local_talkers, top_remote_destinations, exporter_interfaces }
    - csrf: String — passed through to DashboardTimeseries
  Emits:
    - select-interface(iface): an interfaces-table row was clicked (exporter scope only)
    - counts-loaded({ flows, hosts }): live flows/active hosts KPI counts refreshed
    - interfaces-loaded(interfaces): exporter's interfaces list (re)fetched, for the
      parent's KPI cards (SNMP status, current traffic, exporter display name)
  Exposes (via ref):
    - refresh(): re-fetches interfaces (if exporter scope) + overview + counts
                 for the current exporter/iface props, without changing selection
    - load(): initial fetch, same as refresh() (alias for readability at call sites)
    - refreshOverview(): re-fetches only the overview cards (L7/L4/talkers/destinations),
                 for date/time range picker changes where interfaces/counts are unaffected
    - refreshCounts(): re-fetches only the Flows/Active Hosts KPI counts (alias for
                 loadExporterCounts), for when just those need a fresh value
                 (e.g. the parent's Live Flows/Hosts tab being opened)
-->
<template>
    <template v-if="!iface && showInterfaces">
        <DashboardCard :title="_i18n('sites_dashboard.interfaces')" icon="bi bi-ethernet"
            :titleLink="titleLinks.exporter_interfaces" noPadding>
            <NoData v-if="!loadingInterfaces && exporterInterfaces.length === 0" :show="true" />
            <div v-else class="sites-dashboard-clickable-table"
                @click="(ev) => onRowClick(ev, exporterInterfaces, (row) => emit('select-interface', row))">
                <BootstrapTable :id="'sites_dashboard_exporter_interfaces'" :columns="interfaceColumns"
                    :rows="exporterInterfaces" :print_html_column="printInterfaceColumn"
                    :print_html_row="printInterfaceRow" />
            </div>
        </DashboardCard>
    </template>

    <div v-if="iface || !showInterfaces" class="row g-3 mb-3 mt-0">
        <div class="col-lg-8">
            <DashboardCard :title="_i18n('sites_dashboard.traffic_time_series')" icon="bi bi-graph-up"
                :titleLink="titleLinks.traffic_time_series" noPadding>
                <div class="sites-dashboard-ts">
                    <DashboardTimeseries v-if="epochBegin && epochEnd" ref="ifaceChartRef"
                        :id="'sites_dashboard_iface_ts'" :ifid="ifid" :epoch_begin="epochBegin"
                        :epoch_end="epochEnd" :max_width="12" :max_height="4"
                        :params="timeseriesParams" :csrf="csrf" />
                </div>
            </DashboardCard>
        </div>
        <div class="col-lg-4">
            <DashboardCard :title="_i18n('sites_dashboard.top_l7_proto')" icon="bi bi-app-indicator"
                :titleLink="titleLinks.top_l7_proto" noPadding>
                <NoData v-if="!loadingL7 && topL7.length === 0" :show="true" />
                <BootstrapTable v-else :id="'sites_dashboard_top_l7'" :columns="topProtoColumns"
                    :rows="topL7" :print_html_column="printProtoColumn"
                    :print_html_row="printProtoRow" />
            </DashboardCard>
        </div>
    </div>
    <div v-if="iface || !showInterfaces" class="row g-3 mb-3">
        <div v-if="showHistoricalWidgets" class="col-lg-4">
            <DashboardCard :title="_i18n('sites_dashboard.top_l4_proto')" icon="bi bi-diagram-2"
                :titleLink="titleLinks.top_l4_proto" noPadding>
                <NoData v-if="!loadingL4 && topL4.length === 0" :show="true" />
                <BootstrapTable v-else :id="'sites_dashboard_top_l4'" :columns="topProtoColumns"
                    :rows="topL4" :print_html_column="printProtoColumn"
                    :print_html_row="printProtoRow" />
            </DashboardCard>
        </div>
        <div :class="overviewTableColClass">
            <DashboardCard :title="_i18n('sites_dashboard.top_local_talkers')" icon="bi bi-laptop"
                :titleLink="titleLinks.top_local_talkers" noPadding>
                <NoData v-if="!loadingTalkers && topTalkers.length === 0" :show="true" />
                <BootstrapTable v-else :id="'sites_dashboard_top_talkers'" :columns="topHostColumns"
                    :rows="topTalkers" :print_html_column="printHostColumn"
                    :print_html_row="printHostRow" />
            </DashboardCard>
        </div>
        <div :class="overviewTableColClass">
            <DashboardCard :title="_i18n('sites_dashboard.top_remote_destinations')"
                icon="bi bi-globe" :titleLink="titleLinks.top_remote_destinations" noPadding>
                <NoData v-if="!loadingDestinations && topDestinations.length === 0" :show="true" />
                <BootstrapTable v-else :id="'sites_dashboard_top_destinations'"
                    :columns="topHostColumns" :rows="topDestinations"
                    :print_html_column="printHostColumn" :print_html_row="printHostRow" />
            </DashboardCard>
        </div>
    </div>
</template>

<script setup>
import { ref, computed } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../../../services/context/ntopng_globals_services";
import formatterUtils from "../../../utilities/formatter-utils";
import NtopUtils from "../../../utilities/ntop-utils.js";
import { onRowClick } from "../../../utilities/sites-dashboard-utils.js";
import { default as DashboardCard } from "../dashboard-card.vue";
import { default as NoData } from "../no-data.vue";
import { default as BootstrapTable } from "../../bootstrap-table.vue";
import { default as DashboardTimeseries } from "../../dashboard-timeseries.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
    ifid: { type: String, required: true },
    exporter: { type: Object, required: true },
    iface: { type: Object, default: null },
    siteId: { type: [String, Number], default: null },
    showInterfaces: Boolean,
    epochBegin: { type: Number, default: null },
    epochEnd: { type: Number, default: null },
    showHistoricalWidgets: Boolean,
    overviewTableColClass: { type: String, default: "col-lg-4" },
    titleLinks: { type: Object, default: () => ({}) },
    csrf: { type: String, default: null },
});

const emit = defineEmits(["select-interface", "counts-loaded", "interfaces-loaded"]);

let countsRequestGeneration = 0;

const loadingInterfaces = ref(false);
const exporterInterfaces = ref([]);

const loadingL7 = ref(false);
const loadingL4 = ref(false);
const loadingTalkers = ref(false);
const loadingDestinations = ref(false);

const topL7 = ref([]);
const topL4 = ref([]);
const topTalkers = ref([]);
const topDestinations = ref([]);

const interfaceColumns = [
    { id: "snmp_ifname", label: _i18n("sites_dashboard.interface") },
    { id: "in_bytes", label: _i18n("sites_dashboard.in_bytes") },
    { id: "out_bytes", label: _i18n("sites_dashboard.out_bytes") },
];
function printInterfaceColumn(col) { return col.label; }
function printInterfaceRow(col, row) {
    if (col.id === "in_bytes" || col.id === "out_bytes") return formatBytes(row[col.id]);
    if (col.id === "snmp_ifname") return `<a href="#" class="sites-dashboard-row-link">${row[col.id]}</a>`;
    return row[col.id];
}

const topProtoColumns = [
    { id: "label", label: _i18n("application") },
    { id: "value", label: _i18n("traffic") },
    { id: "percentage", label: "" },
];
function printProtoColumn(col) { return col.label; }
function printProtoRow(col, row) {
    if (col.id === "value") return formatBytes(row.value);
    if (col.id === "percentage") return formatPercentage(row.percentage);
    return row.label;
}

const topHostColumns = [
    { id: "label", label: _i18n("sites_dashboard.host") },
    { id: "bytes", label: _i18n("traffic") },
];
function printHostColumn(col) { return col.label; }
function printHostRow(col, row) {
    if (col.id === "bytes") return formatBytes(row.bytes);
    return row.label;
}

function formatBytes(v) {
    return formatterUtils.getFormatter("bytes")(v);
}

function formatPercentage(pct) {
    return NtopUtils.createProgressBar(pct || 0);
}

/* Maps a raw {label, value}[] top-N list into rows carrying each entry's
   share of the total, rendered as a progress bar in the table's third column. */
function withPercentages(list) {
    const total = list.reduce((sum, e) => sum + (e.value || 0), 0);
    return list.map((e) => ({
        ...e,
        percentage: total > 0 ? (e.value / total) * 100 : 0,
    }));
}

/* The exporter's own collector interface (interface_id, from getAllExportersList())
   is not necessarily the page's ambient ifid: an exporter can be collected on an
   interface other than the one currently selected in the top navbar, and its
   flowdev/flowdev_port timeseries are only recorded under that collector ifid. */
const exporterTimeseriesIfid = computed(() => String(props.exporter?.interface_id ?? props.ifid));

const timeseriesParams = computed(() => {
    if (props.iface) {
        return {
            post_params: {
                limit: 180,
                version: 4,
                ts_requests: {
                    "$IFID$": {
                        ts_query: `ifid:${exporterTimeseriesIfid.value},device:${props.exporter?.id},port:${props.iface.ifindex}`,
                        ts_schema: `flowdev_port:traffic`,
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
                    ts_query: `ifid:${exporterTimeseriesIfid.value},device:${props.exporter?.id}`,
                    ts_schema: `flowdev:traffic`,
                },
            },
        },
    };
});

async function loadExporterInterfaces() {
    loadingInterfaces.value = true;
    try {
        const url_params = ntopng_url_manager.obj_to_url_params({
            start: 0,
            length: 10,
            map_search: "",
            visible_columns: "actions,snmp_ifname,in_bytes,out_bytes,ratio",
            ip: props.exporter.id,
            exporter_source_id: props.exporter.exporter_source_id,
            probe_source_id: props.exporter.probe_source_id,
            probe_ip: props.exporter.id,
        });
        const url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporters_interfaces.lua?${url_params}`;
        const data = await ntopng_utility.http_request(url);
        exporterInterfaces.value = data || [];
    } catch (err) {
        console.error("Error retrieving exporter interfaces:", err);
        exporterInterfaces.value = [];
    }
    loadingInterfaces.value = false;
    emit("interfaces-loaded", exporterInterfaces.value);
}

/* Live flows/hosts counts for the "Flows" and "Active Hosts" KPI cards, owned
   by the parent (they render outside this component's slot). Flows count is
   scoped to the exporter and, at interface scope, to flows whose SNMP in OR
   out index is the selected ifIndex (ifIdx). Note host/active_list.lua only
   honours deviceIP, so the Active Hosts KPI stays exporter-scoped. */
async function loadExporterCounts() {
    const generation = ++countsRequestGeneration;
    const iface_filter = props.iface ? { ifIdx: props.iface.ifindex } : {};
    const site_filter = props.siteId != null ? { site_id: props.siteId } : {};

    const flows_params = ntopng_url_manager.obj_to_url_params({
        ifid: exporterTimeseriesIfid.value,
        start: 0,
        length: 1,
        map_search: "",
        visible_columns: "actions,first_seen,last_seen,duration,protocol,score,qoe,flow,cli_asn_asnmode_disabled,srv_asn_asnmode_disabled,throughput,bytes,info,flow_exporter,in_index,out_index",
        deviceIP: props.exporter.id,
        ...site_filter,
        ...iface_filter,
    });
    const hosts_params = ntopng_url_manager.obj_to_url_params({
        ifid: exporterTimeseriesIfid.value,
        start: 0,
        length: 1,
        map_search: "",
        visible_columns: "actions,ip_address,hostname,num_flows,alerts,score,first_seen,traffic_breakdown,throughput,bytes",
        deviceIP: props.exporter.id,
        ...iface_filter,
    });

    let flows = null;
    let hosts = null;

    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/rest/v2/get/flow/active_list.lua?${flows_params}`, undefined, undefined, true
        );
        flows = data?.recordsTotal ?? null;
    } catch (err) {
        console.error("Error retrieving live flows count:", err);
    }

    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/rest/v2/get/host/active_list.lua?${hosts_params}`, undefined, undefined, true
        );
        hosts = data?.recordsTotal ?? null;
    } catch (err) {
        console.error("Error retrieving live hosts count:", err);
    }

    // A newer loadExporterCounts() call (from navigating on) has since
    // started -- its response, whenever it lands, is the one that should win.
    if (generation !== countsRequestGeneration) return;
    emit("counts-loaded", { flows, hosts });
}

/* Refetches the overview cards (L7/L4 protocol breakdown, top local talkers,
   top remote destinations) for the current exporter/iface props and the
   current [epochBegin, epochEnd] window. */
async function loadOverview() {
    if (props.showHistoricalWidgets) {
        await loadOverviewHistorical();
    } else {
        await loadOverviewLive();
    }
}

// Live overview: aggregates the active in-memory flows exported by this exporter
// (deviceIP) through aggregated_live_flows.lua, grouped by application protocol,
// client and server, sorted by traffic.
async function loadOverviewLive() {
    // Top L4: historical-only, cleared in live.
    topL4.value = [];
    loadingL4.value = false;

    const base_params = {
        ifid: exporterTimeseriesIfid.value,
        deviceIP: props.exporter.id,
        sort: "tot_traffic",
        order: "desc",
        start: 0,
        length: 10,
        // ifIdx matches flows whose SNMP in OR out index is this interface.
        // Passing inIfIdx+outIfIdx together would AND them (in==idx AND out==idx),
        // which is almost never true and would leave interface-scoped tables empty.
        ...(props.iface ? { ifIdx: props.iface.ifindex } : {}),
    };

    const fetchAggregated = async (criteria) => {
        const url_params = ntopng_url_manager.obj_to_url_params({
            ...base_params,
            aggregation_criteria: criteria,
        });
        const rows = await ntopng_utility.http_request(
            `${http_prefix}/lua/rest/v2/get/flow/aggregated_live_flows.lua?${url_params}`
        );
        return Array.isArray(rows) ? rows : [];
    };

    loadingL7.value = true;
    loadingTalkers.value = true;
    loadingDestinations.value = true;

    try {
        const rows = await fetchAggregated("application_protocol");
        topL7.value = withPercentages(rows.map((r) => ({
            label: r.application?.label ?? String(r.application?.id ?? ""),
            value: Number(r.tot_traffic) || 0,
        })));
    } catch (err) {
        console.error("Error retrieving live top L7 protocols:", err);
        topL7.value = [];
    }
    loadingL7.value = false;

    try {
        const rows = await fetchAggregated("client");
        topTalkers.value = rows.map((r) => ({
            ip: r.client?.ip,
            label: r.client?.label || r.client?.ip || "",
            bytes: Number(r.tot_traffic) || 0,
        }));
    } catch (err) {
        console.error("Error retrieving live top local talkers:", err);
        topTalkers.value = [];
    }
    loadingTalkers.value = false;

    try {
        const rows = await fetchAggregated("server");
        topDestinations.value = rows.map((r) => ({
            ip: r.server?.ip,
            label: r.server?.label || r.server?.ip || "",
            bytes: Number(r.tot_traffic) || 0,
        }));
    } catch (err) {
        console.error("Error retrieving live top remote destinations:", err);
        topDestinations.value = [];
    }
    loadingDestinations.value = false;
}

// Historical overview (ClickHouse)
async function loadOverviewHistorical() {
    if (!props.epochBegin || !props.epochEnd) return;

    const common_params = {
        ifid: props.ifid,
        epoch_begin: props.epochBegin,
        epoch_end: props.epochEnd,
        ...(props.iface
            ? { snmp_interface: `${props.exporter.id}_${props.iface.ifindex};eq` }
            : { exporter_ip: `${props.exporter.id};eq` }),
    };

    loadingL7.value = true;
    loadingL4.value = true;
    loadingTalkers.value = true;
    loadingDestinations.value = true;

    const l7_params = ntopng_url_manager.obj_to_url_params({
        ...common_params,
        chart_id: "top_l7_proto",
        ts_schema: "host:traffic",
        query_preset: "protos",
        detail_view: "flows",
        length: 10,
        version: 4,
        ts_query: `ifid:${props.ifid}`,
        report_template: "flow_exporters",
    });
    const l4_params = ntopng_url_manager.obj_to_url_params({
        ...common_params,
        chart_id: "top_l4_proto",
        ts_schema: "host:traffic",
        query_preset: "protos",
        detail_view: "flows",
        length: 10,
        version: 4,
        ts_query: `ifid:${props.ifid}`,
        report_template: "flow_exporters",
    });
    const talkers_params = ntopng_url_manager.obj_to_url_params({
        ...common_params,
        start: 0,
        length: 10,
        query_preset: "top_local_talkers",
        aggregated: true,
        report_template: "flow_exporters",
    });
    const destinations_params = ntopng_url_manager.obj_to_url_params({
        ...common_params,
        start: 0,
        length: 10,
        query_preset: "top_remote_destinations",
        aggregated: true,
        report_template: "flow_exporters",
    });

    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/pro/rest/v2/get/db/charts/top_l7_proto.lua?${l7_params}`
        );
        topL7.value = withPercentages((data || []).map((e) => ({ label: e.label, value: e.value })));
    } catch (err) {
        console.error("Error retrieving top L7 protocols:", err);
        topL7.value = [];
    }
    loadingL7.value = false;

    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/pro/rest/v2/get/db/charts/top_l4_proto.lua?${l4_params}`
        );
        topL4.value = withPercentages((data || []).map((e) => ({ label: e.label, value: e.value })));
    } catch (err) {
        console.error("Error retrieving top L4 protocols:", err);
        topL4.value = [];
    }
    loadingL4.value = false;

    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/pro/rest/v2/get/db/historical_db_search.lua?${talkers_params}`
        );
        topTalkers.value = (data?.records || []).map((r) => ({
            ip: r.ip?.ip ?? r.ip?.value,
            label: r.ip?.label || r.ip?.name || r.ip?.ip || r.HOST_LABEL,
            bytes: Number(r.total_bytes) || 0,
        }));
    } catch (err) {
        console.error("Error retrieving top local talkers:", err);
        topTalkers.value = [];
    }
    loadingTalkers.value = false;

    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/pro/rest/v2/get/db/historical_db_search.lua?${destinations_params}`
        );
        topDestinations.value = (data?.records || []).map((r) => ({
            ip: r.ip?.ip ?? r.ip?.value,
            label: r.ip?.label || r.ip?.name || r.ip?.ip || r.country?.label,
            bytes: Number(r.total_bytes) || 0,
        }));
    } catch (err) {
        console.error("Error retrieving top remote destinations:", err);
        topDestinations.value = [];
    }
    loadingDestinations.value = false;
}

/* Fetches everything this component owns for the current props: the
   interfaces list (exporter scope only), the overview cards and the KPI
   counts. Exposed so the parent can trigger it on selection and on the
   refresh button. */
async function refresh() {
    const tasks = [loadOverview(), loadExporterCounts()];
    if (!props.iface) tasks.push(loadExporterInterfaces());
    await Promise.all(tasks);
}

defineExpose({ refresh, load: refresh, refreshOverview: loadOverview, refreshCounts: loadExporterCounts });
</script>

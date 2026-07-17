<!-- (C) 2026 - ntop.org -->
<template>
    <div class="sites-dashboard d-flex">
        <TreeNavSidebar ref="sidebar" :title="_i18n('sites_dashboard.sites')"
            :search-placeholder="_i18n('sites_dashboard.search_placeholder')" :load-children="loadSidebarChildren"
            :selected-id="selectedNodeId" :sticky-top="'calc(3rem + 0.5rem)'" @on_select="handleSidebarSelect" />

        <div class="sites-dashboard-main flex-grow-1 min-w-0">
            <div class="sites-dashboard-topbar d-flex align-items-center flex-wrap">
                <BreadcrumbNav :items="breadcrumbItems" @on_select="handleBreadcrumbSelect" />
                <div v-if="selectedExporter" class="ms-auto d-flex align-items-center gap-2">
                    <a v-if="showHistoricalWidgets && historicalFlowsUrl" :href="historicalFlowsUrl" target="_blank"
                        class="btn btn-sm btn-primary sites-dashboard-flows-btn">
                        <i class="fas fa-external-link-alt me-1"></i>{{ _i18n('sites_dashboard.historical_flows') }}
                    </a>
                    <DateTimeRangePicker v-if="isClickHouseEnabled" :id="DATE_PICKER_ID"
                        class="sites-dashboard-date-picker" ref="date_time_picker"
                        @epoch_change="on_epoch_change" :custom_time_interval_list="time_preset_list" />
                    <span v-else class="sites-dashboard-live-pill">
                        <i class="fa-solid fa-circle fa-2xs text-danger me-1"></i>{{ _i18n('show_alerts.presets.live') }}
                    </span>
                    <button type="button" class="btn btn-sm btn-outline-secondary sites-dashboard-refresh-btn"
                        :title="_i18n('refresh')" @click="refreshCurrentView">
                        <i class="fas fa-sync"></i>
                    </button>
                </div>
            </div>

            <div class="sites-dashboard-body">
                <!-- Title row: current node icon + label + name, with a single
                     subtitle line for whatever secondary context applies -->
                <div class="d-flex align-items-center flex-wrap mb-3">
                    <h4 class="mb-0 d-flex align-items-center flex-wrap">
                        <i class="me-2" :class="titleIcon"></i>
                        <small v-if="titleLabel" class="sites-dashboard-title-label me-1">{{ titleLabel }}:</small>
                        {{ titleName }}
                        <small v-if="titleSubtitle" class="sites-dashboard-subtitle ms-2">{{ titleSubtitle }}</small>
                    </h4>
                </div>

                <!-- KPI row: badge-card component in "simple" mode,
                     with a small icon square, label, and value -->
                <div class="row g-3 mb-3">
                    <div v-for="kpi in kpiCards" :key="kpi.key" class="col-6 col-md-3 col-lg">
                        <BadgeCard simple :icon="kpi.icon" :color="kpi.color"
                            :label="_i18n(kpi.labelI18n)" :value="kpi.value" :sub="kpi.sub" />
                    </div>
                </div>

                <!-- Tab pills: section switcher for the currently selected node -->
                <div class="mb-3">
                    <NavbarTabs :tabs="tabs" :active_tab_id="activeTab" @on_click="switchTab" />
                </div>

                <!-- Overview: traffic time series + L7/L4 protocol breakdown + top talkers/destinations.
                     Shared by the exporter view (all interfaces) and the interface drill-down
                     (single ifIndex) — both feed the same refs via loadExporterOverview(). -->
                <template v-if="(activeTab === 'exporter_interfaces' && selectedExporter && !selectedInterface) || (activeTab === 'traffic_analysis' && selectedInterface)">
                    <div class="row g-3 mb-3">
                        <div class="col-lg-8">
                            <DashboardCard :title="_i18n('sites_dashboard.traffic_time_series')" icon="bi bi-graph-up"
                                :titleLink="titleLinks.traffic_time_series" noPadding>
                                <div class="sites-dashboard-ts">
                                    <DashboardTimeseries v-if="ifaceEpochBegin && ifaceEpochEnd" ref="ifaceChartRef"
                                        :id="'sites_dashboard_iface_ts'" :ifid="ifid" :epoch_begin="ifaceEpochBegin"
                                        :epoch_end="ifaceEpochEnd" :max_width="12" :max_height="4"
                                        :params="ifaceTimeseriesParams" :csrf="props.context?.csrf" />
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
                    <div class="row g-3 mb-3">
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

                <DashboardCard v-if="activeTab === 'networks'" :title="_i18n('sites_dashboard.networks')"
                    icon="bi bi-diagram-3-fill" :titleLink="titleLinks.networks" noPadding>
                    <NoData v-if="!loadingHierarchy && networks.length === 0" :show="true" />
                    <BootstrapTable v-else :id="'sites_dashboard_networks'" :columns="networkColumns"
                        :rows="networks" :print_html_column="printNetworkColumn"
                        :print_html_row="printNetworkRow" />
                </DashboardCard>

                <DashboardCard v-if="activeTab === 'exporters'" :title="_i18n('sites_dashboard.exporters')"
                    icon="bi bi-hdd-network" :titleLink="titleLinks.exporters" noPadding>
                    <NoData v-if="!loadingHierarchy && exporters.length === 0" :show="true" />
                    <div v-else class="sites-dashboard-clickable-table"
                        @click="(ev) => onRowClick(ev, exporters, handleSelectExporter)">
                        <BootstrapTable :id="'sites_dashboard_exporters'" :columns="exporterColumns"
                            :rows="exporters" :print_html_column="printExporterColumn"
                            :print_html_row="printExporterRow" />
                    </div>
                </DashboardCard>

                <DashboardCard v-if="activeTab === 'exporter_interfaces' && selectedExporter"
                    :title="_i18n('sites_dashboard.interfaces')" icon="bi bi-ethernet"
                    :titleLink="titleLinks.exporter_interfaces" noPadding>
                    <NoData v-if="!loadingInterfaces && exporterInterfaces.length === 0" :show="true" />
                    <div v-else class="sites-dashboard-clickable-table"
                        @click="(ev) => onRowClick(ev, exporterInterfaces, (iface) => handleSelectInterface(iface, selectedExporter))">
                        <BootstrapTable :id="'sites_dashboard_exporter_interfaces'"
                            :columns="interfaceColumns" :rows="exporterInterfaces"
                            :print_html_column="printInterfaceColumn" :print_html_row="printInterfaceRow" />
                    </div>
                </DashboardCard>

                <div v-if="!selectedSite && !selectedExporter && !selectedInterface" class="sites-dashboard-empty">
                    <NoData :show="true" />
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, computed, onBeforeMount } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import { default as TreeNavSidebar } from "./components/tree-nav-sidebar.vue";
import { default as BreadcrumbNav } from "./components/breadcrumb-nav.vue";
import { default as DashboardCard } from "./components/dashboard-card.vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { default as NoData } from "./components/no-data.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as BadgeCard } from "./badge-card.vue";
import { default as DashboardTimeseries } from "./dashboard-timeseries.vue";
import { default as BootstrapTable } from "./bootstrap-table.vue";
import NtopUtils from "../utilities/ntop-utils.js";

const _i18n = (t) => i18n(t);

const DEFAULT_SITE_ID = "0";
const DATE_PICKER_ID = "sites_dashboard_date_picker";

/* Title-link URLs for each card. networks/exporters/exporter_interfaces are
   still placeholders - fill in with the final destination URLs.
   traffic_time_series is built dynamically per-scope in buildTimeseriesUrl(). */
const CARD_LINKS = {
    networks: { url: "" },
    exporters: { live_url: `${http_prefix}/`, historical_url: `${http_prefix}/` },
    exporter_interfaces: { live_url: `${http_prefix}/`, historical_url: `${http_prefix}/` },
};

const props = defineProps({
    context: Object,
});

const ifid = String(props.context?.ifid ?? 0);

const isClickHouseEnabled = computed(() => !!props.context?.isClickhouseEnabled);

const SECONDS_ONE_DAY = 24 * 60 * 60;
const SECONDS_LIVE_TS_WINDOW = 60 * 60;

// Picker presets. Shown only when ClickHouse is enabled; otherwise the page is
// live-only and renders a static Live badge instead of the picker.
const time_preset_list = [
    { value: "live", label: _i18n("show_alerts.presets.live"), icon: "fa-solid fa-circle fa-2xs text-danger", currently_active: false },
    { value: "hour", label: _i18n("show_alerts.presets.hour"), currently_active: true },
    { value: "6_hours", label: _i18n("show_alerts.presets.6_hours"), currently_active: false },
    { value: "day", label: _i18n("show_alerts.presets.day"), currently_active: false },
    { value: "week", label: _i18n("show_alerts.presets.week"), currently_active: false },
    { value: "month", label: _i18n("show_alerts.presets.month"), currently_active: false },
    { value: "custom", label: _i18n("show_alerts.presets.custom"), currently_active: false, disabled: true },
];

function setLiveEpochWindow() {
    const now = Math.floor(Date.now() / 1000);
    ifaceEpochEnd.value = now;
    ifaceEpochBegin.value = now - SECONDS_LIVE_TS_WINDOW;
}

function ensureEpochWindow() {
    if (ifaceEpochBegin.value && ifaceEpochEnd.value) return;
    if (isLive.value) {
        setLiveEpochWindow();
    } else {
        const now = Math.floor(Date.now() / 1000);
        ifaceEpochEnd.value = now;
        ifaceEpochBegin.value = now - SECONDS_ONE_DAY;
    }
}

const sidebar = ref(null);

const selectedSite = ref(null);
const selectedExporter = ref(null);
const selectedInterface = ref(null);
const activeTab = ref("networks");

const selectedAncestors = ref([]);

const loadingHierarchy = ref(false);
const loadingInterfaces = ref(false);

const networks = ref([]);
const sites = ref([]);
const exporters = ref([]);
const exporterInterfaces = ref([]);

/* Exporter overview state: L7/L4 protocol breakdown, top local talkers/remote
   destinations and the traffic time series, all scoped to the currently
   selected exporter and driven by the top-right date/time range picker. */
const ifaceEpochBegin = ref(null);
const ifaceEpochEnd = ref(null);

const loadingL7 = ref(false);
const loadingL4 = ref(false);
const loadingTalkers = ref(false);
const loadingDestinations = ref(false);

const topL7 = ref([]);
const topL4 = ref([]);
const topTalkers = ref([]);
const topDestinations = ref([]);

const liveFlowsCount = ref(null);
const liveHostsCount = ref(null);

const isLive = ref(!props.context?.isClickhouseEnabled);
const showHistoricalWidgets = computed(() => isClickHouseEnabled.value && !isLive.value);

/* L7/talkers/destinations render in BOTH live and historical mode (fed by
   aggregated_live_flows in live, ClickHouse in historical). Only Top L4 remains
   historical-only, so in live the two remaining tables widen to fill the row
   left empty by the missing L4 card. */
const overviewTableColClass = computed(() => showHistoricalWidgets.value ? "col-lg-4" : "col-lg-6");

/* BootstrapTable column definitions + print_html_column/print_html_row
   callbacks for every list rendered on this page (see bootstrap-table.vue). */
const networkColumns = [
    { id: "name", label: _i18n("sites_dashboard.network") },
];
function printNetworkColumn(col) { return col.label; }
function printNetworkRow(col, row) { return row.name; }

const exporterColumns = [
    { id: "name", label: _i18n("sites_dashboard.exporter") },
    { id: "id", label: _i18n("sites_dashboard.ip_address") },
];
function printExporterColumn(col) { return col.label; }
function printExporterRow(col, row) { return row[col.id]; }

const interfaceColumns = [
    { id: "snmp_ifname", label: _i18n("sites_dashboard.interface") },
    { id: "in_bytes", label: _i18n("sites_dashboard.in_bytes") },
    { id: "out_bytes", label: _i18n("sites_dashboard.out_bytes") },
];
function printInterfaceColumn(col) { return col.label; }
function printInterfaceRow(col, row) {
    if (col.id === "in_bytes" || col.id === "out_bytes") return formatBytes(row[col.id]);
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

/* Resolves a click anywhere inside a BootstrapTable */
function onRowClick(event, rows, handler) {
    const tr = event.target.closest("tbody tr");
    if (!tr) return;
    const index = Array.from(tr.parentElement.children).indexOf(tr);
    if (rows[index]) handler(rows[index]);
}

/* The exporter's own collector interface (interface_id, from getAllExportersList())
   is not necessarily the page's ambient ifid: an exporter can be collected on an
   interface other than the one currently selected in the top navbar, and its
   flowdev/flowdev_port timeseries are only recorded under that collector ifid. */
const exporterTimeseriesIfid = computed(() => {
    return String(selectedExporter.value?.interface_id ?? ifid);
});

const ifaceTimeseriesParams = computed(() => {
    if (selectedInterface.value) {
        return {
            post_params: {
                limit: 180,
                version: 4,
                ts_requests: {
                    "$IFID$": {
                        ts_query: `ifid:${exporterTimeseriesIfid.value},device:${selectedExporter.value?.id},port:${selectedInterface.value.ifindex}`,
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
                    ts_query: `ifid:${exporterTimeseriesIfid.value},device:${selectedExporter.value?.id}`,
                    ts_schema: `flowdev:traffic`,
                },
            },
        },
    };
});

/* exporters_interfaces.lua is the only
   endpoint that reports exporter_name, SNMP availability and per interface
   in/out byte counters. the hierarchy.lua only has id/name.*/
const exporterDisplayName = computed(() => {
    const name = selectedInterface.value?.exporter_name ?? exporterInterfaces.value[0]?.exporter_name;
    return (name && name !== selectedExporter.value?.id) ? name : null;
});

const exporterSnmpEnabled = computed(() => {
    if (selectedInterface.value) return !!selectedInterface.value.snmp_interface_available;
    return exporterInterfaces.value.some((iface) => iface.snmp_interface_available);
});

/* In/out byte totals for the Current Traffic KPI: at interface scope, just
   that one interface's counters; at exporter scope, summed across every
   interface reported for the device. */
const exporterCurrentTraffic = computed(() => {
    if (selectedInterface.value) {
        return {
            in: selectedInterface.value.in_bytes || 0,
            out: selectedInterface.value.out_bytes || 0,
        };
    }
    return exporterInterfaces.value.reduce(
        (acc, iface) => ({
            in: acc.in + (iface.in_bytes || 0),
            out: acc.out + (iface.out_bytes || 0),
        }),
        { in: 0, out: 0 }
    );
});

const historicalFlowsUrl = computed(() => {
    if (!selectedExporter.value || !ifaceEpochBegin.value || !ifaceEpochEnd.value) return null;
    const url_params = ntopng_url_manager.obj_to_url_params({
        ifid,
        epoch_begin: ifaceEpochBegin.value,
        epoch_end: ifaceEpochEnd.value,
        aggregated: false,
        count: "traffic_presence",
        query_preset: "",
        ...(selectedInterface.value
            ? { snmp_interface: `${selectedExporter.value.id}_${selectedInterface.value.ifindex};eq` }
            : { exporter_ip: `${selectedExporter.value.id};eq` }),
    });
    return `${http_prefix}/lua/pro/db_search.lua?${url_params}`;
});

/* Builds a db_search.lua URL scoped to the current exporter/interface and
   epoch range for the given query_preset (l7_traffic, top_hosts_by_traffic,
   top_remote_destinations, ...). Interface scope filters by snmp_interface
   alone (exporter_ip is redundant since snmp_interface already encodes it). */
function buildDbSearchUrl(queryPreset, count = "") {
    if (!selectedExporter.value || !ifaceEpochBegin.value || !ifaceEpochEnd.value) return null;
    const url_params = ntopng_url_manager.obj_to_url_params({
        ifid,
        epoch_begin: ifaceEpochBegin.value,
        epoch_end: ifaceEpochEnd.value,
        aggregated: false,
        count,
        query_preset: queryPreset,
        ...(selectedInterface.value
            ? { snmp_interface: `${selectedExporter.value.id}_${selectedInterface.value.ifindex};eq` }
            : { exporter_ip: `${selectedExporter.value.id};eq` }),
    });
    return `${http_prefix}/lua/pro/db_search.lua?${url_params}`;
}

/* Live counterpart of buildDbSearchUrl: opens the Active Flows > Analysis page
   (aggregated_live_flows) scoped to this exporter/interface for the given
   aggregation criteria. Uses the exporter's collector ifid. */
function buildLiveAggUrl(criteria) {
    if (!selectedExporter.value) return null;
    const url_params = ntopng_url_manager.obj_to_url_params({
        ifid: exporterTimeseriesIfid.value,
        page: "analysis",
        aggregation_criteria: criteria,
        deviceIP: selectedExporter.value.id,
        ...(selectedInterface.value
            ? { ifIdx: selectedInterface.value.ifindex }
            : {}),
    });
    return `${http_prefix}/lua/flows_stats.lua?${url_params}`;
}

/* Title link of the traffic time-series card: opens the "page=historical"
   time-series view for the current scope */
function buildTimeseriesUrl() {
    if (!selectedExporter.value) return null;

    if (selectedInterface.value) {
        const url_params = ntopng_url_manager.obj_to_url_params({
            deviceIP: selectedExporter.value.id,
            ifIdx: selectedInterface.value.ifindex,
            page: "historical",
        });
        return `${http_prefix}/lua/pro/exporter_interface_overview.lua?${url_params}`;
    }

    const url_params = ntopng_url_manager.obj_to_url_params({
        ip: selectedExporter.value.id,
        ifid: exporterTimeseriesIfid.value,
        ...(selectedExporter.value.probe_source_id != null
            ? { probe_source_id: selectedExporter.value.probe_source_id }
            : {}),
    });
    return `${http_prefix}/lua/pro/enterprise/exporter_details.lua?${url_params}`;
}

/* Resolves each card's title-link from CARD_LINKS, switching to the live vs.
   historical variant for cards with both (see isLive / on_epoch_change). */
const titleLinks = computed(() => {
    const asLink = (url) => (url ? { url } : null);
    const asLiveLink = (entry) => asLink(isLive.value ? entry.live_url : entry.historical_url);
    return {
        traffic_time_series: asLink(buildTimeseriesUrl()),
        top_l7_proto: asLink(showHistoricalWidgets.value ? buildDbSearchUrl("l7_traffic", "l7_traffic") : buildLiveAggUrl("application_protocol")),
        top_l4_proto: asLink(buildDbSearchUrl("", "traffic_presence")),
        top_local_talkers: asLink(showHistoricalWidgets.value ? buildDbSearchUrl("top_hosts_by_traffic") : buildLiveAggUrl("client")),
        top_remote_destinations: asLink(showHistoricalWidgets.value ? buildDbSearchUrl("top_remote_destinations") : buildLiveAggUrl("server")),
        networks: asLink(CARD_LINKS.networks.url),
        exporters: asLiveLink(CARD_LINKS.exporters),
        exporter_interfaces: asLiveLink(CARD_LINKS.exporter_interfaces),
    };
});

/* Id of whichever node (site/exporter/interface) is currently active, used to
   keep the sidebar selection highlight in sync with the main panel. */
const selectedNodeId = computed(() => {
    if (selectedInterface.value) return `interface:${selectedExporter.value?.id}:${selectedInterface.value.ifindex}`;
    if (selectedExporter.value) return `exporter:${selectedExporter.value.id}`;
    if (selectedSite.value) return `site:${selectedSite.value.id}`;
    return null;
});

const titleIcon = computed(() => {
    if (selectedInterface.value) return "bi bi-ethernet";
    if (selectedExporter.value) return "fas fa-satellite-dish";
    return "bi bi-geo-alt-fill";
});

/* "Exporter:" / "Interface:" label shown before the name. Sites have marker label */
const titleLabel = computed(() => {
    if (selectedInterface.value) return _i18n("sites_dashboard.interface");
    if (selectedExporter.value) return _i18n("sites_dashboard.exporter");
    return null;
});

/* Each fact (exporter name, exporter IP, interface name, ifIndex) is stated
   exactly once across titleName + titleSubtitle  */
const titleName = computed(() => {
    if (selectedInterface.value) {
        return selectedInterface.value.snmp_ifname
            ? selectedInterface.value.snmp_ifname
            : `${_i18n("sites_dashboard.if_index_short")} ${selectedInterface.value.ifindex}`;
    }
    if (selectedExporter.value) {
        return exporterDisplayName.value ?? selectedExporter.value.name;
    }
    return selectedSite.value?.name ?? "";
});

const titleSubtitle = computed(() => {
    if (selectedInterface.value) {
        const exporterName = exporterDisplayName.value ?? selectedExporter.value?.name;
        const exporterIp = selectedExporter.value?.id;
        const exporterPart = (exporterIp && exporterIp !== exporterName)
            ? `${exporterName} (${exporterIp})`
            : exporterName;
        return `${exporterPart} · ${_i18n("sites_dashboard.if_index_short")} ${selectedInterface.value.ifindex}`;
    }
    if (selectedExporter.value) {
        return exporterDisplayName.value ? selectedExporter.value.id : null;
    }
    return "";
});

const tabs = computed(() => {
    if (selectedInterface.value) {
        return [{ id: "traffic_analysis", label_i18n: "sites_dashboard.traffic_analysis" }];
    }
    if (selectedExporter.value) {
        return [{ id: "exporter_interfaces", label_i18n: "sites_dashboard.interfaces", count: exporterInterfaces.value.length }];
    }
    return [
        { id: "networks", label_i18n: "sites_dashboard.networks", count: networks.value.length },
        { id: "exporters", label_i18n: "sites_dashboard.exporters", count: exporters.value.length },
    ];
});

const breadcrumbItems = computed(() => {
    const items = selectedAncestors.value.map((n) => ({ id: n.id, name: n.name }));

    if (selectedInterface.value) {
        items.push({
            id: selectedNodeId.value,
            name: selectedInterface.value.snmp_ifname ?? `ifIndex ${selectedInterface.value.ifindex}`,
        });
    } else if (selectedExporter.value) {
        items.push({ id: selectedNodeId.value, name: selectedExporter.value.name });
    } else if (selectedSite.value) {
        items.push({ id: selectedNodeId.value, name: selectedSite.value.name });
    }

    return items;
});

const kpiCards = computed(() => {

    if (selectedInterface.value || selectedExporter.value) {
        const cards = [];
        if (selectedInterface.value) {
            cards.push({
                key: "exporter_type",
                icon: "bi bi-diagram-3",
                color: "#EA6A2A",
                labelI18n: "sites_dashboard.exporter_type",
                value: selectedInterface.value.type ?? "—",
                sub: selectedInterface.value.probe_name ? `${_i18n("sites_dashboard.probe_name")}: ${selectedInterface.value.probe_name}` : null,
            });
        } else {
            cards.push({ key: "interfaces", icon: "bi bi-diagram-3", color: "#EA6A2A", labelI18n: "sites_dashboard.interfaces", value: exporterInterfaces.value.length });
        }

        cards.push({
            key: "current_traffic",
            icon: "bi bi-graph-up-arrow",
            color: "#2fb344",
            labelI18n: "sites_dashboard.current_traffic",
            value: formatBytes(exporterCurrentTraffic.value.in + exporterCurrentTraffic.value.out),
            sub: `${_i18n("sites_dashboard.in_bytes")}: ${formatBytes(exporterCurrentTraffic.value.in)} · ${_i18n("sites_dashboard.out_bytes")}: ${formatBytes(exporterCurrentTraffic.value.out)}`,
        });

        cards.push({ key: "flows", icon: "fas fa-stream", color: "#EA6A2A", labelI18n: "sites_dashboard.flows", value: liveFlowsCount.value ?? "—" });
        cards.push({ key: "active_hosts", icon: "bi bi-pc-display", color: "#3b82f6", labelI18n: "sites_dashboard.active_hosts", value: liveHostsCount.value ?? "—" });
        cards.push({
            key: "snmp",
            icon: exporterSnmpEnabled.value ? "bi bi-check-circle" : "bi bi-x-circle",
            color: exporterSnmpEnabled.value ? "#2fb344" : "#94a3b8",
            labelI18n: "sites_dashboard.snmp",
            value: exporterSnmpEnabled.value ? _i18n("sites_dashboard.enabled") : _i18n("sites_dashboard.disabled"),
        });
        return cards;
    }
    return [
        { key: "networks", icon: "bi bi-diagram-3-fill", color: "#2fb344", labelI18n: "sites_dashboard.networks", value: networks.value.length },
        { key: "sub_sites", icon: "bi bi-geo-alt-fill", color: "#EA6A2A", labelI18n: "sites_dashboard.sub_sites", value: sites.value.length },
        { key: "exporters", icon: "bi bi-hdd-network", color: "#3b82f6", labelI18n: "sites_dashboard.exporters", value: exporters.value.length },
    ];
});

function formatBytes(v) {
    return formatterUtils.getFormatter("bytes")(v);
}

function formatPercentage(pct) {
    return NtopUtils.createProgressBar(pct || 0);
}

const RECENT_ACTIVITY_WINDOW_SECS = 5 * 60;

function isRecentlyActive(timeLastUsed) {
    if (!timeLastUsed) return false;
    return (Date.now() / 1000 - timeLastUsed) <= RECENT_ACTIVITY_WINDOW_SECS;
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

onBeforeMount(() => {
    handleSelectSite({ id: DEFAULT_SITE_ID, name: _i18n("sites_dashboard.default_site") });
});

/* Re fetches data in the currently visible panel, without
   changing the current selection/tab/breadcrumb state. */
async function refreshCurrentView() {
    // In live mode the refresh button also slides the rolling window up to now,
    // so the time series advances instead of re-querying the same stale span.
    if (isLive.value) setLiveEpochWindow();

    if (selectedInterface.value) {
        await Promise.all([
            loadExporterOverview(selectedExporter.value, selectedInterface.value),
            loadExporterCounts(selectedExporter.value, selectedInterface.value),
        ]);
    } else if (selectedExporter.value) {
        await Promise.all([
            loadExporterInterfaces(selectedExporter.value),
            loadExporterOverview(selectedExporter.value),
            loadExporterCounts(selectedExporter.value),
        ]);
    } else if (selectedSite.value) {
        await loadHierarchy(selectedSite.value.id);
    }
}

/* ancestors, when provided, is the real chain reported by the
   sidebar's tree for this exact node. When omitted, it defaults
   to an empty chain: a top-level selection with no ancestors. */
async function handleSelectSite(site, ancestors) {
    selectedSite.value = site;
    selectedExporter.value = null;
    selectedInterface.value = null;
    selectedAncestors.value = ancestors ?? [];
    activeTab.value = "networks";
    await loadHierarchy(site.id);
}

async function loadHierarchy(siteId) {
    loadingHierarchy.value = true;
    try {
        const url_params = ntopng_url_manager.obj_to_url_params({ ifid, site_id: siteId });
        const url = `${http_prefix}/lua/pro/rest/v2/get/sites/hierarchy.lua?${url_params}`;
        const data = await ntopng_utility.http_request(url);
        networks.value = data?.networks || [];
        sites.value = data?.sites || [];
        exporters.value = data?.exporters || [];
    } catch (err) {
        console.error("Error retrieving site hierarchy:", err);
        networks.value = [];
        sites.value = [];
        exporters.value = [];
    }
    loadingHierarchy.value = false;
}

/* ancestors, when provided, is the authoritative chain from the sidebar's
   tree. When omitted, the real parent is exactly selectedSite plus everything above it captured before selectedSite
   itself is overwritten below. */
async function handleSelectExporter(exporter, ancestors) {
    const parentSiteCrumb = selectedSite.value
        ? { id: `site:${selectedSite.value.id}`, name: selectedSite.value.name }
        : null;

    selectedExporter.value = exporter;
    selectedInterface.value = null;
    selectedAncestors.value = ancestors ?? (parentSiteCrumb ? [...selectedAncestors.value, parentSiteCrumb] : []);
    activeTab.value = "exporter_interfaces";
    ensureEpochWindow();
    revealInSidebar();
    await Promise.all([
        loadExporterInterfaces(exporter),
        loadExporterOverview(exporter),
        loadExporterCounts(exporter),
    ]);
}

/* Expands the sidebar tree down to whichever node is now selected (site,
   exporter or interface), so a selection made from a table row click (not
   the sidebar itself) still reveals and highlights the matching tree row
   instead of leaving it hidden under a collapsed branch. */
function revealInSidebar() {
    const ancestorIds = selectedAncestors.value.map((a) => a.id);
    const targetId = selectedNodeId.value;
    if (targetId) sidebar.value?.expandTo([...ancestorIds, targetId]);
}

/* Live flows/hosts counts for the "Flows" and "Active Hosts" KPI cards.
   Flows count is scoped to the exporter and, at interface scope, to flows whose
   SNMP in OR out index is the selected ifIndex (ifIdx). Note host/active_list.lua
   only honours deviceIP, so the Active Hosts KPI stays exporter-scoped. */
async function loadExporterCounts(exporter, iface) {
    if (!exporter) return;

    const iface_filter = iface ? { ifIdx: iface.ifindex } : {};

    const flows_params = ntopng_url_manager.obj_to_url_params({
        start: 0,
        length: 1,
        map_search: "",
        visible_columns: "actions,first_seen,last_seen,duration,protocol,score,qoe,flow,cli_asn_asnmode_disabled,srv_asn_asnmode_disabled,throughput,bytes,info,flow_exporter,in_index,out_index",
        deviceIP: exporter.id,
        ...iface_filter,
    });
    const hosts_params = ntopng_url_manager.obj_to_url_params({
        start: 0,
        length: 1,
        map_search: "",
        visible_columns: "actions,ip_address,hostname,num_flows,alerts,score,first_seen,traffic_breakdown,throughput,bytes",
        deviceIP: exporter.id,
        ...iface_filter,
    });

    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/rest/v2/get/flow/active_list.lua?${flows_params}`, undefined, undefined, true
        );
        liveFlowsCount.value = data?.recordsTotal ?? null;
    } catch (err) {
        console.error("Error retrieving live flows count:", err);
        liveFlowsCount.value = null;
    }

    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/rest/v2/get/host/active_list.lua?${hosts_params}`, undefined, undefined, true
        );
        liveHostsCount.value = data?.recordsTotal ?? null;
    } catch (err) {
        console.error("Error retrieving live hosts count:", err);
        liveHostsCount.value = null;
    }
}

/* Refetches the exporter overview cards (L7/L4 protocol breakdown, top
   local talkers, top remote destinations) for the currently selected exporter
   and the current [ifaceEpochBegin, ifaceEpochEnd] window. */
async function loadExporterOverview(exporter, iface) {
    if (!exporter) return;
    if (showHistoricalWidgets.value) {
        await loadExporterOverviewHistorical(exporter, iface);
    } else {
        await loadExporterOverviewLive(exporter, iface);
    }
}

// Live overview: aggregates the active in-memory flows exported by this exporter
// (deviceIP) through aggregated_live_flows.lua, grouped by application protocol,
// client and server, sorted by traffic.
async function loadExporterOverviewLive(exporter, iface) {
    // Top L4: historical-only, cleared in live.
    topL4.value = [];
    loadingL4.value = false;

    const base_params = {
        ifid: exporterTimeseriesIfid.value,
        deviceIP: exporter.id,
        sort: "tot_traffic",
        order: "desc",
        start: 0,
        length: 10,
        // ifIdx matches flows whose SNMP in OR out index is this interface.
        // Passing inIfIdx+outIfIdx together would AND them (in==idx AND out==idx),
        // which is almost never true and would leave interface-scoped tables empty.
        ...(iface ? { ifIdx: iface.ifindex } : {}),
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
async function loadExporterOverviewHistorical(exporter, iface) {
    if (!ifaceEpochBegin.value || !ifaceEpochEnd.value) return;

    const common_params = {
        ifid,
        epoch_begin: ifaceEpochBegin.value,
        epoch_end: ifaceEpochEnd.value,
        ...(iface ? { snmp_interface: `${exporter.id}_${iface.ifindex};eq` } : { exporter_ip: `${exporter.id};eq` }),
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
        ts_query: `ifid:${ifid}`,
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
        ts_query: `ifid:${ifid}`,
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

function on_epoch_change(epoch) {
    isLive.value = epoch?.timeframe_id === "live";

    if (isLive.value) {
        // The picker reports live as a zero-width now() window; the flowdev time
        // series needs a real span, so use the rolling live window instead.
        setLiveEpochWindow();
    } else {
        if (epoch?.epoch_begin) ifaceEpochBegin.value = epoch.epoch_begin;
        if (epoch?.epoch_end) ifaceEpochEnd.value = epoch.epoch_end;
    }

    if (selectedExporter.value) loadExporterOverview(selectedExporter.value, selectedInterface.value);
}

async function loadExporterInterfaces(exporter) {
    loadingInterfaces.value = true;
    try {
        const url_params = ntopng_url_manager.obj_to_url_params({
            start: 0,
            length: 10,
            map_search: "",
            visible_columns: "actions,snmp_ifname,in_bytes,out_bytes,ratio",
            ip: exporter.id,
            exporter_source_id: exporter.exporter_source_id,
            probe_source_id: exporter.probe_source_id,
            probe_ip: exporter.id,
        });
        const url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporters_interfaces.lua?${url_params}`;
        const data = await ntopng_utility.http_request(url);
        exporterInterfaces.value = data || [];
    } catch (err) {
        console.error("Error retrieving exporter interfaces:", err);
        exporterInterfaces.value = [];
    }
    loadingInterfaces.value = false;
}

function handleSelectInterface(iface, exporter, ancestors) {
    const owningExporter = exporter ?? selectedExporter.value;
    const parentExporterCrumb = owningExporter
        ? { id: `exporter:${owningExporter.id}`, name: owningExporter.name }
        : null;

    if (exporter) {
        selectedExporter.value = exporter;
    }
    selectedInterface.value = iface;
    selectedAncestors.value = ancestors ?? (parentExporterCrumb ? [...selectedAncestors.value, parentExporterCrumb] : []);
    activeTab.value = "traffic_analysis";
    ensureEpochWindow();
    revealInSidebar();
    loadExporterOverview(owningExporter, iface);
    loadExporterCounts(owningExporter, iface);
}

function switchTab(tab) {
    activeTab.value = tab.id;
}

async function loadSidebarChildren(node) {
    if (node === null) {
        return fetchSiteLevel(null);
    }
    if (node.data.kind === "site") {
        return fetchSiteLevel(node.data.site.id);
    }
    if (node.data.kind === "exporter") {
        return fetchExporterInterfaceNodes(node.data.exporter);
    }
    return []; // interfaces are leaves
}

/* Fetches the sub sites + exporters of siteId
   and maps them to NodeDescriptors. Sites and exporters can appear side by
   side at the same level, exactly as the hierarchy endpoint returns them. */
async function fetchSiteLevel(siteId) {
    try {
        const paramsObj = { ifid };
        if (siteId !== null && siteId !== undefined) {
            paramsObj.site_id = siteId;
        }
        const url_params = ntopng_url_manager.obj_to_url_params(paramsObj);
        const url = `${http_prefix}/lua/pro/rest/v2/get/sites/hierarchy.lua?${url_params}`;
        const data = await ntopng_utility.http_request(url);

        const rawSites = data?.sites || {};
        const siteList = Array.isArray(rawSites) ? rawSites : Object.values(rawSites);
        const exporterList = Array.isArray(data?.exporters) ? data.exporters : [];

        const siteNodes = siteList
            .filter((s) => String(s.id) !== "0" || siteId === null)
            .map((s) => ({
                id: `site:${s.id}`,
                name: s.name,
                icon: "bi bi-geo-alt-fill",
                data: { kind: "site", site: s },
            }));

        const exporterNodes = exporterList.map((e) => ({
            id: `exporter:${e.id}`,
            name: e.name,
            icon: "fas fa-satellite-dish",
            color: isRecentlyActive(e.time_last_used) ? "#2fb344" : undefined,
            data: { kind: "exporter", exporter: e },
        }));

        return [...siteNodes, ...exporterNodes].sort((a, b) => a.name.localeCompare(b.name));
    } catch (err) {
        console.error("Error retrieving sites hierarchy:", err);
        return [];
    }
}

/* Fetches the interfaces of one exporter and maps them to leaf NodeDescriptors. */
async function fetchExporterInterfaceNodes(exporter) {
    try {
        const url_params = ntopng_url_manager.obj_to_url_params({
            start: 0,
            length: 10,
            map_search: "",
            visible_columns: "actions,snmp_ifname,in_bytes,out_bytes,ratio",
            ip: exporter.id,
            exporter_source_id: exporter.exporter_source_id,
            probe_source_id: exporter.probe_source_id,
            probe_ip: exporter.id,
        });
        const url = `${http_prefix}/lua/pro/rest/v2/get/exporters/exporters_interfaces.lua?${url_params}`;
        const data = await ntopng_utility.http_request(url);
        const list = Array.isArray(data) ? data : [];

        return list.map((iface) => ({
            id: `interface:${exporter.id}:${iface.ifindex}`,
            name: iface.snmp_ifname != null ? String(iface.snmp_ifname) : `ifIndex ${iface.ifindex}`,
            icon: "bi bi-ethernet",
            hasChildren: false,
            data: { kind: "interface", exporter, iface },
        }));
    } catch (err) {
        console.error("Error retrieving exporter interfaces:", err);
        return [];
    }
}

function handleSidebarSelect(node, ancestors) {
    if (node.data.kind === "site") {
        handleSelectSite(node.data.site, ancestors);
    } else if (node.data.kind === "exporter") {
        handleSelectExporter(node.data.exporter, ancestors);
    } else if (node.data.kind === "interface") {
        handleSelectInterface(node.data.iface, node.data.exporter, ancestors);
    }
}

/* Clicking any crumb jumps straight back to that exact node: the ancestor
   chain is truncated to everything strictly above the clicked crumb, and the node itself
   becomes the new selection, reloading its own data. This works for a crumb
   at any depth since it operates purely on breadcrumbItems/selectedAncestors,
   not on any fixed number of levels. */
async function handleBreadcrumbSelect(item) {
    const clickedIndex = breadcrumbItems.value.findIndex((crumb) => crumb.id === item.id);
    const newAncestors = clickedIndex > 0 ? breadcrumbItems.value.slice(0, clickedIndex) : [];

    if (typeof item.id === "string" && item.id.startsWith("site:")) {
        await handleSelectSite({ id: item.id.slice("site:".length), name: item.name }, newAncestors);
    } else if (typeof item.id === "string" && item.id.startsWith("exporter:")) {
        selectedAncestors.value = newAncestors;
        selectedInterface.value = null;
        activeTab.value = "exporter_interfaces";
        if (exporterInterfaces.value.length === 0 && selectedExporter.value) {
            await loadExporterInterfaces(selectedExporter.value);
        }
    }
}
</script>

<style scoped>
.sites-dashboard {
    max-width: none;
    align-items: flex-start;
    margin: -0.5rem -0.75rem 0 -0.75rem;
}

.min-w-0 {
    min-width: 0;
}

.sites-dashboard-main {
    background: var(--bg-base);
    color: var(--ntop-text-color);
}

.sites-dashboard-topbar {
    padding: 14px 20px;
    border-bottom: 1px solid var(--border-color);
    background: var(--bg-base);
    position: sticky;
    top: calc(3rem + 0.5rem);
    z-index: 20;
}

.sites-dashboard-body {
    padding: 20px;
}

.sites-dashboard-subtitle {
    color: var(--ntop-muted-text-color);
}

.sites-dashboard-title-label {
    text-transform: uppercase;
    letter-spacing: 0.02em;
    color: var(--ntop-muted-text-color);
}

.sites-dashboard-empty {
    padding: 60px 0;
}

.sites-dashboard-clickable-row {
    cursor: pointer;
}

.sites-dashboard-clickable-table :deep(tbody tr) {
    cursor: pointer;
    transition: background-color 0.12s ease;
}

.sites-dashboard-clickable-table :deep(tbody tr:hover) {
    background-color: var(--ntop-row-hover-bg, rgba(234, 106, 42, 0.08));
}

.sites-dashboard-date-picker :deep(.dtrp-btn-icon) {
    display: none;
}

.sites-dashboard-flows-btn i {
    color: #fff;
}

.sites-dashboard-refresh-btn {
    height: 28px;
    width: 28px;
    padding: 0.2rem;
    border-radius: 7px;
    display: inline-flex;
    align-items: center;
    justify-content: center;
}

.sites-dashboard-mock-chart {
    min-height: 220px;
}

.sites-dashboard-ts {
    display: flex;
    flex-direction: column;
    flex: 1 1 auto;
    height: 100%;
    min-height: 460px;
}

/* Static "Live" indicator shown in place of the range picker when ClickHouse is
   disabled and the page is live-only. */
.sites-dashboard-live-pill {
    display: inline-flex;
    align-items: center;
    height: 28px;
    padding: 0.2rem 0.65rem;
    font-size: 0.8rem;
    font-weight: 500;
    color: var(--ntop-text-color);
    border: 1px solid var(--border-color);
    border-radius: 7px;
}

@media (max-width: 992px) {
    .sites-dashboard {
        flex-direction: column;
        align-items: stretch;
        min-height: calc(100vh - 60px);
    }
}

@media (max-width: 576px) {
    .sites-dashboard-body {
        padding: 12px;
    }
}
</style>

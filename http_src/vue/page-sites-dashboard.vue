<!-- (C) 2026 - ntop.org -->
<template>
    <div class="sites-dashboard d-flex">
        <TreeNavSidebar ref="sidebar" :title="_i18n('sites_dashboard.sites')"
            :search-placeholder="_i18n('sites_dashboard.search_placeholder')" :load-children="loadSidebarChildren"
            :selected-id="selectedNodeId" :sticky-top="'calc(3rem + 0.5rem)'" @on_select="handleSidebarSelect" />

        <div class="sites-dashboard-main flex-grow-1 min-w-0">
            <div class="sites-dashboard-topbar d-flex align-items-center flex-wrap">
                <BreadcrumbNav :items="breadcrumbItems" @on_select="handleBreadcrumbSelect" />
                <div v-if="selectedExporter || selectedSnmpDevice" class="ms-auto d-flex align-items-center gap-2">
                    <a v-if="selectedExporter && showHistoricalWidgets && historicalFlowsUrl" :href="historicalFlowsUrl" target="_blank"
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

            <div v-if="!initialSelectionReady" class="sites-dashboard-body">
                <Loading :isLoading="true" />
            </div>
            <div v-else class="sites-dashboard-body">
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

                <ExporterTrafficDashboard
                    v-if="selectedInterface ? activeTab === 'traffic_analysis' : (selectedExporter && (activeTab === 'traffic_analysis' || activeTab === 'exporter_interfaces'))"
                    ref="exporterTrafficRef" :ifid="ifid" :exporter="selectedExporter" :iface="selectedInterface"
                    :show-interfaces="activeTab === 'exporter_interfaces'"
                    :epoch-begin="ifaceEpochBegin" :epoch-end="ifaceEpochEnd"
                    :show-historical-widgets="showHistoricalWidgets" :overview-table-col-class="overviewTableColClass"
                    :title-links="titleLinks" :csrf="props.context?.csrf"
                    @select-interface="(iface) => handleSelectInterface(iface, selectedExporter)"
                    @counts-loaded="onExporterCountsLoaded"
                    @interfaces-loaded="(list) => exporterInterfaces = list" />

                <NetworkDashboard v-if="activeTab === 'networks'" :networks="networks" :loading="loadingHierarchy"
                    :title-link="titleLinks.networks" @select="handleSelectNetwork" />

                <ExportersDashboard v-if="activeTab === 'exporters'" :exporters="displayedExporters"
                    :loading="loadingHierarchy" :title-link="titleLinks.exporters" @select="handleSelectExporter" />

                <SnmpTrafficDashboard v-if="activeTab === 'snmp_analysis' && (selectedExporter || selectedSnmpDevice)"
                    ref="snmpTrafficRef" :ifid="ifid"
                    :device="selectedSnmpDevice || selectedExporter"
                    :iface="selectedSnmpDevice ? selectedSnmpInterface : selectedInterface"
                    :show-analysis="!!selectedSnmpDevice"
                    :epoch-begin="ifaceEpochBegin" :epoch-end="ifaceEpochEnd"
                    :title-links="titleLinks" :csrf="props.context?.csrf"
                    @interfaces-loaded="(list) => snmpDeviceInterfaces = list" />

                <DashboardCard v-if="activeTab === 'live_flows' && (selectedExporter || selectedNetwork || selectedSite)"
                    :title="_i18n('sites_dashboard.live_flows')" icon="fas fa-stream"
                    :titleLink="titleLinks.live_flows" noPadding>
                    <PageFlowsList :key="liveFlowsPageKey" :context="liveFlowsContext"
                        :locked_filters="liveFlowsLockedFilters" @total-loaded="(total) => liveFlowsCount = total" />
                </DashboardCard>

                <DashboardCard v-if="activeTab === 'hosts' && (selectedExporter || selectedNetwork)"
                    :title="_i18n('sites_dashboard.hosts')" icon="bi bi-pc-display"
                    :titleLink="titleLinks.hosts" noPadding>
                    <PageHostsList :key="hostsPageKey" :context="hostsContext"
                        :locked_filters="hostsLockedFilters" @total-loaded="(total) => liveHostsCount = total" />
                </DashboardCard>

                <div v-if="!selectedSite && !selectedExporter && !selectedInterface" class="sites-dashboard-empty">
                    <NoData :show="true" />
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, computed, onBeforeMount, nextTick, watch } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services";
import formatterUtils from "../utilities/formatter-utils";
import { default as TreeNavSidebar } from "./components/tree-nav-sidebar.vue";
import { default as BreadcrumbNav } from "./components/breadcrumb-nav.vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";
import { default as NoData } from "./components/no-data.vue";
import { default as Loading } from "./loading.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as BadgeCard } from "./badge-card.vue";
import { default as NetworkDashboard } from "./components/sites-dashboard/network-dashboard.vue";
import { default as ExportersDashboard } from "./components/sites-dashboard/exporters-dashboard.vue";
import { default as ExporterTrafficDashboard } from "./components/sites-dashboard/exporter-traffic-dashboard.vue";
import { default as SnmpTrafficDashboard } from "./components/sites-dashboard/snmp-traffic-dashboard.vue";
import { default as DashboardCard } from "./components/dashboard-card.vue";
import { default as PageFlowsList } from "./page-flows-list.vue";
import { default as PageHostsList } from "./page-hosts-list.vue";
import { isRecentlyActive } from "../utilities/sites-dashboard-utils.js";

const _i18n = (t) => i18n(t);

const DEFAULT_SITE_ID = "0";
const DATE_PICKER_ID = "sites_dashboard_date_picker";

/* URL params that mirror the current selection, so a page refresh restores
   the same site/network/exporter/interface instead of resetting to the
   default site (see the selection watcher below / restoreSelectionFromUrl). */
const URL_PARAM_SITE_ID = "site_id";
const URL_PARAM_NETWORK_ID = "network_id";
const URL_PARAM_EXPORTER_IP = "exporter_ip";
const URL_PARAM_IF_IDX = "ifIdx";
const URL_PARAM_SNMP_DEVICE_IP = "host";
const URL_PARAM_SNMP_IF_IDX = "snmp_if_idx";
const URL_PARAM_TAB = "tab";

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
// live-only and renders a static Live badge instead of the picker. "live" is the
// fallback the picker resolves to when the URL carries no epoch range.
const time_preset_list = [
    { value: "live", label: _i18n("show_alerts.presets.live"), icon: "fa-solid fa-circle fa-2xs text-danger", currently_active: true },
    { value: "hour", label: _i18n("show_alerts.presets.hour"), currently_active: false },
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
const exporterTrafficRef = ref(null);
const snmpTrafficRef = ref(null);

const selectedSite = ref(null);
const selectedNetwork = ref(null);
const selectedExporter = ref(null);
const selectedInterface = ref(null);
/* Bare SNMP device (from sites/hierarchy.lua's snmp_devices[]), distinct from
   selectedExporter: it has no flow/exporter data, so none of the flow-based
   tabs (Traffic Analysis/Live Flows/Hosts) apply to it. */
const selectedSnmpDevice = ref(null);
const selectedSnmpInterface = ref(null);
const activeTab = ref("networks");

/* Gates the whole body's first render until restoreSelectionFromUrl() (an
   async chain of site-hierarchy fetches) has resolved, so on page load/
   navigation the DOM never paints the default "Networks" tab/site before
   flipping to whatever the URL actually specifies -- onBeforeMount alone
   doesn't block the initial render on an async callback, so without this the
   wrong tab would flash briefly before the real one takes over. */
const initialSelectionReady = ref(false);

/* Ancestor chain (root -> ... -> parent) of whichever site is currently
   selected, i.e. everything the breadcrumb needs above the site crumb itself.
   Resolved once per site change (see handleSelectSite) via the same
   resolveSiteChain BFS used for URL restore, so the breadcrumb is always
   built the same way regardless of how the site was reached */
const selectedSiteAncestors = ref([]);

const loadingHierarchy = ref(false);

const networks = ref([]);
const sites = ref([]);
const exporters = ref([]);
const siteSnmpDevices = ref([]);

/* Last interfaces list reported by ExporterTrafficDashboard for the selected
   exporter */
const exporterInterfaces = ref([]);

/* Last interfaces list reported by SnmpTrafficDashboard's Analysis table for
   the selected bare SNMP device (see selectedSnmpDevice). */
const snmpDeviceInterfaces = ref([]);
const snmpDeviceAnalysisCount = computed(() => snmpDeviceInterfaces.value.length);

/* Epoch window driving the exporter/interface traffic panel (ExporterTrafficDashboard),
   set here since it's shared with the top-right date/time range picker. */
const ifaceEpochBegin = ref(null);
const ifaceEpochEnd = ref(null);

const liveFlowsCount = ref(null);
const liveHostsCount = ref(null);

// In the live case we clear the epoch params up front, before the picker mounts
// and reads them, so it resolves to the "live" preset instead of "custom".
const urlEpochBegin = ntopng_url_manager.get_url_entry("epoch_begin");
const urlEpochEnd = ntopng_url_manager.get_url_entry("epoch_end");
const hasHistoricalRange = !!props.context?.isClickhouseEnabled
    && urlEpochBegin != null && urlEpochEnd != null
    && Number.parseInt(urlEpochBegin) < Number.parseInt(urlEpochEnd);

const isLive = ref(!hasHistoricalRange);
const showHistoricalWidgets = computed(() => isClickHouseEnabled.value && !isLive.value);

if (hasHistoricalRange) {
    ifaceEpochBegin.value = Number.parseInt(urlEpochBegin);
    ifaceEpochEnd.value = Number.parseInt(urlEpochEnd);
} else {
    ntopng_url_manager.delete_params(["epoch_begin", "epoch_end"]);
}

/* L7/talkers/destinations render in BOTH live and historical mode (fed by
   aggregated_live_flows in live, ClickHouse in historical). Only Top L4 remains
   historical-only, so in live the two remaining tables widen to fill the row
   left empty by the missing L4 card. */
const overviewTableColClass = computed(() => showHistoricalWidgets.value ? "col-lg-4" : "col-lg-6");

/* The exporter's own collector interface (interface_id, from getAllExportersList())
   is not necessarily the page's ambient ifid: an exporter can be collected on an
   interface other than the one currently selected in the top navbar, and its
   flowdev/flowdev_port timeseries are only recorded under that collector ifid. */
const exporterTimeseriesIfid = computed(() => {
    return String(selectedExporter.value?.interface_id ?? ifid);
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

/* Title-link of the "Live Flows" card: opens flows_stats.lua pre-filtered to
   whichever scope is active -- exporter/interface (SNMP in/out index),
   network, or (root) site. */
function buildLiveFlowsUrl() {
    const base_params = {
        interface_filter: "",
        flowhosts_type: "",
        l4proto: "",
        application: "",
        status: "",
        qoe: "",
        traffic_type: "",
        host_pool_id: "",
        network: "",
        dst_asn: "",
        deviceIP: "",
    };
    if (selectedExporter.value) {
        const url_params = ntopng_url_manager.obj_to_url_params({
            ...base_params,
            deviceIP: selectedExporter.value.id,
            ifIdx: selectedInterface.value ? selectedInterface.value.ifindex : "",
        });
        return `${http_prefix}/lua/flows_stats.lua?${url_params}`;
    }
    if (selectedNetwork.value) {
        const url_params = ntopng_url_manager.obj_to_url_params({ ...base_params, network: selectedNetwork.value.id });
        return `${http_prefix}/lua/flows_stats.lua?${url_params}`;
    }
    if (selectedSite.value) {
        const url_params = ntopng_url_manager.obj_to_url_params({ ...base_params, site_id: selectedSite.value.id });
        return `${http_prefix}/lua/flows_stats.lua?${url_params}`;
    }
    return null;
}

/* Title-link of the "Hosts" card: opens hosts_stats.lua pre-filtered to
   whichever scope is active -- exporter (hosts_stats.lua has no per-interface
   filter, so this stays exporter-scoped even at interface scope) or network. */
function buildHostsUrl() {
    const base_params = {
        version: "",
        network: "",
        traffic_type: "",
        mode: "",
        pool: "",
        deviceIP: "",
        label: "",
    };
    if (selectedExporter.value) {
        const url_params = ntopng_url_manager.obj_to_url_params({ ...base_params, deviceIP: selectedExporter.value.id });
        return `${http_prefix}/lua/hosts_stats.lua?${url_params}`;
    }
    if (selectedNetwork.value) {
        const url_params = ntopng_url_manager.obj_to_url_params({ ...base_params, network: selectedNetwork.value.id });
        return `${http_prefix}/lua/hosts_stats.lua?${url_params}`;
    }
    return null;
}

/* Title link of the SNMP traffic time-series card */
function buildSnmpTimeseriesUrl() {
    if (!selectedExporter.value) return null;

    if (selectedInterface.value) {
        const url_params = ntopng_url_manager.obj_to_url_params({
            host: selectedExporter.value.id,
            snmp_port_idx: selectedInterface.value.ifindex,
            page: "historical",
        });
        return `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?${url_params}`;
    }

    const url_params = ntopng_url_manager.obj_to_url_params({
        host: selectedExporter.value.id,
        page: "historical",
    });
    return `${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?${url_params}`;
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
        live_flows: asLink(buildLiveFlowsUrl()),
        hosts: asLink(buildHostsUrl()),
        snmp_traffic_time_series: asLink(buildSnmpTimeseriesUrl()),
    };
});

/* Id of whichever node (site/exporter/interface) is currently active, used to
   keep the sidebar selection highlight in sync with the main panel. */
const selectedNodeId = computed(() => {
    if (selectedSnmpInterface.value) return `snmp_interface:${selectedSnmpDevice.value?.id}:${selectedSnmpInterface.value.ifindex}`;
    if (selectedSnmpDevice.value) return `snmp_device:${selectedSnmpDevice.value.id}`;
    if (selectedInterface.value) return `interface:${selectedExporter.value?.id}:${selectedInterface.value.ifindex}`;
    if (selectedExporter.value) return `exporter:${selectedExporter.value.id}`;
    if (selectedNetwork.value) return selectedNetwork.value.nodeId;
    if (selectedSite.value) return `site:${selectedSite.value.id}`;
    return null;
});

const titleIcon = computed(() => {
    if (selectedSnmpInterface.value) return "bi bi-ethernet";
    if (selectedSnmpDevice.value) return "fas fa-network-wired";
    if (selectedInterface.value) return "bi bi-ethernet";
    if (selectedExporter.value) return "fas fa-satellite-dish";
    if (selectedNetwork.value) return "bi bi-diagram-3-fill";
    return "bi bi-geo-alt-fill";
});

/* "Exporter:" / "Interface:" label shown before the name. Sites have marker label */
const titleLabel = computed(() => {
    if (selectedSnmpInterface.value) return _i18n("sites_dashboard.interface");
    if (selectedSnmpDevice.value) return _i18n("sites_dashboard.snmp_device");
    if (selectedInterface.value) return _i18n("sites_dashboard.interface");
    if (selectedExporter.value) return _i18n("sites_dashboard.exporter");
    if (selectedNetwork.value) return _i18n("sites_dashboard.network");
    return null;
});

/* Each fact (exporter name, exporter IP, interface name, ifIndex) is stated
   exactly once across titleName + titleSubtitle  */
const titleName = computed(() => {
    if (selectedSnmpInterface.value) {
        return selectedSnmpInterface.value.snmp_ifname
            ? selectedSnmpInterface.value.snmp_ifname
            : `${_i18n("sites_dashboard.if_index_short")} ${selectedSnmpInterface.value.ifindex}`;
    }
    if (selectedSnmpDevice.value) {
        return selectedSnmpDevice.value.name ?? selectedSnmpDevice.value.id;
    }
    if (selectedInterface.value) {
        return selectedInterface.value.snmp_ifname
            ? selectedInterface.value.snmp_ifname
            : `${_i18n("sites_dashboard.if_index_short")} ${selectedInterface.value.ifindex}`;
    }
    if (selectedExporter.value) {
        return exporterDisplayName.value ?? selectedExporter.value.name;
    }
    if (selectedNetwork.value) {
        return selectedNetwork.value.name;
    }
    return selectedSite.value?.name ?? "";
});

const titleSubtitle = computed(() => {
    if (selectedSnmpInterface.value) {
        const deviceName = selectedSnmpDevice.value?.name ?? selectedSnmpDevice.value?.id;
        const deviceIp = selectedSnmpDevice.value?.id;
        const devicePart = (deviceIp && deviceIp !== deviceName) ? `${deviceName} (${deviceIp})` : deviceName;
        return `${devicePart} · ${_i18n("sites_dashboard.if_index_short")} ${selectedSnmpInterface.value.ifindex}`;
    }
    if (selectedSnmpDevice.value) {
        return selectedSnmpDevice.value.name && selectedSnmpDevice.value.name !== selectedSnmpDevice.value.id
            ? selectedSnmpDevice.value.id
            : "";
    }
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
    if (selectedSnmpDevice.value) {
        return [{ id: "snmp_analysis", label_i18n: "sites_dashboard.snmp_analysis" }];
    }
    if (selectedInterface.value) {
        const t = [
            { id: "traffic_analysis", label_i18n: "sites_dashboard.traffic_analysis" },
            { id: "live_flows", label_i18n: "sites_dashboard.live_flows", count: liveFlowsCount.value },
            { id: "hosts", label_i18n: "sites_dashboard.hosts", count: liveHostsCount.value },
        ];
        if (exporterSnmpEnabled.value) t.push({ id: "snmp_analysis", label_i18n: "sites_dashboard.snmp_analysis" });
        return t;
    }
    if (selectedExporter.value) {
        const t = [
            { id: "traffic_analysis", label_i18n: "sites_dashboard.traffic_analysis" },
            { id: "exporter_interfaces", label_i18n: "sites_dashboard.interfaces", count: exporterInterfaces.value.length },
            { id: "live_flows", label_i18n: "sites_dashboard.live_flows", count: liveFlowsCount.value },
            { id: "hosts", label_i18n: "sites_dashboard.hosts", count: liveHostsCount.value },
        ];
        if (selectedExporter.value) t.push({ id: "snmp_analysis", label_i18n: "sites_dashboard.snmp_analysis" });
        return t;
    }
    if (selectedNetwork.value) {
        return [
            { id: "exporters", label_i18n: "sites_dashboard.exporters", count: displayedExporters.value.length },
            { id: "live_flows", label_i18n: "sites_dashboard.live_flows", count: liveFlowsCount.value },
            { id: "hosts", label_i18n: "sites_dashboard.hosts", count: liveHostsCount.value },
        ];
    }
    return [
        { id: "networks", label_i18n: "sites_dashboard.networks", count: networks.value.length },
        { id: "exporters", label_i18n: "sites_dashboard.exporters", count: exporters.value.length },
        { id: "live_flows", label_i18n: "sites_dashboard.live_flows", count: liveFlowsCount.value },
    ];
});

/* Every crumb id is prefixed with its kind (site:/network:/exporter:/interface:,
   see selectedNodeId and the "network:<site>:<id>" scheme in handleSelectNetwork),
   so the breadcrumb's hover tooltip ("Site", "Network", ...) can be derived
   generically from the id instead of being threaded through separately. */
const BREADCRUMB_KIND_LABELS = {
    site: () => _i18n("sites_dashboard.site"),
    network: () => _i18n("sites_dashboard.network"),
    exporter: () => _i18n("sites_dashboard.exporter"),
    interface: () => _i18n("sites_dashboard.interface"),
    snmp_devices: () => _i18n("sites_dashboard.snmp_devices"),
    snmp_device: () => _i18n("sites_dashboard.snmp_device"),
    snmp_interface: () => _i18n("sites_dashboard.interface"),
};

function breadcrumbTooltip(id) {
    if (typeof id !== "string") return null;
    const kind = id.split(":")[0];
    return BREADCRUMB_KIND_LABELS[kind]?.() ?? null;
}

/* Single generic breadcrumb builder: always composes the chain the same way
   from current selection state, regardless of how that state was reached
   (sidebar click, table click, breadcrumb click, or URL restore on mount) —
   no per-handler ancestor bookkeeping. */
const breadcrumbItems = computed(() => {
    const items = [...selectedSiteAncestors.value];

    if (selectedSite.value && selectedSite.value.id !== DEFAULT_SITE_ID) {
        items.push({ id: `site:${selectedSite.value.id}`, name: selectedSite.value.name });
    }
    if (selectedNetwork.value) {
        items.push({ id: selectedNetwork.value.nodeId, name: selectedNetwork.value.name });
    }
    if (selectedExporter.value) {
        items.push({ id: `exporter:${selectedExporter.value.id}`, name: selectedExporter.value.name });
    }
    if (selectedInterface.value) {
        items.push({
            id: `interface:${selectedExporter.value?.id}:${selectedInterface.value.ifindex}`,
            name: selectedInterface.value.snmp_ifname ?? `ifIndex ${selectedInterface.value.ifindex}`,
        });
    }
    if (selectedSnmpDevice.value) {
        // Matches the sidebar's snmp_devices group node id exactly (see
        // makeSnmpDevicesGroupNode), so revealInSidebar's expandTo() can find
        // it: grouped under the owning network when known, otherwise
        // top-level under the site (unassigned devices, see fetchSiteLevel).
        const groupParentId = selectedNetwork.value?.nodeId ?? `site:${selectedSite.value?.id ?? DEFAULT_SITE_ID}`;
        items.push({
            id: `snmp_devices:${groupParentId}`,
            name: _i18n("sites_dashboard.snmp_devices"),
        });
        items.push({
            id: `snmp_device:${selectedSnmpDevice.value.id}`,
            name: selectedSnmpDevice.value.name ?? selectedSnmpDevice.value.id,
        });
    }
    if (selectedSnmpInterface.value) {
        items.push({
            id: `snmp_interface:${selectedSnmpDevice.value?.id}:${selectedSnmpInterface.value.ifindex}`,
            name: selectedSnmpInterface.value.snmp_ifname ?? `ifIndex ${selectedSnmpInterface.value.ifindex}`,
        });
    }

    return items.map((item) => ({ ...item, tooltip: breadcrumbTooltip(item.id) }));
});

const kpiCards = computed(() => {

    if (selectedSnmpDevice.value) {
        const cards = [];
        if (selectedSnmpInterface.value) {
            cards.push({
                key: "snmp_interface_type",
                icon: "bi bi-ethernet",
                color: "#EA6A2A",
                labelI18n: "sites_dashboard.interface_type",
                value: selectedSnmpInterface.value.type ?? "—",
            });
        } else {
            cards.push({
                key: "snmp_interfaces",
                icon: "fas fa-network-wired",
                color: "#EA6A2A",
                labelI18n: "sites_dashboard.snmp_interfaces",
                value: snmpDeviceAnalysisCount.value,
            });
        }
        return cards;
    }

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

/* Exporters shown in the "exporters" tab table: scoped down to the selected
   network's members when a network node is active, otherwise the full list
   for the current site. */
const displayedExporters = computed(() => {
    if (!selectedNetwork.value) return exporters.value;
    return exporters.value.filter((e) => String(e.network_id) === String(selectedNetwork.value.id));
});

const liveFlowsContext = computed(() => ({
    ifid,
    has_exporters: true,
    is_viewed: false,
    is_clickhouse_enabled: isClickHouseEnabled.value,
    is_pcap: false,
    csrf: props.context?.csrf,
    is_enterprise_l: !!props.context?.is_enterprise_l,
    ASNModeEnabled: !!props.context?.ASNModeEnabled,
    isNedge: !!props.context?.isNedge,
}));

const hostsContext = computed(() => ({
    ifid,
    has_vlans: !!props.context?.has_vlans,
    csrf: props.context?.csrf,
    isNedge: !!props.context?.isNedge,
}));
/* deviceIP/ifIdx/network/site_id are pinned to the current selection (see the
   URL watcher below), so their filter dropdowns are shown for visibility/
   consistency with the rest of the row but disabled rather than editable here. */
const liveFlowsLockedFilters = computed(() => {
    let lockedFilters = [];
    if (selectedInterface.value) lockedFilters = lockedFilters.concat(["deviceIP", "ifIdx", "inIfIdx", "outIfIdx"]);
    if (selectedExporter.value) lockedFilters = lockedFilters.concat(["deviceIP"]);
    if (selectedNetwork.value) lockedFilters = lockedFilters.concat(["network"]);
    if (selectedSite.value) lockedFilters = lockedFilters.concat(["site_id"]);
    return lockedFilters;
});
const hostsLockedFilters = computed(() =>
    selectedNetwork.value && !selectedExporter.value ? ["network"] : ["deviceIP"]
);

/* Distinguishes every filterable scope (exporter/interface, network, site) so
   the embedded list remounts (instead of just re-filtering in place) whenever
   the scope changes. */
const liveFlowsPageKey = computed(() =>
    `${selectedExporter.value?.id ?? ""}:${selectedInterface.value?.ifindex ?? ""}:${selectedNetwork.value?.id ?? ""}:${selectedSite.value?.id ?? ""}`
);
const hostsPageKey = liveFlowsPageKey;


// "site_id" is deliberately NOT in this list: it is also the persistent
// site-tree selection param (URL_PARAM_SITE_ID, see the selection->URL watcher
// below) and must never be blanket-deleted here -- see the dedicated
// site_id handling after this forEach.
const EMBEDDED_TAB_URL_PARAMS = ["deviceIP", "ifIdx", "network"];

/* Mirrors the current exporter/interface/network/site scope into the real
   URL's deviceIP/ifIdx/network/site_id params while a
   "live_flows"/"hosts" tab is active, so the embedded page-flows-list/
   page-hosts-list components (which read filters straight off
   window.location.search) come up pre-filtered, matching
   flows_stats.lua?deviceIP=...&ifIdx=... /
   flows_stats.lua?network=... / flows_stats.lua?site_id=... /
   hosts_stats.lua?deviceIP=... / hosts_stats.lua?network=.... Removed again
   on tab switch so it doesn't leak into the sites-dashboard's own selection
   params. */
watch([activeTab, selectedExporter, selectedInterface, selectedNetwork, selectedSite], () => {
    const search_params = ntopng_url_manager.get_url_search_params();
    EMBEDDED_TAB_URL_PARAMS.forEach((p) => search_params.delete(p));

    const onEmbeddedTab = activeTab.value === "live_flows" || activeTab.value === "hosts";
    if (onEmbeddedTab && selectedExporter.value) {
        search_params.set("deviceIP", selectedExporter.value.id);
        // hosts_stats.lua's active_list only filters by deviceIP (no per-interface
        // scoping), so ifIdx only apply to the live_flows tab.
        if (activeTab.value === "live_flows" && selectedInterface.value) {
            search_params.set("ifIdx", selectedInterface.value.ifindex);
        }
    } else if (onEmbeddedTab && selectedNetwork.value) {
        search_params.set("network", selectedNetwork.value.id);
    }

    // site_id: only this watcher (not the blanket forEach above) ever touches
    // it, and only while at pure site scope with the live_flows tab active
    // (its only tab, see tabs computed) -- otherwise the persistent
    // selection->URL watcher below remains the sole owner of this param,
    // including deleting it for the Default site (site_id="0" case, where
    // this tab still needs it present, unlike the persisted value).
    if (activeTab.value === "live_flows" && !selectedExporter.value && !selectedNetwork.value && selectedSite.value) {
        search_params.set("site_id", selectedSite.value.id);
    } else if (selectedSite.value && selectedSite.value.id !== DEFAULT_SITE_ID) {
        // Non-default site selected but not on this tab: restore the
        // persistent watcher's value instead of leaving it deleted.
        search_params.set("site_id", selectedSite.value.id);
    } else if (!selectedSite.value || selectedSite.value.id === DEFAULT_SITE_ID) {
        search_params.delete("site_id");
    }

    ntopng_url_manager.replace_url(search_params.toString());
}, { immediate: true });

function formatBytes(v) {
    return formatterUtils.getFormatter("bytes")(v);
}

onBeforeMount(async () => {
    await restoreSelectionFromUrl();
    initialSelectionReady.value = true;
});

/* Re fetches data in the currently visible panel, without
   changing the current selection/tab/breadcrumb state. */
async function refreshCurrentView() {
    // In live mode the refresh button also slides the rolling window up to now,
    // so the time series advances instead of re-querying the same stale span.
    if (isLive.value) setLiveEpochWindow();

    if (selectedExporter.value || selectedSnmpDevice.value) {
        // Only one of the two panels is mounted at a time (tab-gated), so the
        // other ref is null and its optional call is a no-op.
        await Promise.all([
            exporterTrafficRef.value?.refresh(),
            snmpTrafficRef.value?.refresh(),
        ]);
    } else if (selectedSite.value) {
        await loadHierarchy(selectedSite.value.id);
    }
}

/* siteAncestors, when provided, is the real chain reported by the sidebar's
   tree for this exact node (root -> ... -> parent). When omitted (table
   click, breadcrumb click, URL restore), it's resolved generically via the
   same resolveSiteChain BFS used everywhere else, so the breadcrumb always
   ends up identical regardless of how the site was reached. */
async function handleSelectSite(site, siteAncestors) {
    selectedSite.value = site;
    selectedNetwork.value = null;
    selectedExporter.value = null;
    selectedInterface.value = null;
    selectedSnmpDevice.value = null;
    selectedSnmpInterface.value = null;
    activeTab.value = "networks";

    if (siteAncestors) {
        selectedSiteAncestors.value = siteAncestors;
    } else if (site.id === DEFAULT_SITE_ID) {
        selectedSiteAncestors.value = [];
    } else {
        selectedSiteAncestors.value = (await resolveSiteChain(site.id)).ancestors;
    }

    await loadHierarchy(site.id);
}

/* Builds the selectedNetwork shape (id/name/nodeId) from a raw {id, name}
   network object, under the current site. */
function makeSelectedNetwork(network) {
    if (!network) return null;
    return {
        id: network.id,
        name: network.name,
        nodeId: `network:${selectedSite.value?.id ?? DEFAULT_SITE_ID}:${network.id}`,
    };
}

/* Looks up the network a given network_id refers to within the current
   site's loaded networks.value list (populated by loadHierarchy). */
function findNetworkById(networkId) {
    if (networkId == null) return null;
    return networks.value.find((n) => String(n.id) === String(networkId)) ?? null;
}

/* Selects a "network" grouping node: shows only the exporters that belong to
   this network_id, reusing the exporters tab/table. */
function handleSelectNetwork(network) {
    selectedNetwork.value = makeSelectedNetwork(network);
    selectedExporter.value = null;
    selectedInterface.value = null;
    selectedSnmpDevice.value = null;
    selectedSnmpInterface.value = null;
    activeTab.value = "exporters";
    revealInSidebar();
}

async function loadHierarchy(siteId) {
    loadingHierarchy.value = true;
    try {
        const data = await fetchSiteHierarchy(siteId);
        networks.value = data?.networks || [];
        sites.value = data?.sites || [];
        exporters.value = data?.exporters || [];
        siteSnmpDevices.value = data?.snmp_devices || [];
    } catch (err) {
        console.error("Error retrieving site hierarchy:", err);
        networks.value = [];
        sites.value = [];
        exporters.value = [];
        siteSnmpDevices.value = [];
    }
    loadingHierarchy.value = false;
}

/* Selects an exporter. The breadcrumb's network crumb (if any) is derived
   generically from the exporter's own network_id */
async function handleSelectExporter(exporter) {
    selectedExporter.value = exporter;
    selectedInterface.value = null;
    selectedSnmpDevice.value = null;
    selectedSnmpInterface.value = null;
    selectedNetwork.value = makeSelectedNetwork(findNetworkById(exporter.network_id));
    activeTab.value = "traffic_analysis";
    ensureEpochWindow();
    revealInSidebar();
    // The picker mounts with this selection; in live it writes a zero-width
    // window to the URL on mount, so clear it once mounted (see stripLiveEpochFromUrl).
    stripLiveEpochFromUrl();
    await nextTick();
    await exporterTrafficRef.value?.refresh();
}

/* Expands the sidebar tree down to whichever node is now selected (site,
   exporter or interface), so a selection made from a table row click (not
   the sidebar itself) still reveals and highlights the matching tree row
   instead of leaving it hidden under a collapsed branch. */
function revealInSidebar() {
    // breadcrumbItems always ends with the current node's own crumb (matching
    // selectedNodeId), so its ancestor ids are exactly everything before that;
    // the target id itself is included too so an exporter/network selection
    // also expands to reveal its own children (interfaces/exporters).
    const targetId = selectedNodeId.value;
    if (!targetId) return;
    const ancestorIds = breadcrumbItems.value.slice(0, -1).map((a) => a.id);
    sidebar.value?.expandTo([...ancestorIds, targetId]);
}

/* Single generic sync point for selection -> URL: one watcher over the four
   selection refs, instead of a syncSelectionToUrl() call threaded through
   every handler. */
watch([selectedSite, selectedNetwork, selectedExporter, selectedInterface, selectedSnmpDevice, selectedSnmpInterface, activeTab], () => {
    const search_params = ntopng_url_manager.get_url_search_params();

    const site_id = selectedSite.value?.id;
    if (site_id != null && site_id !== DEFAULT_SITE_ID) {
        search_params.set(URL_PARAM_SITE_ID, site_id);
    } else {
        search_params.delete(URL_PARAM_SITE_ID);
    }

    if (selectedNetwork.value) {
        search_params.set(URL_PARAM_NETWORK_ID, selectedNetwork.value.id);
    } else {
        search_params.delete(URL_PARAM_NETWORK_ID);
    }

    if (selectedExporter.value) {
        search_params.set(URL_PARAM_EXPORTER_IP, selectedExporter.value.id);
    } else {
        search_params.delete(URL_PARAM_EXPORTER_IP);
    }

    if (selectedInterface.value) {
        search_params.set(URL_PARAM_IF_IDX, selectedInterface.value.ifindex);
    } else {
        search_params.delete(URL_PARAM_IF_IDX);
    }

    if (selectedSnmpDevice.value) {
        search_params.set(URL_PARAM_SNMP_DEVICE_IP, selectedSnmpDevice.value.id);
    } else {
        search_params.delete(URL_PARAM_SNMP_DEVICE_IP);
    }

    if (selectedSnmpInterface.value) {
        search_params.set(URL_PARAM_SNMP_IF_IDX, selectedSnmpInterface.value.ifindex);
    } else {
        search_params.delete(URL_PARAM_SNMP_IF_IDX);
    }

    if (activeTab.value) {
        search_params.set(URL_PARAM_TAB, activeTab.value);
    } else {
        search_params.delete(URL_PARAM_TAB);
    }

    ntopng_url_manager.replace_url(search_params.toString());
});

/* site_id=0 (Default's own networks/exporters) and "no site_id" (the flat
   top-level sites list: Default + every other root-level site) are two
   different, both meaningful queries — site_id is only omitted when siteId
   is actually null/undefined (the tree's true root), never coerced from "0". */
async function fetchSiteHierarchy(siteId) {
    const paramsObj = { ifid };
    if (siteId !== null && siteId !== undefined) paramsObj.site_id = siteId;
    const url_params = ntopng_url_manager.obj_to_url_params(paramsObj);
    const url = `${http_prefix}/lua/pro/rest/v2/get/sites/hierarchy.lua?${url_params}`;
    return ntopng_utility.http_request(url);
}

function siteListFrom(data) {
    const rawSites = data?.sites || {};
    return Array.isArray(rawSites) ? rawSites : Object.values(rawSites);
}

/* Resolves an arbitrary site_id's own name plus its full ancestor chain, by
   depth-first searching the site tree top-down from the root */
async function resolveSiteChain(targetSiteId) {
    const defaultSite = { id: DEFAULT_SITE_ID, name: _i18n("sites_dashboard.default_site") };
    if (targetSiteId === DEFAULT_SITE_ID) return { site: defaultSite, ancestors: [] };

    const MAX_DEPTH = 20;

    // DFS stack of { id, ancestors } to visit, ancestors being the crumb chain
    // (root -> ... -> parent) leading to that node, not including it
    const rootCrumb = { id: `site:${DEFAULT_SITE_ID}`, name: defaultSite.name };
    let stack = [{ id: null, ancestors: [rootCrumb] }];

    for (let depth = 0; depth < MAX_DEPTH && stack.length > 0; depth++) {
        const nextStack = [];
        for (const node of stack) {
            let data;
            try {
                data = await fetchSiteHierarchy(node.id);
            } catch (err) {
                console.error("Error resolving site chain from URL:", err);
                continue;
            }

            const children = siteListFrom(data).filter((s) => String(s.id) !== DEFAULT_SITE_ID);
            const match = children.find((s) => String(s.id) === String(targetSiteId));
            if (match) return { site: { id: match.id, name: match.name }, ancestors: node.ancestors };

            children.forEach((child) => {
                nextStack.push({
                    id: child.id,
                    ancestors: [...node.ancestors, { id: `site:${child.id}`, name: child.name }],
                });
            });
        }
        stack = nextStack;
    }

    return { site: defaultSite, ancestors: [] };
}

/* Restores the selection from the URL on mount: resolves the site's own name
   and ancestor chain (see resolveSiteChain) */
async function restoreSelectionFromUrl() {
    const urlSiteId = ntopng_url_manager.get_url_entry(URL_PARAM_SITE_ID) ?? DEFAULT_SITE_ID;
    const urlNetworkId = ntopng_url_manager.get_url_entry(URL_PARAM_NETWORK_ID);
    const urlExporterIp = ntopng_url_manager.get_url_entry(URL_PARAM_EXPORTER_IP);
    const urlIfIdx = ntopng_url_manager.get_url_entry(URL_PARAM_IF_IDX);
    const urlSnmpDeviceIp = ntopng_url_manager.get_url_entry(URL_PARAM_SNMP_DEVICE_IP);
    const urlSnmpIfIdx = ntopng_url_manager.get_url_entry(URL_PARAM_SNMP_IF_IDX);
    const urlTab = ntopng_url_manager.get_url_entry(URL_PARAM_TAB);

    // Every handleSelect* call below resets activeTab to its own default tab,
    // so the saved tab (if still valid for the resulting selection) is applied
    // last, once, overriding those defaults.
    const restoreTab = () => {
        if (urlTab && tabs.value.some((t) => t.id === urlTab)) activeTab.value = urlTab;
    };

    const { site, ancestors: siteAncestors } = await resolveSiteChain(urlSiteId);
    // Loads networks.value/exporters.value/siteSnmpDevices.value for this site
    await handleSelectSite(site, siteAncestors);

    if (urlExporterIp) {
        const exporter = exporters.value.find((e) => String(e.id) === String(urlExporterIp));
        if (!exporter) return;

        await handleSelectExporter(exporter);

        if (urlIfIdx) {
            const iface = exporterInterfaces.value.find((i) => String(i.ifindex) === String(urlIfIdx));
            if (iface) handleSelectInterface(iface, exporter);
        }
        restoreTab();
        return;
    }

    if (urlSnmpDeviceIp) {
        const device = siteSnmpDevices.value.find((d) => String(d.ip) === String(urlSnmpDeviceIp));
        if (!device) return;

        handleSelectSnmpDevice(device);

        if (urlSnmpIfIdx) {
            const ifaceNodes = await fetchSnmpDeviceInterfaceNodes(device);
            const ifaceNode = ifaceNodes.find((n) => String(n.data.iface.ifindex) === String(urlSnmpIfIdx));
            if (ifaceNode) handleSelectSnmpInterface(ifaceNode.data.iface, device);
        }
        restoreTab();
        return;
    }

    if (urlNetworkId) {
        const network = networks.value.find((n) => String(n.id) === String(urlNetworkId));
        if (network) handleSelectNetwork(network);
    }
    restoreTab();
}

// in live, the picker still writes a zero-width now() window (epoch_begin == epoch_end), which would
// be resolved back to "custom" on the next load, so we strip it.
function stripLiveEpochFromUrl() {
    if (isLive.value) ntopng_url_manager.delete_params(["epoch_begin", "epoch_end"]);
}

function on_epoch_change(epoch) {
    isLive.value = epoch?.timeframe_id === "live";

    if (isLive.value) {
        stripLiveEpochFromUrl();
        setLiveEpochWindow();
    } else {
        if (epoch?.epoch_begin) ifaceEpochBegin.value = epoch.epoch_begin;
        if (epoch?.epoch_end) ifaceEpochEnd.value = epoch.epoch_end;
    }

    if (selectedExporter.value) exporterTrafficRef.value?.refreshOverview();
}

function onExporterCountsLoaded({ flows, hosts }) {
    liveFlowsCount.value = flows;
    liveHostsCount.value = hosts;
}

/* Initial Live Flows/Hosts tab pill counts for network and site scope
   (exporter/interface scope gets its initial value from
   ExporterTrafficDashboard's own counts-loaded emit instead, see
   onExporterCountsLoaded), scoped the same way the embedded live_flows/hosts
   tabs are (see the EMBEDDED_TAB_URL_PARAMS watcher). Only a one-shot probe:
   once the corresponding tab is actually opened, PageFlowsList/PageHostsList's
   total-loaded emit (see the template) takes over for every subsequent load.
   hosts_stats.lua's active_list has no site_id filter, so hosts stays null
   at site scope. */
async function loadNetworkOrSiteCounts() {
    if (selectedExporter.value || selectedInterface.value) return; // handled by the child emit instead

    const scopeParams = selectedNetwork.value
        ? { network: selectedNetwork.value.id }
        : (selectedSite.value ? { site_id: selectedSite.value.id } : null);
    if (!scopeParams) {
        liveFlowsCount.value = null;
        liveHostsCount.value = null;
        return;
    }

    const flows_params = ntopng_url_manager.obj_to_url_params({ start: 0, length: 1, map_search: "", ...scopeParams });
    try {
        const data = await ntopng_utility.http_request(
            `${http_prefix}/lua/rest/v2/get/flow/active_list.lua?${flows_params}`, undefined, undefined, true
        );
        liveFlowsCount.value = data?.recordsTotal ?? null;
    } catch (err) {
        console.error("Error retrieving live flows count:", err);
        liveFlowsCount.value = null;
    }

    if (!selectedNetwork.value) {
        liveHostsCount.value = null; // no site_id filter on host/active_list.lua
        return;
    }
    const hosts_params = ntopng_url_manager.obj_to_url_params({ start: 0, length: 1, map_search: "", ...scopeParams });
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

/* One-shot fetch on scope change: this is only the pill's initial value for
   whichever tab isn't currently open (e.g. showing the Live Flows count while
   viewing the Exporters tab). Once the live_flows/hosts tab is actually
   opened, PageFlowsList/PageHostsList's own total-loaded emit (see the
   template) takes over and keeps the count in lockstep with the table's own
   recordsTotal on every subsequent load -- no separate polling needed. */
watch([selectedNetwork, selectedSite, selectedExporter, selectedInterface], () => {
    loadNetworkOrSiteCounts();
});

/* Selects an interface. Like handleSelectExporter, the network crumb (if any)
   is derived from the owning exporter's network_id, not from prior selection
   state, so it's correct however this interface was reached. */
function handleSelectInterface(iface, exporter) {
    const owningExporter = exporter ?? selectedExporter.value;

    selectedExporter.value = owningExporter;
    selectedInterface.value = iface;
    selectedSnmpDevice.value = null;
    selectedSnmpInterface.value = null;
    selectedNetwork.value = makeSelectedNetwork(findNetworkById(owningExporter?.network_id));
    activeTab.value = "traffic_analysis";
    ensureEpochWindow();
    revealInSidebar();
    stripLiveEpochFromUrl();
    nextTick(() => exporterTrafficRef.value?.refresh());
}

/* Selects a bare SNMP device (sites/hierarchy.lua's snmp_devices[]), clearing
   whatever exporter/interface scope was active -- the two are mutually
   exclusive selection states (see selectedSnmpDevice). */
function handleSelectSnmpDevice(device, network) {
    selectedExporter.value = null;
    selectedInterface.value = null;
    selectedSnmpDevice.value = { id: device.ip, name: device.name };
    selectedSnmpInterface.value = null;
    selectedNetwork.value = network ? makeSelectedNetwork(network) : makeSelectedNetwork(findNetworkById(device.network_id));
    activeTab.value = "snmp_analysis";
    snmpDeviceInterfaces.value = [];
    ensureEpochWindow();
    revealInSidebar();
    stripLiveEpochFromUrl();
    nextTick(() => snmpTrafficRef.value?.refresh());
}

/* Drills into one interface of the currently selected bare SNMP device,
   triggered from the Analysis table's select-interface-equivalent drill-down
   (via the sidebar or the in-card row link's owning device context). */
function handleSelectSnmpInterface(iface, device) {
    if (device) selectedSnmpDevice.value = { id: device.ip, name: device.name };
    selectedSnmpInterface.value = iface;
    activeTab.value = "snmp_analysis";
    ensureEpochWindow();
    revealInSidebar();
    stripLiveEpochFromUrl();
    nextTick(() => snmpTrafficRef.value?.refresh());
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
    if (node.data.kind === "network") {
        return [
            ...node.data.exporters.map((e) => makeExporterNode(e)),
            ...(node.data.snmpDevices.length > 0 ? [makeSnmpDevicesGroupNode(node.id, node.data.snmpDevices)] : []),
        ];
    }
    if (node.data.kind === "exporter") {
        return fetchExporterInterfaceNodes(node.data.exporter);
    }
    if (node.data.kind === "snmp_devices_group") {
        return node.data.devices.map((d) => makeSnmpDeviceNode(d));
    }
    return []; // interfaces and snmp_device nodes are leaves
}

function makeExporterNode(e) {
    return {
        id: `exporter:${e.id}`,
        name: e.name,
        icon: "fas fa-satellite-dish",
        color: isRecentlyActive(e.time_last_used) ? "#2fb344" : undefined,
        data: { kind: "exporter", exporter: e },
    };
}

function makeSnmpDevicesGroupNode(networkNodeId, devices) {
    return {
        id: `snmp_devices:${networkNodeId}`,
        name: _i18n("sites_dashboard.snmp_devices"),
        icon: "fas fa-network-wired",
        hasChildren: devices.length > 0,
        data: { kind: "snmp_devices_group", devices },
    };
}

function makeSnmpDeviceNode(d) {
    return {
        id: `snmp_device:${d.ip}`,
        name: d.name || d.ip,
        icon: "bi bi-router",
        color: d.is_active ? "#2fb344" : undefined,
        hasChildren: false,
        data: { kind: "snmp_device", device: d },
    };
}

/* Fetches the sub sites + networks + exporters of siteId and maps them to
   NodeDescriptors */
async function fetchSiteLevel(siteId) {
    try {
        const data = await fetchSiteHierarchy(siteId);

        const rawSites = data?.sites || {};
        const siteList = Array.isArray(rawSites) ? rawSites : Object.values(rawSites);
        const exporterList = Array.isArray(data?.exporters) ? data.exporters : [];
        const networkList = Array.isArray(data?.networks) ? data.networks : [];
        const snmpDeviceList = Array.isArray(data?.snmp_devices) ? data.snmp_devices : [];

        const siteNodes = siteList
            .filter((s) => String(s.id) !== "0" || siteId === null)
            .map((s) => ({
                id: `site:${s.id}`,
                name: s.name,
                icon: "bi bi-geo-alt-fill",
                data: { kind: "site", site: s },
            }));

        const exportersByNetwork = new Map();
        const unassignedExporters = [];
        exporterList.forEach((e) => {
            if (e.network_id == null) {
                unassignedExporters.push(e);
                return;
            }
            const key = String(e.network_id);
            if (!exportersByNetwork.has(key)) exportersByNetwork.set(key, []);
            exportersByNetwork.get(key).push(e);
        });

        const snmpDevicesByNetwork = new Map();
        const unassignedSnmpDevices = [];
        snmpDeviceList.forEach((d) => {
            if (d.network_id == null) {
                unassignedSnmpDevices.push(d);
                return;
            }
            const key = String(d.network_id);
            if (!snmpDevicesByNetwork.has(key)) snmpDevicesByNetwork.set(key, []);
            snmpDevicesByNetwork.get(key).push(d);
        });

        const networkNodes = networkList.map((n) => {
            const netExporters = exportersByNetwork.get(String(n.id)) || [];
            const netSnmpDevices = snmpDevicesByNetwork.get(String(n.id)) || [];
            return {
                id: `network:${siteId ?? DEFAULT_SITE_ID}:${n.id}`,
                name: n.name,
                icon: "bi bi-diagram-3-fill",
                hasChildren: netExporters.length > 0 || netSnmpDevices.length > 0,
                data: { kind: "network", network: n, exporters: netExporters, snmpDevices: netSnmpDevices },
            };
        });

        const exporterNodes = unassignedExporters.map((e) => makeExporterNode(e));
        const snmpDeviceGroupNodes = unassignedSnmpDevices.length > 0
            ? [makeSnmpDevicesGroupNode(`site:${siteId ?? DEFAULT_SITE_ID}`, unassignedSnmpDevices)]
            : [];

        return [...siteNodes, ...networkNodes, ...exporterNodes, ...snmpDeviceGroupNodes]
            .sort((a, b) => a.name.localeCompare(b.name));
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

/* Fetches the interfaces of one bare SNMP device (no flow exporter) and maps
   them to leaf NodeDescriptors, mirroring fetchExporterInterfaceNodes but
   sourced from snmp/metric/interfaces.lua (same endpoint the Analysis table
   in snmp-traffic-dashboard.vue uses), since these devices have no
   exporters_interfaces.lua entry. */
async function fetchSnmpDeviceInterfaceNodes(device) {
    try {
        const url_params = ntopng_url_manager.obj_to_url_params({
            host: device.ip,
            start: 0,
            length: 1000,
        });
        const url = `${http_prefix}/lua/pro/rest/v2/get/snmp/metric/interfaces.lua?${url_params}`;
        const data = await ntopng_utility.http_request(url);
        const list = Array.isArray(data?.rsp) ? data.rsp : [];

        return list.map((iface) => ({
            id: `snmp_interface:${device.ip}:${iface.interface_id}`,
            name: iface.interface_name != null ? String(iface.interface_name) : `ifIndex ${iface.interface_id}`,
            icon: "bi bi-ethernet",
            hasChildren: false,
            data: { kind: "snmp_interface", device, iface: { ...iface, ifindex: iface.interface_id, snmp_ifname: iface.interface_name } },
        }));
    } catch (err) {
        console.error("Error retrieving SNMP device interfaces:", err);
        return [];
    }
}

/* The sidebar tree is the one place that already knows a node's real ancestor
   chain — see handleSelectExporter/handleSelectInterface. */
async function handleSidebarSelect(node, ancestors) {
    if (node.data.kind === "site") {
        await handleSelectSite(node.data.site, ancestors);
        return;
    }

    const siteAncestors = [];
    let containingSite = { id: DEFAULT_SITE_ID, name: _i18n("sites_dashboard.default_site") };
    for (const crumb of ancestors) {
        if (typeof crumb.id === "string" && crumb.id.startsWith("site:")) {
            if (containingSite.id !== DEFAULT_SITE_ID) siteAncestors.push({ id: `site:${containingSite.id}`, name: containingSite.name });
            containingSite = { id: crumb.id.slice("site:".length), name: crumb.name };
        }
    }

    if (String(selectedSite.value?.id) !== String(containingSite.id)) {
        await handleSelectSite(containingSite, siteAncestors);
    }

    if (node.data.kind === "network") {
        handleSelectNetwork(node.data.network);
    } else if (node.data.kind === "exporter") {
        await handleSelectExporter(node.data.exporter);
    } else if (node.data.kind === "interface") {
        handleSelectInterface(node.data.iface, node.data.exporter);
    } else if (node.data.kind === "snmp_devices_group") {
        // Non-selectable grouping node with no page of its own: clicking its
        // label (not just the chevron) also expands it, same as clicking any
        // other row would normally navigate somewhere.
        await sidebar.value?.expandTo([node.id]);
    } else if (node.data.kind === "snmp_device") {
        handleSelectSnmpDevice(node.data.device);
    }
}

/* Clicking any crumb jumps straight back to that exact node. */
async function handleBreadcrumbSelect(item) {
    if (typeof item.id !== "string") return;

    if (item.id.startsWith("site:")) {
        const siteId = item.id.slice("site:".length);
        if (String(selectedSite.value?.id) === siteId) {
            // Already the selected site: clicking it again means "go back up
            // to the site view", clearing whatever network/exporter/interface
            // was drilled into below it.
            await handleSelectSite(selectedSite.value, selectedSiteAncestors.value);
            return;
        }
        const { site, ancestors } = await resolveSiteChain(siteId);
        await handleSelectSite(site, ancestors);
    } else if (item.id.startsWith("network:") && selectedNetwork.value) {
        handleSelectNetwork(selectedNetwork.value);
    } else if (item.id.startsWith("exporter:") && selectedExporter.value) {
        await handleSelectExporter(selectedExporter.value);
    } else if (item.id.startsWith("snmp_devices:") && selectedNetwork.value) {
        // "SNMP Devices" crumb: go back up to the network's grouping view
        // (there's no dedicated tab for it yet, so fall back to the network).
        handleSelectNetwork(selectedNetwork.value);
    } else if (item.id.startsWith("snmp_device:") && selectedSnmpDevice.value) {
        handleSelectSnmpDevice({ ip: selectedSnmpDevice.value.id, name: selectedSnmpDevice.value.name, network_id: selectedNetwork.value?.id });
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
    min-height: 100vh;
}

.sites-dashboard-topbar {
    padding: 14px 20px;
    border-bottom: 1px solid var(--border-color);
    background: var(--bg-base);
    position: sticky;
    top: 3rem;
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

<!-- shared by every sites-dashboard sub-component's clickable table
     (network/exporters/exporter-traffic dashboards)-->
<style>
.sites-dashboard-clickable-table tbody tr {
    cursor: pointer;
    transition: background-color 0.12s ease;
}

.sites-dashboard-clickable-table tbody tr:hover {
    background-color: var(--ntop-row-hover-bg, rgba(234, 106, 42, 0.08));
}

.sites-dashboard-row-link {
    color: var(--ntop-orange);
    text-decoration: underline;
    text-decoration-color: currentColor;
    text-underline-offset: 2px;
    transition: color 0.12s ease;
}

.sites-dashboard-clickable-table tbody tr:hover .sites-dashboard-row-link {
    color: var(--ntop-orange-dark, var(--ntop-orange));
}

.sites-dashboard-ts {
    display: flex;
    flex-direction: column;
    flex: 1 1 auto;
    height: 100%;
    min-height: 460px;
}
</style>

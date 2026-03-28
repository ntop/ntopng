/**
    (C) 2022 - ntop.org    
*/

import * as Vue from "vue";
// window.Vue = Vue;

// pages
import { default as PageAlertStats } from "./page-alert-stats.vue";
import { default as PageFlowHistorical } from "./page-flow-historical.vue";
import { default as PageStats } from "./page-stats.vue";
import { default as PageAssetTable } from "./page-asset-table.vue";
import { default as PagePeriodicityTable } from "./page-periodicity-table.vue";
import { default as PageServiceTable } from "./page-service-table.vue";
import { default as PageServiceMap } from "./page-service-map.vue";
import { default as PagePeriodicityMap } from "./page-periodicity-map.vue";
import { default as PageAssetMap } from "./page-asset-map.vue";
import { default as PageDeviceExclusions } from "./page-device-exclusions.vue";
import { default as PageHostTLS } from "./page-host-tls.vue";
import { default as PageHostSSH } from "./page-host-ssh.vue";
import { default as PageHomeMap } from "./page-home-map.vue";
import { default as PageHostDetailsApplications } from "./page-host-details-applications.vue";
import { default as PageHostDetailsTraffic } from "./page-host-details-traffic.vue";
import { default as PageHostDetailsPackets } from "./page-host-details-packets.vue";
import { default as PageHostDetailsFlowSankey } from "./page-host-details-flow-sankey.vue";
import { default as PageHostRules } from "./page-traffic-rules.vue";
import { default as PageHostDetailsPorts } from "./page-host-details-ports.vue";
import { default as PageAlertAnalysis } from "./page-alert-analysis.vue";
import { default as PageHostMap } from "./page-host-map.vue";
import { default as PageVLANPortsSankey } from "./page-vlan-ports-sankey.vue";
import { default as PageAggregatedLiveFlows } from "./page-aggregated-live-flows.vue";
import { default as PageTestTable } from "./page-test-table.vue";
import { default as NedgeRulesConfig } from "./page-nedge-rules-config.vue";
import { default as PageEditApplications } from "./page-edit-applications.vue";
import { default as PageEditCategories } from "./page-edit-categories.vue";
import { default as ModalEditCategory } from "./modal-edit-category.vue";
import { default as PageEditConfigset } from "./page-edit-configset.vue";
import { default as PageEditCheck } from "./page-edit-check.vue";
import { default as PageNetworkDiscovery } from "./page-network-discovery.vue";
import { default as PageManageConfigurationBackup } from "./page-manage-configurations-backup.vue";
import { default as PageManageConfigurations } from "./page-manage-configurations.vue";
import { default as PageSNMPDeviceRules } from "./page-snmp-device-rules.vue";
import { default as PageServerPorts } from "./page-server-ports.vue";
import { default as NedgeRepeatersConfig } from "./page-nedge-repeaters-config.vue";
import { default as PageExportersConfig } from "./page-flowdevice-config.vue";
import { default as PageFlowDeviceInterfaceDetails } from "./page-flowdevice-interface-config.vue";
import { default as PageVulnerabilityScan } from "./page-vulnerability-scan.vue";
import { default as PageHostVsResult } from "./page-host-vs-result.vue";
import { default as PageOpenPorts } from "./page-open-ports.vue";
import { default as PageVulnerabilityScanReport } from "./page-vulnerability-scan-report.vue"
import { default as PageSNMPUsage } from "./page-snmp-usage.vue"
import { default as PageHostsList } from "./page-hosts-list.vue"
import { default as PageFlowsList } from "./page-flows-list.vue"
import { default as PageMacsList } from "./page-macs-list.vue"
import { default as PageInterfaceICMP } from "./page-interface-icmp.vue"
import { default as PageLabels } from "./page-labels.vue"
import { default as PageExporterSites } from "./page-exporter-sites.vue"
import { default as PageSNMPInterfaces } from "./page-snmp-interfaces.vue"
import { default as PageSNMPTopology } from "./page-snmp-topology.vue"
import { default as PageSNMPTopologyMap } from "./page-snmp-topology-map.vue"
import { default as PageSNMPSimilarity } from "./page-snmp-similarity.vue"
import { default as PageSNMPDevices } from "./page-snmp-devices.vue"
import { default as PageBlacklists } from "./page-blacklists.vue"
import { default as PageHistoricalFlow } from "./page-historical-flow-details.vue"
import { default as PageSNMPQoS } from "./page-snmp-qos.vue"
import { default as PageGeoMap } from "./hosts-geomap.vue"
import { default as PageCountryStats } from "./page-country-stats.vue"
import { default as PageHostPools } from "./page-host-pools.vue"
import { default as PageManageHostPoolMembers } from "./page-manage-host-members.vue"
import { default as PagePoolPolicy } from "./page-pool-policy.vue"
import { default as PageUploadPcap } from "./page-upload-pcap.vue"
import { default as PageRedisStats } from "./page-redis-stats.vue"
import { default as PageAsStats } from "./page-as-stats.vue"
import { default as PageExportersInterfacesStats } from "./page-exporters-interfaces-stats.vue"
import { default as PageAsOverview } from "./page-as-overview.vue"
import { default as PageProbes } from "./page-probes.vue"
import { default as PageExporters } from "./page-exporters.vue"
import { default as PageExportersInterfaces } from "./page-exporters-interfaces.vue"
import { default as PageNetworkConfiguration } from "./page-network-configuration.vue"
import { default as PageASNConfiguration } from "./page-asn-configuration.vue"
import { default as PageNetworkPolicy } from "./page-network-policy.vue"
import { default as PageLimits } from "./page-limits.vue"
import { default as PageLocalHostsReport } from "./page-local-hosts-report.vue"
import { default as PageAssets } from "./page-assets.vue"
import { default as PageAssetDetails } from "./page-asset-details.vue"
import { default as PageAssetDetailsNew } from "./page-asset-details-new.vue"
import { default as PageAccessControlList } from "./page-access-control-list.vue"
import { default as PageTopInterfaceApplications } from "./page-top-interface-applications.vue"
import { default as PageTopInterfaceCategories } from "./page-top-interface-categories.vue"
import { default as PageObservationPoints } from "./page-observation-points.vue"
import { default as PageObservationPointsConfig } from "./page-observation-points-config.vue"
import { default as PageObservationPointsList } from "./page-flow-exporters-list.vue"
import { default as PageActiveMonitoring } from "./page-active-monitoring.vue"
import { default as PageAlertsGraph } from "./page-alerts-graph.vue"
import { default as PageAlertsGeoMap } from "./page-alerts-geomap.vue"
import { default as PageTrafficProfiles } from "./page-traffic-profiles.vue"
import { default as PageNetworksList } from "./page-networks-list.vue"
import { default as PageDHCPLeases } from "./page-DHCP-leases.vue"
import { default as PageExporterInterfaceOverview } from "./page-exporter-interface-overview.vue"
import { default as PageExporterMap } from "./page-exporter-map.vue"
import { default as PageExportersGraph } from "./pages/page-graph.vue"
import { default as PageAbout } from "./page-about.vue"
import { default as PageLicense } from "./page-license.vue"
import { default as PageDirectories } from "./page-directories.vue"
import { default as PageTsOverview } from "./page-ts-overview.vue"
import { default as PageDefsOverview } from "./page-defs-overview.vue"
import { default as PageChecksOverview } from "./page-checks-overview.vue"
import { default as PageManageData } from "./page-manage-data.vue"
import { default as PageEditDeviceProtocols } from "./page-edit-device-protocols.vue"

/* Testing page */
import { default as PageTest } from "./page-test.vue";

/* Flow Details pages */
//import { default as PageFlowDetails } from "./page-flow-details.vue"
import { default as PageFlowDetailsModbus } from "./page-flow-details-modbus.vue"
import { default as PageFlowDetailsS7Comm } from "./page-flow-details-s7comm.vue"
import { default as PageFlowDetailsProfinet } from "./page-flow-details-profinet.vue"

/* Config pages */
import { default as PageSNMPConfig } from "./page-snmp-config.vue"
import { default as PageHostConfig } from "./page-host-config.vue"
import { default as PageTrafficRules } from "./page-traffic-rules.vue"

// components
import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import { default as Datatable } from "./datatable.vue";
import { default as NetworkMap } from "./network-map.vue";
import { default as DateTimeRangePicker } from "./date-time-range-picker.vue";
import { default as PageNavbar } from "./page-navbar.vue";
import { default as RangePicker } from "./range-picker.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as TabList } from "./tab-list.vue";
import { default as Sankey } from "./sankey.vue";
import { default as Chord } from "./chord-chart.vue";
import { default as NoteList } from "./note-list.vue";
import { default as Loading } from "./loading.vue";
import { default as SearchBox } from "./components/search-box.vue";
import { default as NoData } from "./components/no-data.vue";
import { default as NavbarTabs } from "./components/navbar-tabs.vue";

// dashboard
import { default as Dashboard } from "./dashboard.vue";
import { default as DashboardBox } from "./dashboard-box.vue";
import { default as DashboardEmpty } from "./dashboard-empty.vue";
import { default as DashboardTable } from "./dashboard-table.vue";
import { default as DashboardBadge } from "./dashboard-badge.vue";
import { default as DashboardPie } from "./dashboard-pie.vue";
import { default as DashboardTimeseries } from "./dashboard-timeseries.vue";
import { default as DashboardSankey } from "./dashboard-sankey.vue";

// list
import { default as ListTimeseries } from "./list-timeseries.vue";

// modals
import { default as Modal } from "./modal.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddCheckExclusion } from "./modal-add-check-exclusion.vue";
import { default as ModalAddDeviceExclusion } from "./modal-add-device-exclusion.vue";
import { default as ModalEditDeviceExclusion } from "./modal-edit-device-exclusion.vue";
import { default as ModalAlertsFilter } from "./modal-alerts-filter.vue";
import { default as ModalFilters } from "./modal-filters.vue";
import { default as ModalTimeseries } from "./modal-timeseries.vue";
import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";
import { default as ModalSnapshot } from "./modal-snapshot.vue";
import { default as ModalAddHostRules } from "./modal-add-traffic-rules.vue";
import { default as ModalAddApplication } from "./modal-add-application.vue";
import { default as ModalDeleteApplication } from "./modal-delete-application.vue";
import { default as ModalEditReport } from "./modal-edit-vs-report.vue";
import { default as ModalAddSNMPDevice } from "./modal-add-snmp-device.vue";
import { default as ModalDeleteSNMPDevice } from "./modal-delete-snmp-device.vue";
import { default as ModalImportSNMPDevices } from "./modal-import-snmp-devices.vue";
import { default as ModalEditBlacklist } from "./modal-edit-blacklist.vue";
import { default as ModalAddACLRule } from "./modal-add-acl-rule.vue";
import { default as ModalEditACLRule } from "./modal-edit-acl-rule.vue";
import { default as ModalDeleteACLRule } from "./modal-delete-acl-rule.vue";
import { default as ModalDeleteAllACLRule } from "./modal-delete-all-acl-rules.vue";

/* Charts */
import { default as MultiPieChart } from "./charts/multi-pie-chart.vue";
import { default as PieChart } from "./charts/pie-chart.vue";
import { default as LineChart } from "./charts/line-chart.vue";
import { default as PeityChart } from "./charts/peity.vue";

import { default as Chatbot } from "./chatbot.vue";

let ntopVue = {
    Chatbot: Chatbot,
    
    // graphs
    MultiPieChart: MultiPieChart,
    PieChart: PieChart,
    PeityChart: PeityChart,
    LineChart: LineChart,
    
    // pages
    PageAlertStats: PageAlertStats,
    PageFlowHistorical: PageFlowHistorical,
    PageStats: PageStats,
    PageAssetTable: PageAssetTable,
    PagePeriodicityTable: PagePeriodicityTable,
    PageServiceTable: PageServiceTable,
    PageServiceMap: PageServiceMap,
    PagePeriodicityMap: PagePeriodicityMap,
    PageAssetMap: PageAssetMap,
    PageDeviceExclusions: PageDeviceExclusions,
    PageHostTLS: PageHostTLS,
    PageHostSSH: PageHostSSH,
    PageHomeMap: PageHomeMap,
    PageHostRules: PageHostRules,
    PageAlertAnalysis: PageAlertAnalysis,
    PageHostMap: PageHostMap,
    PageManageConfigurationBackup: PageManageConfigurationBackup,
    PageManageConfigurations: PageManageConfigurations,
    PageSNMPDeviceRules: PageSNMPDeviceRules,
    PageServerPorts: PageServerPorts,
    PageVulnerabilityScan: PageVulnerabilityScan,
    PageHostVsResult: PageHostVsResult,
    PageOpenPorts: PageOpenPorts,
    PageVulnerabilityScanReport: PageVulnerabilityScanReport,
    PageFlowsList: PageFlowsList,
    PageMacsList: PageMacsList,
    PageInterfaceICMP: PageInterfaceICMP,
    PageLabels: PageLabels,
    PageExporterSites: PageExporterSites,
    PageAsStats: PageAsStats,
    PageExportersInterfacesStats: PageExportersInterfacesStats,
    PageAsOverview: PageAsOverview,
    PageProbes: PageProbes,
    PageExportersInterfaces: PageExportersInterfaces,
    PageLimits: PageLimits,
    PageLocalHostsReport: PageLocalHostsReport,
    PageAssets: PageAssets,
    PageAssetDetails: PageAssetDetails,
    PageAssetDetailsNew: PageAssetDetailsNew,
    PageAccessControlList: PageAccessControlList,
    PageTopInterfaceApplications: PageTopInterfaceApplications,
    PageTopInterfaceCategories: PageTopInterfaceCategories,
    PageObservationPoints: PageObservationPoints,
    PageObservationPointsConfig: PageObservationPointsConfig,
    PageObservationPointsList: PageObservationPointsList,
    PageActiveMonitoring: PageActiveMonitoring,
    PageHostPools: PageHostPools,
    PageManageHostPoolMembers: PageManageHostPoolMembers,
    PagePoolPolicy: PagePoolPolicy,
    PageTrafficProfiles: PageTrafficProfiles,
    PageDHCPLeases: PageDHCPLeases,
    PageExporterInterfaceOverview: PageExporterInterfaceOverview,
    PageExporterMap: PageExporterMap,
    PageManageData: PageManageData,
    PageEditDeviceProtocols: PageEditDeviceProtocols,

    PageExportersGraph: PageExportersGraph,
    PageAbout: PageAbout,
    PageLicense: PageLicense,
    PageDirectories: PageDirectories,
    PageTsOverview: PageTsOverview,
    PageDefsOverview: PageDefsOverview,
    PageChecksOverview: PageChecksOverview,

    /* Testing page */
    PageTest: PageTest,

    /* Flow Details pages */
    //PageFlowDetails: PageFlowDetails,
    PageFlowDetailsModbus: PageFlowDetailsModbus,
    PageFlowDetailsS7Comm: PageFlowDetailsS7Comm,
    PageFlowDetailsProfinet: PageFlowDetailsProfinet,
    
    /* SNMP */
    PageSNMPDevices: PageSNMPDevices,
    PageSNMPQoS: PageSNMPQoS,
    PageSNMPConfig: PageSNMPConfig,
    PageSNMPUsage: PageSNMPUsage,
    PageSNMPInterfaces: PageSNMPInterfaces,
    PageSNMPTopology: PageSNMPTopology,
    PageSNMPTopologyMap: PageSNMPTopologyMap,
    PageSNMPSimilarity: PageSNMPSimilarity,

    PageEditApplications: PageEditApplications,
    PageEditCategories: PageEditCategories,
    PageEditConfigset: PageEditConfigset,
    PageEditCheck: PageEditCheck,
    ModalEditCategory: ModalEditCategory,

    PageVLANPortsSankey: PageVLANPortsSankey,
    PageTestTable: PageTestTable,

    NedgeRulesConfig: NedgeRulesConfig,
    NedgeRepeatersConfig: NedgeRepeatersConfig,

    PageBlacklists: PageBlacklists,
    //PageChatbot: PageChatbot,

    // Host details pages
    PageHostDetailsApplications: PageHostDetailsApplications,
    PageHostDetailsTraffic: PageHostDetailsTraffic,
    PageHostDetailsPackets: PageHostDetailsPackets,
    PageHostDetailsFlowSankey: PageHostDetailsFlowSankey,
    PageHostDetailsPorts: PageHostDetailsPorts,
    PageHostsList: PageHostsList,
    PageGeoMap: PageGeoMap,
    PageHostConfig: PageHostConfig,
    PageCountryStats: PageCountryStats,
    PageUploadPcap: PageUploadPcap,
    PageRedisStats: PageRedisStats,
    PageExporters: PageExporters,
    PageAggregatedLiveFlows: PageAggregatedLiveFlows,
    PageNetworkDiscovery: PageNetworkDiscovery,
    PageExportersConfig: PageExportersConfig,
    PageFlowDeviceInterfaceDetails: PageFlowDeviceInterfaceDetails,
    PageHistoricalFlow: PageHistoricalFlow,
    PageNetworkConfiguration: PageNetworkConfiguration,
    PageASNConfiguration: PageASNConfiguration,
    PageNetworkPolicy: PageNetworkPolicy,
    PageTrafficRules: PageTrafficRules,
    PageAlertsGraph: PageAlertsGraph,
    PageAlertsGeoMap: PageAlertsGeoMap,
    PageNetworksList: PageNetworksList,
    
    // components
    AlertInfo: AlertInfo,
    Chart: Chart,
    TimeseriesChart: TimeseriesChart,
    SearchBox: SearchBox,
    Datatable: Datatable,
    DateTimeRangePicker: DateTimeRangePicker,
    NetworkMap: NetworkMap,
    RangePicker: RangePicker,
    PageNavbar: PageNavbar,
    SelectSearch: SelectSearch,
    TabList: TabList,
    Sankey: Sankey,
    Chord: Chord,
    NoteList: NoteList,
    Loading: Loading,
    NoData: NoData,
    NavbarTabs: NavbarTabs,

    // dashboard
    Dashboard: Dashboard,
    DashboardBox: DashboardBox,
    DashboardEmpty: DashboardEmpty,
    DashboardTable: DashboardTable,
    DashboardBadge: DashboardBadge,
    DashboardPie: DashboardPie,
    DashboardTimeseries: DashboardTimeseries,
    DashboardSankey: DashboardSankey,

    // list
    ListTimeseries: ListTimeseries,

    // modals
    Modal: Modal,
    ModalAddCheckExclusion: ModalAddCheckExclusion,
    ModalAlertsFilter: ModalAlertsFilter,
    ModalFilters: ModalFilters,
    ModalTimeseries: ModalTimeseries,
    ModalTrafficExtraction: ModalTrafficExtraction,
    ModalDeleteConfirm: ModalDeleteConfirm,
    ModalSnapshot: ModalSnapshot,
    ModalAddDeviceExclusion: ModalAddDeviceExclusion,
    ModalEditDeviceExclusion: ModalEditDeviceExclusion,
    ModalAddHostRules: ModalAddHostRules,
    ModalAddApplication: ModalAddApplication,
    ModalDeleteApplication: ModalDeleteApplication,
    ModalEditReport: ModalEditReport,
    ModalAddSNMPDevice: ModalAddSNMPDevice,
    ModalDeleteSNMPDevice: ModalDeleteSNMPDevice,
    ModalImportSNMPDevices: ModalImportSNMPDevices,
    ModalEditBlacklist: ModalEditBlacklist,
    ModalAddACLRule: ModalAddACLRule,
    ModalEditACLRule: ModalEditACLRule,
    ModalDeleteACLRule: ModalDeleteACLRule,
    ModalDeleteAllACLRule: ModalDeleteAllACLRule,

    Vue: Vue,
};
window.ntopVue = ntopVue;

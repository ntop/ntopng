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
import { default as PageSankey } from "./page-sankey.vue";
import { default as PageHostDetailsApplications } from "./page-host-details-applications.vue";
import { default as PageHostDetailsTraffic } from "./page-host-details-traffic.vue";
import { default as PageHostDetailsPackets } from "./page-host-details-packets.vue";
import { default as PageHostDetailsFlowSankey } from "./page-host-details-flow-sankey.vue";
import { default as PageHostRules } from "./page-host-rules.vue";
import { default as PageHostDetailsPorts } from "./page-host-details-ports.vue";
import { default as PageAlertAnalysis } from "./page-alert-analysis.vue";
import { default as PageHostMap } from "./page-host-map.vue";
import { default as PageVLANPortsSankey } from "./page-vlan-ports-sankey.vue";
import { default as PageAggregatedLiveFlows } from "./page-aggregated-live-flows.vue";
import { default as PageAggregatedLiveFlowsV2 } from "./page-aggregated-live-flows-v2.vue";
import { default as PageTestTable } from "./page-test-table.vue";
import { default as NedgeRulesConfig } from "./page-nedge-rules-config.vue";
import { default as PageEditApplications } from "./page-edit-applications.vue";
import { default as PageNetworkDiscovery } from "./page-network-discovery.vue";
import { default as PageManageConfigurationBackup } from "./page-manage-configurations-backup.vue";
import { default as PageManageConfigurationBackup2 } from "./page-manage-configurations-backup2.vue";
import { default as PageSNMPDeviceRules } from "./page-snmp-device-rules.vue";
import { default as PageSnmpDevicesInterfacesSimilarity } from "./page-snmp-devices-interfaces-similarity.vue";
import { default as PageHostsPortsAnalysis } from "./page-hosts-ports-analysis.vue";
import { default as NedgeRepeatersConfig } from "./page-nedge-repeaters-config.vue";
import { default as PageInactiveHosts } from "./page-inactive-hosts.vue";
import { default as PageInactiveHostDetails } from "./page-inactive-host-details.vue";
import { default as PageFlowDeviceDetails } from "./page-flowdevice-config.vue";

// components
import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as TimeseriesChart } from "./timeseries-chart.vue";
import { default as Datatable } from "./datatable.vue";
import { default as NetworkMap } from "./network-map.vue";
import { default as DateTimeRangePicker } from "./data-time-range-picker.vue";
import { default as PageNavbar } from "./page-navbar.vue";
import { default as RangePicker } from "./range-picker.vue";
import { default as SimpleTable } from "./simple-table.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as TabList } from "./tab-list.vue";
import { default as Sankey } from "./sankey.vue";
import { default as NoteList } from "./note-list.vue";
import { default as Loading } from "./loading.vue";

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
import { default as ModalAddHostRules } from "./modal-add-host-rules.vue";
import { default as ModalAddApplication } from "./modal-add-application.vue";
import { default as ModalDeleteApplication } from "./modal-delete-application.vue";

let ntopVue = {
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
    PageSankey: PageSankey,
    PageHostRules: PageHostRules,
    PageAlertAnalysis: PageAlertAnalysis,
    PageHostMap: PageHostMap,
    PageManageConfigurationBackup: PageManageConfigurationBackup,
    PageManageConfigurationBackup2: PageManageConfigurationBackup2,
    PageSNMPDeviceRules: PageSNMPDeviceRules,
    PageHostsPortsAnalysis: PageHostsPortsAnalysis,
    PageInactiveHosts: PageInactiveHosts,
    PageInactiveHostDetails: PageInactiveHostDetails,

    PageEditApplications: PageEditApplications,

    PageVLANPortsFlowSankey: PageVLANPortsSankey,
    PageTestTable: PageTestTable,
    PageSnmpDevicesInterfacesSimilarity: PageSnmpDevicesInterfacesSimilarity,

    NedgeRulesConfig: NedgeRulesConfig,
    NedgeRepeatersConfig: NedgeRepeatersConfig,


    // Host details pages
    PageHostDetailsApplications: PageHostDetailsApplications,
    PageHostDetailsTraffic: PageHostDetailsTraffic,
    PageHostDetailsPackets: PageHostDetailsPackets,
    PageHostDetailsFlowSankey: PageHostDetailsFlowSankey,
    PageHostDetailsPorts: PageHostDetailsPorts,

    PageAggregatedLiveFlows: PageAggregatedLiveFlows,
    PageAggregatedLiveFlowsV2: PageAggregatedLiveFlowsV2,

    PageNetworkDiscovery: PageNetworkDiscovery,

    PageFlowDeviceDetails: PageFlowDeviceDetails,

    // components
    AlertInfo: AlertInfo,
    Chart: Chart,
    TimeseriesChart: TimeseriesChart,
    Datatable: Datatable,
    DateTimeRangePicker: DateTimeRangePicker,
    NetworkMap: NetworkMap,
    RangePicker: RangePicker,
    PageNavbar: PageNavbar,
    SimpleTable: SimpleTable,
    SelectSearch: SelectSearch,
    TabList: TabList,
    Sankey: Sankey,
    NoteList: NoteList,
    Loading: Loading,

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

    Vue: Vue,
};
window.ntopVue = ntopVue;

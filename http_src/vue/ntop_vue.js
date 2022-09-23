import * as Vue from "vue";
// window.Vue = Vue;

// pages
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

// components
import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as Datatable } from "./datatable.vue";
import { default as NetworkMap } from "./network-map.vue";
import { default as DateTimeRangePicker } from "./data-time-range-picker.vue";
import { default as PageNavbar } from "./page-navbar.vue";
import { default as RangePicker } from "./range-picker.vue";
import { default as SimpleTable } from "./simple-table.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as TabList } from "./tab-list.vue";

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

let ntopVue = {
    // pages
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
    
    // components
    AlertInfo: AlertInfo,
    Chart: Chart,
    Datatable: Datatable,
    DateTimeRangePicker: DateTimeRangePicker,
    NetworkMap: NetworkMap,
    RangePicker: RangePicker,
    PageNavbar: PageNavbar,
    SimpleTable: SimpleTable,
    SelectSearch: SelectSearch,
    TabList: TabList,
    
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

    Vue: Vue,
};
window.ntopVue = ntopVue;

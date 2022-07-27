import * as Vue from "vue";
// window.Vue = Vue;

// pages
import { default as PageStats } from "./page-stats.vue";

// components
import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as Datatable } from "./datatable.vue";
import { default as DateTimeRangePicker } from "./data-time-range-picker.vue";
import { default as PageNavbar } from "./page-navbar.vue";
import { default as RangePicker } from "./range-picker.vue";
import { default as SimpleTable } from "./simple-table.vue";

// modals
import { default as Modal } from "./modal.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddCheckExclusion } from "./modal-add-check-exclusion.vue";
import { default as ModalAlertsFilter } from "./modal-alerts-filter.vue";
import { default as ModalFilters } from "./modal-filters.vue";
import { default as ModalTimeseries } from "./modal-timeseries.vue";
import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";
import { default as ModalSnapshot } from "./modal-snapshot.vue";

let ntopVue = {
    // pages
    PageStats: PageStats,
    
    // components
    AlertInfo: AlertInfo,
    Chart: Chart,
    Datatable: Datatable,
    DateTimeRangePicker: DateTimeRangePicker,
    RangePicker: RangePicker,
    PageNavbar: PageNavbar,
    SimpleTable: SimpleTable,

    // modals
    Modal: Modal,
    ModalAddCheckExclusion: ModalAddCheckExclusion,
    ModalAlertsFilter: ModalAlertsFilter,
    ModalFilters: ModalFilters,
    ModalTimeseries: ModalTimeseries,
    ModalTrafficExtraction: ModalTrafficExtraction,
    ModalDeleteConfirm: ModalDeleteConfirm,
    ModalSnapshot: ModalSnapshot,

    Vue: Vue,
};
window.ntopVue = ntopVue;

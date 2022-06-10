import * as Vue from "vue";
// window.Vue = Vue;

import { default as AlertInfo } from "./alert-info.vue";
import { default as Chart } from "./chart.vue";
import { default as Datatable } from "./datatable.vue";
import { default as DateTimeRangePicker } from "./data-time-range-picker.vue";

import { default as Modal } from "./modal.vue";
import { default as ModalDeleteConfirm } from "./modal-delete-confirm.vue";
import { default as ModalAddCheckExclusion } from "./modal-add-check-exclusion.vue";
import { default as ModalFilters } from "./modal-filters.vue";
import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";

import { default as PageNavbar } from "./page-navbar.vue";
import { default as RangePicker } from "./range-picker.vue";

let ntopVue = {
    AlertInfo: AlertInfo,
    Chart: Chart,
    Datatable: Datatable,
    DateTimeRangePicker: DateTimeRangePicker,

    Modal: Modal,
    ModalAddCheckExclusion: ModalAddCheckExclusion,
    ModalFilters: ModalFilters,
    ModalTrafficExtraction: ModalTrafficExtraction,
    ModalDeleteConfirm: ModalDeleteConfirm,

    RangePicker: RangePicker,
    PageNavbar: PageNavbar,

    Vue: Vue,
};
window.ntopVue = ntopVue;

import * as Vue from "vue";
// window.Vue = Vue;

import { default as DateTimeRangePicker } from "./data-time-range-picker.vue";
import { default as Chart } from "./chart.vue";
import { default as AlertInfo } from "./alert-info.vue";
import { default as Modal } from "./modal.vue";
import { default as ModalFilters } from "./modal-filters.vue";
import { default as RangePicker } from "./range-picker.vue";
import { default as ModalTrafficExtraction } from "./modal-traffic-extraction.vue";
import { default as PageNavbar } from "./page-navbar.vue";

let ntopVue = {
    DateTimeRangePicker: DateTimeRangePicker,
    Chart: Chart,
    AlertInfo: AlertInfo,
    Modal: Modal,
    ModalFilters: ModalFilters,
    RangePicker: RangePicker,
    ModalTrafficExtraction: ModalTrafficExtraction,
    PageNavbar: PageNavbar,

    Vue: Vue,
};
window.ntopVue = ntopVue;

/* First import jquery */
import $ from 'jquery'

window.jQuery = $
window.$ = $

//import moment from 'moment'
import moment from 'moment-timezone'
import ApexCharts from 'apexcharts'


window.moment = moment
window.ApexCharts = ApexCharts

import 'jquery-ui'
import './scripts/vendors/jquery/jquery.resizableColumns.js';
import './scripts/vendors/jquery/jquery-print.min.js';

import store from 'store-js';
window.store = store;

import Sortable from './scripts/vendors/sortablejs/sortable.core.esm.js';
window.Sortable = Sortable

/* See https://datatables.net/forums/discussion/comment/103356 */
import dt from 'datatables.net-dt'
import 'datatables.net-buttons-dt'
import 'datatables.net-responsive-dt'
window.dt = dt

import 'peity'

import 'flatpickr'
import * as bootstrap from 'bootstrap/dist/js/bootstrap.bundle'

window.bootstrap = bootstrap

import crossfilter from 'crossfilter2'
import * as dc from 'dc'
import * as cubism from 'cubism'

import 'jquery.are-you-sure'

window.crossfilter = crossfilter
window.dc = dc
window.cubism = cubism

import * as vis from 'vis-network/dist/vis-network.esm'

window.vis = vis

import 'select2'
/* 
  Must be included here, otherwise it's not going to work, in fact some 
  external libraries have been changed and added this ntop util functions 
*/

/* regeneratorRuntime error, check https://github.com/babel/babel/issues/9849 */
import regeneratorRuntime from "regenerator-runtime"
import ToastUtils from '../http_src/utilities/toast-utils'
import '../http_src/utilities/string-utils'

/* Generic ntopng Utils */
window.regeneratorRuntime = regeneratorRuntime
window.ToastUtils = ToastUtils

import '../http_src/utilities/datatable/datatable-plugins/api-extension'
import '../http_src/utilities/datatable/datatable-plugins/jquery-extension'

import './third-party-npm.scss'

/* Must add it here otherwise a package error is going to be release */
import 'jquery.are-you-sure'
import { aysGetDirty, aysHandleForm, aysResetForm, aysUpdateForm, aysRecheckForm } from '../http_src/utilities/are-you-sure-utils'

window.aysGetDirty = aysGetDirty
window.aysHandleForm = aysHandleForm
window.aysResetForm = aysResetForm
window.aysUpdateForm = aysUpdateForm
window.aysRecheckForm = aysRecheckForm

import * as d3v7 from "d3v7";

window.d3v7 = {
  ...d3v7
};


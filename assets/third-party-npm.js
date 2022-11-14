/* First import jquery */
import $ from 'jquery'

window.jQuery = $
window.$ = $

//import moment from 'moment'
import moment from 'moment-timezone'
import ApexCharts from 'apexcharts'


window.moment = moment
window.ApexCharts = ApexCharts

import 'jquery-ui-bundle'

/* See https://datatables.net/forums/discussion/comment/103356 */
import 'datatables.net'
import dt from 'datatables.net-dt'
window.dt = dt

import 'datatables.net-buttons'
import 'datatables.net-responsive'
/*
NOTE: It seemes that bs5 datatable components are not correctly working on MacOS
import 'datatables.net-bs'
import 'datatables.net-buttons-bs'
import 'datatables.net-responsive-bs'
*/
import 'peity'
import * as L from 'leaflet'
import 'leaflet.markercluster'

/* See issue https://github.com/PaulLeCam/react-leaflet/issues/255 */
import marker from 'leaflet/dist/images/marker-icon.png';
import marker2x from 'leaflet/dist/images/marker-icon-2x.png';
import markerShadow from 'leaflet/dist/images/marker-shadow.png';

const iconDefault = L.icon({
  iconRetinaUrl: marker2x,
  iconUrl: marker,
  shadowUrl: markerShadow,
});

L.Marker.prototype.options.icon = iconDefault;

window.L = L

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
import * as sankey from "d3-sankey";
import { chord } from "d3-chord";

window.d3v7 = {
    ...d3v7,
    ...sankey,
    ...chord,
};


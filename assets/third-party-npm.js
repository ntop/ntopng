/* First import jquery */
import $ from 'jquery'

window.jQuery = $
window.$ = $

import moment from 'moment'
import ApexCharts from 'apexcharts'


window.moment = moment
window.ApexCharts = ApexCharts

import 'jquery-ui-bundle'
import 'datatables.net-dt'
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
import 'bootstrap/dist/js/bootstrap.bundle'
import crossfilter from 'crossfilter2'
import * as dc from 'dc'
import * as cubism from 'cubism'

import 'jquery.are-you-sure'

window.crossfilter = crossfilter
window.dc = dc
window.cubism = cubism

import 'vis-network'
/* 
  Must be included here, otherwise it's not going to work, in fact some 
  external libraries have been changed and added this ntop util functions 
*/

/* regeneratorRuntime error, check https://github.com/babel/babel/issues/9849 */
import regeneratorRuntime from "regenerator-runtime" 
import ToastUtils from '../http_src/utilities/toast-utils'
import NtopUtils from '../http_src/utilities/ntop-utils'
import '../http_src/utilities/string-utils'

window.regeneratorRuntime = regeneratorRuntime
window.ToastUtils = ToastUtils
window.NtopUtils = NtopUtils



$.fn.dataTable.Api.registerPlural( 'columns().names()', 'column().name()', function ( setter ) {
  return this.iterator( 'column', function ( settings, column ) {
      var col = settings.aoColumns[column];

      if ( setter !== undefined ) {
          col.sName = setter;
          return this;
      }
      else {
          return col.sName;
      }
  }, 1 );
} );


jQuery.fn.dataTableExt.sErrMode = 'console';
jQuery.fn.dataTableExt.formatSecondsToHHMMSS = (data, type, row) => {
    if (isNaN(data)) return data;
    if (type == "display" && data <= 0) return ' ';
    if (type == "display") return NtopUtils.secondsToTime(data);
    return data;
};
jQuery.fn.dataTableExt.absoluteFormatSecondsToHHMMSS = (data, type, row) => {

    if (isNaN(data)) return data;
    if (type == "display" && (data <= 0)) return ' ';

    const delta = Math.floor(Date.now() / 1000) - data;
    if (type == "display") return NtopUtils.secondsToTime(delta);
    return data;
};
jQuery.fn.dataTableExt.sortBytes = (byte, type, row) => {
    if (type == "display") return NtopUtils.bytesToSize(byte);
    return byte;
};
jQuery.fn.dataTableExt.hideIfZero = (value, type, row) => {
    if (type === "display" && parseInt(value) === 0) return "";
    return value;
};
jQuery.fn.dataTableExt.showProgress = (percentage, type, row) => {
    if (type === "display") {
        const fixed = percentage.toFixed(1)
        return `
        <div class="d-flex align-items-center">
        <span class="progress w-100">
          <span class="progress-bar bg-warning" role="progressbar" style="width: ${fixed}%" aria-valuenow="${fixed}" aria-valuemin="0" aria-valuemax="100"></span>
        </span>
        <span>${fixed}%</span>
        </div>
        `
    }
    return percentage;
};

import './third-party-npm.scss'

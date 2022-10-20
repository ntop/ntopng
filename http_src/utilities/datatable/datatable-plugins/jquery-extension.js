/**
 * (C) 2020-21 - ntop.org
 * This file contains datatables.net extensions.
 */

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
/* Extended sorting like written here https://datatables.net/plug-ins/sorting/ */
/** Time sorting */
jQuery.extend(jQuery.fn.dataTableExt.oSort, {
  "time-uni-pre": function (a) {
      var uniTime;
      debugger;

      if (a.toLowerCase().indexOf("am") > -1 || (a.toLowerCase().indexOf("pm") > -1 && Number(a.split(":")[0]) === 12)) {
          uniTime = a.toLowerCase().split("pm")[0].split("am")[0];
          while (uniTime.indexOf(":") > -1) {
              uniTime = uniTime.replace(":", "");
          }
      } else if (a.toLowerCase().indexOf("pm") > -1 || (a.toLowerCase().indexOf("am") > -1 && Number(a.split(":")[0]) === 12)) {
          uniTime = Number(a.split(":")[0]) + 12;
          var leftTime = a.toLowerCase().split("pm")[0].split("am")[0].split(":");
          for (var i = 1; i < leftTime.length; i++) {
              uniTime = uniTime + leftTime[i].trim().toString();
          }
      } else {
          uniTime = a.replace(":", "");
          while (uniTime.indexOf(":") > -1) {
              uniTime = uniTime.replace(":", "");
          }
      }
      return Number(uniTime);
  },

  "time-uni-asc": function (a, b) {
      return ((a < b) ? -1 : ((a > b) ? 1 : 0));
  },

  "time-uni-desc": function (a, b) {
      return ((a < b) ? 1 : ((a > b) ? -1 : 0));
  }
});
/** Bytes sorting */
jQuery.extend(jQuery.fn.dataTableExt.oSort, {
  "bytes-pre": function (a) {
      var uniTime;

      if (a.toLowerCase().indexOf("am") > -1 || (a.toLowerCase().indexOf("pm") > -1 && Number(a.split(":")[0]) === 12)) {
          uniTime = a.toLowerCase().split("pm")[0].split("am")[0];
          while (uniTime.indexOf(":") > -1) {
              uniTime = uniTime.replace(":", "");
          }
      } else if (a.toLowerCase().indexOf("pm") > -1 || (a.toLowerCase().indexOf("am") > -1 && Number(a.split(":")[0]) === 12)) {
          uniTime = Number(a.split(":")[0]) + 12;
          var leftTime = a.toLowerCase().split("pm")[0].split("am")[0].split(":");
          for (var i = 1; i < leftTime.length; i++) {
              uniTime = uniTime + leftTime[i].trim().toString();
          }
      } else {
          uniTime = a.replace(":", "");
          while (uniTime.indexOf(":") > -1) {
              uniTime = uniTime.replace(":", "");
          }
      }
      return Number(uniTime);
  },

  "bytes-asc": function (a, b) {
      return ((a < b) ? -1 : ((a > b) ? 1 : 0));
  },

  "bytes-desc": function (a, b) {
      return ((a < b) ? 1 : ((a > b) ? -1 : 0));
  }
});
jQuery.fn.dataTable.ext.type.order['file-size-pre'] = function ( data ) {
  if (data === null || data === '') {
      return 0;
  }

  var matches = data.match( /^(\d+(?:\.\d+)?)\s*([a-z]+)/i );
  var multipliers = {
      b:  1,
      bytes: 1,
      kb: 1000,
      kib: 1024,
      mb: 1000000,
      mib: 1048576,
      gb: 1000000000,
      gib: 1073741824,
      tb: 1000000000000,
      tib: 1099511627776,
      pb: 1000000000000000,
      pib: 1125899906842624
  };

  if (matches) {
      var multiplier = multipliers[matches[2].toLowerCase()];
      return parseFloat( matches[1] ) * multiplier;
  } else {
      return -1;
  };
};
jQuery.fn.dataTable.ext.type.order['severity-pre'] = function ( data ) {
  if (data === null || data === '') {
      return 0;
  }

  var lowerData = data.toLowerCase()
  var severities = [
    '',
    'none',
    'info',
    'notice',
    'warning',
    'error',
    'critical',
    'emergency',
  ]

  return severities.indexOf(lowerData);
};

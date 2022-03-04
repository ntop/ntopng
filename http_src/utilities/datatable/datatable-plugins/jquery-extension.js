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

/*
  (C) 2013-23 - ntop.org
 */

/*
  Here a list of functions used to check, format data;
  e.g. functions that check if a string is null or empty
 */

/* This function check if value is not set (null or empty).
 * Do not check for 0 as it may be a valid value. */
const QoEQualityBadge = (value) => {
    let badge = ''
    if (value > 90) {
        badge = 'bg-success';
    } else if (value > 75) {
        badge = 'bg-primary'
    } else if (value > 60) {
        badge = 'bg-info'
    } else if (value > 50) {
        badge = 'bg-warning'
    } else {
        badge = 'bg-danger'
    }

    return badge;
}

/* ******************************************************************** */

/* *** NOTE: in order to be able to used these icons, please include in the HTML/vue page
    <script src="https://unpkg.com/lucide@latest"></script> 
*/
/* This function check if value is not set (null or empty).
 * Do not check for 0 as it may be a valid value. */
const QoEQualityIcon = (value) => {
    let icon = ''
    if (value > 90 && value <= 100) {
        icon = '<svg data-bs-toggle="tooltip" data-bs-placement="bottom" title="' + QoEQualityLabel(value) + '" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-signal mb-1 text-success" style="margin-top:-4px;"><path d="M2 20h.01"/><path d="M7 20v-4"/><path d="M12 20v-8"/><path d="M17 20V8"/><path d="M22 4v16"/></svg>';
    } else if (value > 75) {
        icon = '<svg data-bs-toggle="tooltip" data-bs-placement="bottom" title="' + QoEQualityLabel(value) + '" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-signal-high mb-1 text-success" style="margin-top:-4px;"><path d="M2 20h.01"/><path d="M7 20v-4"/><path d="M12 20v-8"/><path d="M17 20V8"/></svg>'
    } else if (value > 60) {
        icon = '<svg data-bs-toggle="tooltip" data-bs-placement="bottom" title="' + QoEQualityLabel(value) + '" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-signal-high mb-1 text-success" style="margin-top:-4px;"><path d="M2 20h.01"/><path d="M7 20v-4"/><path d="M12 20v-8"/><path d="M17 20V8"/></svg>'
    } else if (value > 50) {
        icon = '<svg data-bs-toggle="tooltip" data-bs-placement="bottom" title="' + QoEQualityLabel(value) + '" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-signal-medium mb-1 text-warning" style="margin-top:-4px;"><path d="M2 20h.01"/><path d="M7 20v-4"/><path d="M12 20v-8"/></svg>'
    } else if (value <= 50) {
        icon = '<svg data-bs-toggle="tooltip" data-bs-placement="bottom" title="' + QoEQualityLabel(value) + '" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-signal-low mb-1 text-error" style="margin-top:-4px;"><path d="M2 20h.01"/><path d="M7 20v-4"/></svg>'
    }

    return icon;
}

/* ******************************************************************** */

/* This function check if value is not set (null or empty).
 * Do not check for 0 as it may be a valid value. */
const QoEQualityLabel = (value) => {
    let label = ''
    if (value > 90) {
        label = i18n('flow_details.qoe_excellent_label');
    } else if (value > 75) {
        label = i18n('flow_details.qoe_good_label');
    } else if (value > 60) {
        label = i18n('flow_details.qoe_fair_label');
    } else if (value > 50) {
        label = i18n('flow_details.qoe_degraded_label');
    } else {
        label = i18n('flow_details.qoe_poor_label');
    }

    return label;
}

/* ******************************************************************** */

const dataUtils = function () {
    return {
        QoEQualityBadge,
        QoEQualityLabel,
        QoEQualityIcon,
    };
}();

export default dataUtils;


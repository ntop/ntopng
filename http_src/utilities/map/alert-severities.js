/*
  (C) 2013-24 - ntop.org
 */

const alert_severities = {
    none: {
        severity_id: 0,
        label: "bg-info",
        color: "#a8e4ef",
        icon: "",
        i18n_title: "alerts_dashboard.none",
        syslog_severity: 10,
    },
    debug: {
        severity_id: 1,
        label: "bg-info",
        icon: "fas fa-bug text-info",
        color: "#a8e4ef",
        i18n_title: "alerts_dashboard.debug",
        syslog_severity: 7,
        emoji: "\xE2\x84\xB9"
    },
    info: {
        severity_id: 2,
        label: "bg-info",
        icon: "fas fa-info-circle text-info",
        color: "#c1f0c1",
        i18n_title: "alerts_dashboard.info",
        syslog_severity: 6,
        used_by_alerts: true,
        emoji: "\xE2\x84\xB9"
    },
    notice: {
        severity_id: 3,
        label: "bg-info",
        icon: "fas fa-info-circle text-info",
        color: "#5cd65c",
        i18n_title: "alerts_dashboard.notice",
        syslog_severity: 5,
        used_by_alerts: true,
        emoji: "\xE2\x84\xB9"
    },
    warning: {
        severity_id: 4,
        label: "bg-warning",
        icon: "fas fa-exclamation-triangle text-warning",
        color: "#ffc007",
        i18n_title: "alerts_dashboard.warning",
        syslog_severity: 4,
        used_by_alerts: true,
        emoji: "\xE2\x9A\xA0"
    },
    error: {
        severity_id: 5,
        label: "bg-danger",
        icon: "fas fa-exclamation-triangle text-danger",
        color: "#ff3231",
        i18n_title: "alerts_dashboard.error",
        syslog_severity: 3,
        used_by_alerts: true,
        emoji: "\xE2\x9D\x97"
    },
    critical: {
        severity_id: 6,
        label: "bg-danger",
        icon: "fas fa-exclamation-triangle text-danger",
        color: "#fb6962",
        i18n_title: "alerts_dashboard.critical",
        syslog_severity: 2,
        emoji: "\xE2\x9D\x97"
    },
    emergency: {
        severity_id: 8,
        label: "bg-danger text-danger",
        icon: "fas fa-bomb text-danger",
        color: "#fb6962",
        i18n_title: "alerts_dashboard.emergency",
        syslog_severity: 0,
        emoji: "\xF0\x9F\x9A\xA9"
    }
}

/* *********************************** */

const getSeverityIcon = function(severity_id) {
    for (const [_, value] of Object.entries(alert_severities)) {
        if(Number(severity_id) == Number(value.severity_id)) {
            return value.icon
        }
    }
}

/* *********************************** */

const alertSeverities = function () {
    return {
        getSeverityIcon
    };
}();

export default alertSeverities;
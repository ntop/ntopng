/*
  (C) 2013-23 - ntop.org
 */

/*
 * Here a list of functions used to retrieve URLs; in this way
 * only here needs to change the URL in case of changes 
 */

/* ***** IMPORTANT: http_prefix is not returned ***** */

/* Returns the URL of the exporters details */
const getExporterDetailsPageURL = (exporter_info, http_prefix) => {
    const exporter_ip = exporter_info.ip
    let probe_source_id = ''
    let exporter_source_id = ''
    let probe_ip = ''
    
    if (exporter_info.probe_source_id) {
        probe_source_id = exporter_info.probe_source_id
    }
    if (exporter_info.exporter_source_id) {
        exporter_source_id = exporter_info.exporter_source_id
    }
    if (exporter_info.probe_ip) {
        probe_ip = exporter_info.probe_ip
    }
    return `${http_prefix}/lua/pro/enterprise/exporter_interfaces.lua?ip=${exporter_ip}&exporter_source_id=${exporter_source_id}&probe_source_id=${probe_source_id}&probe_ip=${probe_ip}`
}

/* ******************************************************************** */

/* Returns the URL of the exporters details */
const getExporterTimeseriesPageURL = (exporter_info, http_prefix) => {
    return `${http_prefix}/lua/pro/enterprise/exporter_details.lua?ip=${exporter_info.ip}&ifid=${exporter_info.ifid}&probe_source_id=${exporter_info.probe_source_id}`
}

/* ******************************************************************** */

/* Returns the URL of the exporters details */
const getExporterInterfaceConfigPageURL = (exporter_ip, interface_id, ifid, http_prefix) => {
    return `${http_prefix}/lua/pro/exporter_interface_overview.lua?deviceIP=${exporter_ip}&ifIdx=${interface_id}&ifid=${ifid}&page=config`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getExporterInterfaceDetailsPageURL = (exporter_ip, interface_id, ifid, http_prefix) => {
    return `${http_prefix}/lua/pro/exporter_interface_overview.lua?deviceIP=${exporter_ip}&ifIdx=${interface_id}&ifid=${ifid}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getSNMPDetailsPageURL = (device_ip, http_prefix) => {
    return `${http_prefix}/lua/pro/enterprise/snmp_device_details.lua?host=${device_ip}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getSNMPInterfaceDetailsPageURL = (device_ip, interface_id, http_prefix) => {
    return `${http_prefix}/lua/pro/enterprise/snmp_interface_details.lua?&host=${device_ip}&snmp_port_idx=${interface_id}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getAggregatedFlowsURL = (filters, aggregation_criteria, http_prefix) => {
    let filters_string = ''
    for (const filter in filters) {
        filters_string = `${filters_string}${filter}=${filters[filter]}&`
    }
    return `${http_prefix}/lua/flows_stats.lua?page=analysis&aggregation_criteria=${aggregation_criteria}&${filters_string}`
}

/* ******************************************************************** */

/* Returns the URL of the exporter details */
const getFlowExporterInterfaceOverviewPageURL = (device_ip, interface_id, http_prefix) => {
    return `${http_prefix}/lua/pro/exporter_interface_overview.lua?deviceIP=${device_ip}&ifIdx=${interface_id}`
}

/* ******************************************************************** */

const linksUtils = function () {
    return {
        getExporterDetailsPageURL,
        getExporterInterfaceDetailsPageURL,
        getSNMPDetailsPageURL,
        getSNMPInterfaceDetailsPageURL,
        getAggregatedFlowsURL,
        getFlowExporterInterfaceOverviewPageURL,
        getExporterTimeseriesPageURL,
        getExporterInterfaceConfigPageURL
    };
}();

export default linksUtils;


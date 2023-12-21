import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import NtopUtils from "../utilities/ntop-utils.js";

const available_interfaces = async (host) => {
    const params = {
        host: host
    };
    const url_params = ntopng_url_manager.obj_to_url_params(params);
    const snmp_device_port_url = `${http_prefix}/lua/pro/rest/v2/get/snmp/device/available_interfaces.lua?${url_params}`;
    const interfaces_list = await ntopng_utility.http_request(snmp_device_port_url);
    return interfaces_list;
};

const snmp_device_ports = async (host) => {
    let interfaces = await available_interfaces(host);
    let result_interfaces = interfaces.map((iface) => {
        if(iface.name != null && iface.name != "" && iface.name != iface.id) {
            return { label: `${iface.name} (${iface.id})`, id: iface.id, name: iface.name };
        }
        return { label: iface.id, id: iface.id,  name: iface.id };
    });

    return result_interfaces.sort(NtopUtils.sortAlphabetically)
};

const proxy_snmp = function () {
    return {
        available_interfaces,
        snmp_device_ports,
    };
}();

export default proxy_snmp;

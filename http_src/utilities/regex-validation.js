/*
 * (C) 2013-23 - ntop.org
 */

/* ****************************************************** */

const regexes = {
    ipv4: String.raw`^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$`,
    ipv6: String.raw`^(?:(?:[a-fA-F\d]{1,4}:){7}(?:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){6}(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){5}(?::(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,2}|:)|(?:[a-fA-F\d]{1,4}:){4}(?:(?::[a-fA-F\d]{1,4}){0,1}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,3}|:)|(?:[a-fA-F\d]{1,4}:){3}(?:(?::[a-fA-F\d]{1,4}){0,2}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,4}|:)|(?:[a-fA-F\d]{1,4}:){2}(?:(?::[a-fA-F\d]{1,4}){0,3}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,5}|:)|(?:[a-fA-F\d]{1,4}:){1}(?:(?::[a-fA-F\d]{1,4}){0,4}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,6}|:)|(?::(?:(?::[a-fA-F\d]{1,4}){0,5}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,7}|:)))(?:%[0-9a-zA-Z]{1,})?$`,
    mac_address: String.raw`^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$`,
    comma_separted_port_regex: String.raw`^(\d{1,5})(,\s*\d{1,5})*$`,
    port_range_regex: String.raw`^(\d{1,5})-(\d{1,5})$`,
	host_name: String.raw`^(?!\s*$)[a-zA-Z0-9._: \-\/]{1,250}|^[a-zA-Z0-9._: \-\/]{1,250}@[0-9]{0,5}`,
}

/* ****************************************************** */

const validateIP = (ip) => {
    return (validateIPv4(ip) || validateIPv6(ip));
}

/* ****************************************************** */

const validateIPv4 = (ip) => {
    const ipv4 = new RegExp(regexes.ipv4);

    return ipv4.test(ip);
}

/* ****************************************************** */

const validateIPv6 = (ip) => {
    const ipv6 = new RegExp(regexes.ipv6);

    return ipv6.test(ip);
}

const validateHostName = (host_name) => {
	const host_name_regexp = new RegExp(regexes.host_name);

	return host_name_regexp.test(host_name);
}

/* ****************************************************** */

const validateCommaSeparatedPortList = (ports) => {
    const port_list = new RegExp(regexes.comma_separted_port_regex);

    return port_list.test(ports);
}

/* ****************************************************** */

const validatePortRange = (ports) => {
    const port_array = ports.split("-", 2);
    const low = Number(port_array[0]);
    const high = Number(port_array[1]);

    if ((isNaN(low)) || (isNaN(high)))
        return false;

    if ((low > 0) && (low < high) && (high < 65536))
        return true;
    else
        return false;
}

/* ****************************************************** */

import NtopUtils from "./ntop-utils.js";

const Utils = NtopUtils;
function get_data_pattern(type) {
    if (type == "text") {
        return `.*`;
    } else if (type == "vlan") {
        let vlan = String.raw`@(([1-9])|([1-9][0-9]{1,2})|([1-3][0-9]{3})|(40[0-8][0-9])|(409[0-5]))`;
        return vlan;
    } else if (type == "ip" || type == "cidr") {
        let vlan = get_data_pattern("vlan");
        let r_ipv4 = Utils.REGEXES.ipv4;
        let r_ipv4_vlan = r_ipv4.replaceAll("$", `${vlan}$`);
        let r_ipv6 = Utils.REGEXES.ipv6;
        let r_ipv6_vlan = r_ipv6.replaceAll("$", `${vlan}$`);
        if (type == "cidr") {
            let network_ipv4 = String.raw`(\/(([1-9])|([1-2][0-9])|(3[0-2])))`;
            let ipv4_cidr = r_ipv4.replaceAll("$", `${network_ipv4}$`);
            let ipv4_cidr_vlan = r_ipv4.replaceAll("$", `${network_ipv4}${vlan}$`);
            let network_ipv6 = String.raw`(\/(([1-9])|([1-9][0-9])|(1[0-1][0-9])|(12[0-8])))`;
            let ipv6_cidr = r_ipv6.replaceAll("$", `${network_ipv6}$`);
            let ipv6_cidr_vlan = r_ipv6.replaceAll("$", `${network_ipv6}${vlan}$`);
            return `(${ipv4_cidr}|${ipv4_cidr_vlan}|${ipv6_cidr}|${ipv6_cidr_vlan})`;
        }
        return `(${r_ipv4})|(${r_ipv4_vlan})|(${r_ipv6})|(${r_ipv6_vlan})`;
    } else if (type == "mac") {
        return Utils.REGEXES["macAddress"];
    } else if (type == "ip,cidr") {
        let ip = get_data_pattern("ip");
        let cidr = get_data_pattern("cidr");
        return `(${ip})|(${cidr})`;
    }
    return Utils.REGEXES[type];
}

const regexValidation = function () {
    return {
        get_data_pattern,
        validateIP,
        validateIPv4,
        validateIPv6,
		validateHostName,
        validateCommaSeparatedPortList,
        validatePortRange,
    };
}();

export default regexValidation;

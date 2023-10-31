/*
 * (C) 2013-23 - ntop.org
 */

/* ****************************************************** */

const regexes = {
	ipv4: /^(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}$/gm,
	ipv6: /^(?:(?:[a-fA-F\d]{1,4}:){7}(?:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){6}(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|:[a-fA-F\d]{1,4}|:)|(?:[a-fA-F\d]{1,4}:){5}(?::(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,2}|:)|(?:[a-fA-F\d]{1,4}:){4}(?:(?::[a-fA-F\d]{1,4}){0,1}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,3}|:)|(?:[a-fA-F\d]{1,4}:){3}(?:(?::[a-fA-F\d]{1,4}){0,2}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,4}|:)|(?:[a-fA-F\d]{1,4}:){2}(?:(?::[a-fA-F\d]{1,4}){0,3}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,5}|:)|(?:[a-fA-F\d]{1,4}:){1}(?:(?::[a-fA-F\d]{1,4}){0,4}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,6}|:)|(?::(?:(?::[a-fA-F\d]{1,4}){0,5}:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)(?:\\.(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]\d|\d)){3}|(?::[a-fA-F\d]{1,4}){1,7}|:)))(?:%[0-9a-zA-Z]{1,})?$/gm,
	mac_address: String.raw`^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$`,
	comma_separted_port_regex: /^(\d{1,5})(,\s*\d{1,5})*$/,
}

/* ****************************************************** */

const validateIP = (ip) => {
	const ipv4 = regexes.ipv4;
	const ipv6 = regexes.ipv6;

	return (ipv4.test(ip) || ipv6.test(ip));
}

/* ****************************************************** */

const validateIPv4 = (ip) => {
	const ipv4 = regexes.ipv4;

	return ipv4.test(ip);
}

/* ****************************************************** */

const validateIPv6 = (ip) => {
	const ipv6 = regexes.ipv6;

	return ipv6.test(ip);
}

/* ****************************************************** */

const validateCommaSeparatedPortList = (ports) => {
	const port_list = regexes.comma_separted_port_regex;

	return port_list.test(ports);
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

const regexValidation = function() {
    return {
			get_data_pattern,
			validateIP,
			validateIPv4,
			validateIPv6,
			validateCommaSeparatedPortList,
    };
}();

export default regexValidation;

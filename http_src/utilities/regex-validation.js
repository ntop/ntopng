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
	let r_ipv4_vlan = r_ipv4.replace("$", `${vlan}$`);
	let r_ipv6 = Utils.REGEXES.ipv6;
	let r_ipv6_vlan = r_ipv6.replaceAll("$", `${vlan}$`);
	if (type == "cidr") {
	    let network_ipv4 = String.raw`(\/(([1-9])|([1-2][0-9])|(3[0-2])))`;
	    let ipv4_cidr = r_ipv4.replace("$", `${network_ipv4}$`);
	    let ipv4_cidr_vlan = r_ipv4.replace("$", `${network_ipv4}${vlan}$`);
	    let network_ipv6 = String.raw`(\/(([1-9])|([1-9][0-9])|(1[0-1][0-9])|(12[0-8])))`;
	    let ipv6_cidr = r_ipv6.replaceAll("$", `${network_ipv6}$`);
	    let ipv6_cidr_vlan = r_ipv6.replaceAll("$", `${network_ipv6}${vlan}$`);
	    return `(${ipv4_cidr}|${ipv4_cidr_vlan}|${ipv6_cidr}|${ipv6_cidr_vlan})`;
	}
	
	return `(${r_ipv4})|(${r_ipv4_vlan})|(${r_ipv6})|(${r_ipv6_vlan})`;
    } else if (type == "mac") {
	return Utils.REGEXES["macAddress"];
    }
    return Utils.REGEXES[type];
}

const regexValidation = function() {
    return {
	get_data_pattern,
    };
}();

export default regexValidation;

import NtopUtils from "./ntop-utils.js";

const Utils = NtopUtils;
function get_data_pattern(type) {
    if (type == "text") {
	return `.*`;
    } else if (type == "ip") {
	let r_ipv4 = Utils.REGEXES.ipv4;
	let r_ipv4_vlan = r_ipv4.replace("$", "@[0-9]{0,5}$");
	let r_ipv6 = Utils.REGEXES.ipv6;
	let r_ipv6_vlan = r_ipv6.replaceAll("$", "@[0-9]{0,5}$");
	return `(${r_ipv4})|(${r_ipv4_vlan})|(${r_ipv6})|(${r_ipv6_vlan})`;
    }
    return Utils.REGEXES[type];
}

const regexValidation = function() {
    return {
	get_data_pattern,
    };
}();

export default regexValidation;

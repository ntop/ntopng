// 2014-20 - ntop.org
Date.prototype.format = function (format) { //author: meizz
        var o = {
                "M+": this.getMonth() + 1, //month
                "d+": this.getDate(),    //day
                "h+": this.getHours(),   //hour
                "m+": this.getMinutes(), //minute
                "s+": this.getSeconds(), //second
                "q+": Math.floor((this.getMonth() + 3) / 3),  //quarter
                "S": this.getMilliseconds() //millisecond
        }

        if (/(y+)/.test(format)) format = format.replace(RegExp.$1,
                (this.getFullYear() + "").substr(4 - RegExp.$1.length));
        for (var k in o) if (new RegExp("(" + k + ")").test(format))
                format = format.replace(RegExp.$1,
                        RegExp.$1.length == 1 ? o[k] :
                                ("00" + o[k]).substr(("" + o[k]).length));
        return format;
}

// Extended disable function 
jQuery.fn.extend({
        disable: function (state) {
                return this.each(function () {
                        var $this = $(this);
                        if ($this.is('input, button, textarea, select'))
                                this.disabled = state;
                        else
                                $this.toggleClass('disabled', state);
                });
        }
});

const NTOPNG_MIN_VISUAL_VALUE = 0.005;

const REGEXES = {
        ipv4: String.raw`^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$`,
        ipv6: String.raw`^((([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]):){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$|^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*)$`,
        domainName: String.raw`^([a-zA-Z]([a-zA-Z]|[0-9])?\.[a-zA-Z]{2,13}|[a-zA-Z0-9]([\-_.a-zA-Z0-9]{1,61}[a-zA-Z0-9])?\.[a-zA-Z]{2,13}|[a-zA-Z0-9]([\-_.a-zA-Z0-9]{1,61}[a-zA-Z0-9])?\.[a-zA-Z]{2,30}\.[a-zA-Z]{2,3})$`,
        port: String.raw`^([0-9]{1,4}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$`,
        latency: String.raw`^([0-9]*[.])?[0-9]+$`,
        url: String.raw`^(https?\:\/\/[^\/\s]+(\/.*)?)$`,
        emailUrl: String.raw`^smtps?:\/\/[\-a-zA-Z0-9:.]{1,256}$`,
        macAddress: String.raw`^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$`,
        hostname: String.raw`^(?!\s*$)[a-zA-Z0-9._: \-\/]{1,250}|^[a-zA-Z0-9._: \-\/]{1,250}@[0-9]{0,5}`,
        username: String.raw`^[a-zA-Z0-9._@!-?]{3,30}$`,
        singleword: String.raw`^(?=[a-zA-Z0-9._:\-]{3,253}$)(?!.*[_.:\-]{2})[^_.:\-].*[^_.:\-]$`,
        multiword: String.raw`^([a-zA-Z0-9._:\-\s]{3,253})$`,
        email: String.raw`^([a-zA-Z0-9.!#$%&'*+\-\/=?^_\`\|~]+@[a-zA-Z0-9\-]+(?:\.[a-zA-Z0-9\-]+)*)$|^[a-zA-Z\d.!#$%&'*+\-\/=?^_\`\|~]{1,128}$`,
        emailCommaList: String.raw`^((?:[a-zA-Z0-9.!#$%&'*+\-\/=?^_\`\|~]+@[a-zA-Z0-9\-]+(?:\.[a-zA-Z0-9\-]+)*)|([a-zA-Z\d.!#$%&'*+\-\/=?^_\`\|~]{1,128}))(?:,((?:[a-zA-Z0-9.!#$%&'*+\-\/=?^_\`\|~]+@[a-zA-Z0-9\-]+(?:\.[a-zA-Z0-9\-]+)*)|([a-zA-Z\d.!#$%&'*+\-\/=?^_\`\|~]{1,128})))*$`,
        https: String.raw`^https?:\/\/.+$`,
        token: String.raw`^[0-9a-f]{32}`,
        score: String.raw`^[0-9]{1,5}`,
        telegram_channel: String.raw`^[0-9\-]{1,15}`,
        password: String.raw`^[\w\/$!\/()=?^*@_-]{5,31}$`,
        tls_certificate: String.raw`^[^=,]+=[^=,]+(,\s[^=,]+=[^=,]+)*$`,
        domain_name_not_strict: String.raw`^[a-zA-Z0-9\-_~]+((\.[a-zA-Z0-9\-_~]+)+)$`,
        non_quoted_text: String.raw`^[a-zA-Z0-9.-_]+$`,
};

export default class NtopUtils {

        /* Show an overlay to hide loading */
        static toggleOverlays(time = 500) {
                $(`.overlay`).toggle(time);
        }

        static showOverlays(time = 500) {
                $(`.overlay`).fadeIn(time);
        }

        static hideOverlays(time = 500) {
                $(`.overlay`).fadeOut(time);
        }

        static get REGEXES() {
                return REGEXES;
        }

        static getIPv4RegexWithCIDR() {
                const length = REGEXES.ipv4.length;
                return `${REGEXES.ipv4.substring(0, length - 1)}(\\/?)(\\b([0-9]|[12][0-9]|3[0-2])?\\b)$`;
        }

        static getIPv6RegexWithCIDR() {
                const length = REGEXES.ipv6.length;
                return `${REGEXES.ipv6.substring(0, length - 1)}(\\/?)\\b([0-9]|[1-9][0-9]|1[01][0-9]|12[0-8])?\\b$`;
        }

        /**
         * Resolve a hostname by doing a DNS Resolve.
         * @param {string} hostname The hostname to resolve
         */
        static async resolveDNS(hostname = "ntop.org") {

                // resolve the hostname by doing a fetch request to the backend
                try {
                        const request = await fetch(`${http_prefix}/lua/rest/v2/get/dns/resolve.lua?hostname=${hostname}`);
                        const response = await request.json();
                        return response;
                }
                catch (err) {
                        // prints out the error if the request fails
                        console.error(`Something went wrong when resolving hostname: ${err}`)
                }

                // if the request has failed return a placeholder response
                // indicating the failure
                return { rc: -1, rc_str: "FAILED_HTTP_REQUEST" };
        }

        /**
         * Replace the inputs which contain the [data-pattern] attribute
         * with the [pattern] attribute.
         */
        static initDataPatterns() {
                // for each input with the data-pattern attribute
                // substitute the data-pattern with the right regexes
                $(`input[data-pattern]`).each(function () {

                        // if the pattern is empty then print a warn inside the console
                        const dataPattern = $(this).data('pattern');
                        if (!dataPattern) {
                                console.warn(`An empty data-pattern on an input was found!`, this);
                                return;
                        }

                        // build the regexp pattern for the input
                        const pattern = dataPattern.split('|').map(p => REGEXES[p].toString()).join('|');
                        // load the pattern
                        $(this).attr('pattern', pattern);
                        // remove the data-pattern from the input
                        $(this).removeAttr('data-pattern');
                });
        }

        static is_good_ipv4(ipv4) {
                return new RegExp(REGEXES.ipv4).test(ipv4);
        }

        static is_good_ipv6(ipv6) {
                return new RegExp(REGEXES.ipv6).test(ipv6);
        }

        static is_mac_address(mac) {
                return new RegExp(REGEXES.macAddress).test(mac);
        }

        static isNumeric(value) {
                return /^\d+$/.test(value);
        }

        static is_network_mask(what, optional_mask) {
                var elems = what.split("/");
                var mask = null;
                var ip_addr;

                if (elems.length != 2) {
                        if (!optional_mask)
                                return null;
                        else
                                ip_addr = what;
                } else {
                        ip_addr = elems[0];

                        if (!NtopUtils.isNumeric(elems[1]))
                                return null;

                        mask = parseInt(elems[1]);

                        if (mask < 0)
                                return null;
                }

                if (NtopUtils.is_good_ipv4(ip_addr)) {
                        if (mask === null)
                                mask = 32;
                        else if (mask > 32)
                                return null;

                        return {
                                type: "ipv4",
                                address: ip_addr,
                                mask: mask
                        };
                } else if (NtopUtils.is_good_ipv6(elems[0])) {
                        if (mask === null)
                                mask = 128;
                        else if (mask > 128)
                                return (false);

                        return {
                                type: "ipv6",
                                address: ip_addr,
                                mask: mask
                        };
                }

                return null;
        }

        static fbits(bits) {
                const sizes = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];

                if (typeof (bits) === "undefined")
                        return "-";

                if (bits == 0) return '0';
                if ((bits > 0) && (bits < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + ' bps');
                var bits_log1000 = Math.log(bits) / Math.log(1000)
                var i = parseInt(Math.floor(bits_log1000));
                if (i < 0 || isNaN(i)) {
                        i = 0;
                } else if (i >= sizes.length) { // prevents overflows
                        return "> " + sizes[sizes.length - 1]
                }

                if (i <= 1) {
                        return Math.round(bits / Math.pow(1000, i) * 100) / 100 + ' ' + sizes[i]
                }
                else {
                        var ret = parseFloat(bits / Math.pow(1000, i)).toFixed(2)
                        if (ret % 1 == 0)
                                ret = Math.round(ret)
                        return ret + ' ' + sizes[i]
                }
        }

        static export_rate(eps) {
                if (typeof (eps) === "undefined")
                        return "-";

                var sizes = ['exp/s', 'Kexp/s'];
                if (eps == 0) return '0';
                if ((eps > 0) && (eps < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + ' exps/s');
                var res = NtopUtils.scaleValue(eps, sizes, 1000);

                // Round to two decimal digits
                return Math.round(res[0] * 100) / 100 + ' ' + res[1];
        }

        static exports_format(exports) {
                if (typeof (exports) === "undefined")
                        return "-";

                var exports_label = i18n_ext.exports.toLowerCase();

                var sizes = [exports_label, 'K ' + exports_label];
                if (exports == 0) return '0';
                if ((exports > 0) && (exports < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + ' exps/s');
                var res = NtopUtils.scaleValue(exports, sizes, 1000);

                // Round to two decimal digits
                return Math.round(res[0] * 100) / 100 + ' ' + res[1];
        }

        static fbits_from_bytes(bytes) {
                if (typeof (bytes) === "undefined")
                        return "-";
                return (NtopUtils.fbits(bytes * 8));
        }

        static fpackets(pps) {
                if (typeof (pps) === "undefined")
                        return "-";

                var sizes = ['pps', 'Kpps', 'Mpps', 'Gpps', 'Tpps'];
                if (pps == 0) return '0';
                if ((pps > 0) && (pps < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + ' pps');
                var res = NtopUtils.scaleValue(pps, sizes, 1000);

                // Round to two decimal digits
                return Math.round(res[0] * 100) / 100 + ' ' + res[1];
        }

        static fpoints(pps) {
                if (typeof (pps) === "undefined")
                        return "-";

                var sizes = ['pt/s', 'Kpt/s', 'Mpt/s', 'Gpt/s', 'Tpt/s'];
                if (pps == 0) return '0';
                if ((pps > 0) && (pps < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + ' pt/s');
                var res = NtopUtils.scaleValue(pps, sizes, 1000);

                // Round to two decimal digits
                return Math.round(res[0] * 100) / 100 + ' ' + res[1];
        }

        static fflows(fps) {
                if (typeof (fps) === "undefined")
                        return "-";

                var sizes = ['fps', 'Kfps', 'Mfps', 'Gfps', 'Tfps'];
                if (fps == 0) return '0';
                if ((fps > 0) && (fps < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + ' fps');
                var res = NtopUtils.scaleValue(fps, sizes, 1000);

                // Round to two decimal digits
                return Math.round(res[0] * 100) / 100 + ' ' + res[1];
        }

        static fmsgs(mps) {
                if (typeof (mps) === "undefined")
                        return "-";

                var sizes = ['msg/s', 'Kmsg/s', 'Msg/s', 'Gmsg/s', 'Tmsg/s'];
                if (mps == 0) return '0';
                if ((mps > 0) && (mps < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + ' mps');
                var res = NtopUtils.scaleValue(mps, sizes, 1000);

                // Round to two decimal digits
                return Math.round(res[0] * 100) / 100 + ' ' + res[1];
        }

        static fmillis(ms) {

                if (ms === undefined) return '-';
                const sizes = ['ms'];
                const res = NtopUtils.scaleValue(ms, sizes, 1000);
                return Math.round(res[0] * 100) / 100 + ' ' + res[1];
        }

        static fnone(val) {

                if (val === undefined) return '-';
                return Math.round(val * 100) / 100;
        }

        static falerts(aps) {
                if (typeof (aps) === "undefined")
                        return "-";

                // Round to two decimal digits
                return Math.round(aps * 100) / 100 + ' alerts/s';
        }

        static fint(value) {
                if (typeof (value) === "undefined")
                        return "-";

                var x = Math.round(value);
                return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        }

        static ffloat(value) {
                if (typeof (value) === "undefined")
                        return "-";

                var x = Math.round(value * 100) / 100.;
                return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
        }

        static fpercent(value) {
                if (typeof (value) === "undefined")
                        return "-";

                return Math.round(value * 100) / 100 + " %";
        }

        static percentage(value, total) {
                if (total > 0) {
                        var pctg = Math.round((value * 10000) / total)

                        if (pctg > 0) {
                                /* Two decimals */
                                return (" [ " + (pctg / 100) + " % ] ")
                        }
                }

                return ("")
        }

        static fdate(when) {
                var epoch = when * 1000;
                var d = new Date(epoch);

                return (d);
        }

        static capitaliseFirstLetter(string) {
                return string.charAt(0).toUpperCase() + string.slice(1);
        }

        static get_trend(actual, before) {
                if ((actual === undefined) || (before === undefined) || (actual == before)) {
                        return ("<i class=\"fas fa-minus\"></i>");
                } else if (actual > before) {
                        return ("<i class=\"fas fa-arrow-up\"></i>");
                } else {
                        return ("<i class=\"fas fa-arrow-down\"></i>");
                }
        }

        static abbreviateString(str, len) {
                if (!str)
                        return "";
                if (str.length < len)
                        return str;
                return str.substring(0, len) + "...";
        }

        static toFixed2(num) {
                if (!num) return "";
                return num.toFixed(2);
        }

        // Convert bytes to human readable format
        static bytesToSize(bytes) {
                if (typeof (bytes) === "undefined")
                        return "-";

                var precision = 2;
                var kilobyte = 1024;
                var megabyte = kilobyte * 1024;
                var gigabyte = megabyte * 1024;
                var terabyte = gigabyte * 1024;

                if ((bytes >= 0) && (bytes < kilobyte))
                        if (bytes != 0)
                                return parseFloat(bytes.toFixed(precision)) + " Bytes";
                        else
                                return parseFloat(bytes) + " Bytes";

                else if ((bytes >= kilobyte) && (bytes < megabyte))
                        return parseFloat((bytes / kilobyte).toFixed(precision)) + ' KB';
                else if ((bytes >= megabyte) && (bytes < gigabyte))
                        return parseFloat((bytes / megabyte).toFixed(precision)) + ' MB';
                else if ((bytes >= gigabyte) && (bytes < terabyte))
                        return parseFloat((bytes / gigabyte).toFixed(precision)) + ' GB';
                else if (bytes >= terabyte)
                        return parseFloat((bytes / terabyte).toFixed(precision)) + ' TB';
                else
                        return parseFloat(bytes.toFixed(precision)) + ' Bytes';
        }

        static drawTrend(current, last, withColor) {
                if (current == last) {
                        return ("<i class=\"fas fa-minus\"></i>");
                } else if (current > last) {
                        return ("<i class=\"fas fa-arrow-up\"" + withColor + "></i>");
                } else {
                        return ("<i class=\"fas fa-arrow-down\"></i>");
                }
        }

        static toggleAllTabs(enabled) {
                if (enabled === true)
                        $("#historical-tabs-container").find("li").removeClass("disabled").find("a").attr("data-toggle", "tab");
                else
                        $("#historical-tabs-container").find("li").addClass("disabled").find("a").removeAttr("data-toggle");
        }

        static disableAllDropdownsAndTabs() {
                $("select").each(function () {
                        $(this).prop("disabled", true);
                });
                NtopUtils.toggleAllTabs(false)
        }

        static enableAllDropdownsAndTabs() {
                $("select").each(function () {
                        $(this).prop("disabled", false);
                });
                NtopUtils.toggleAllTabs(true)
        }

        static capitalize(s) {
                return s && s[0].toUpperCase() + s.slice(1);
        }

        static addCommas(nStr) {
                nStr += '';
                var x = nStr.split('.');
                var x1 = x[0];
                var x2 = x.length > 1 ? '.' + x[1] : '';
                var rgx = /(\d+)(\d{3})/;
                while (rgx.test(x1)) {
                        x1 = x1.replace(rgx, '$1' + ',' + '$2');
                }
                return x1 + x2;
        }

        static scaleValue(val, sizes, scale, decimals) {
                if (val == 0) return [0, sizes[0]];
                let factor = decimals ? (10 * decimals) : 10;

                var i = parseInt(Math.floor(Math.log(val) / Math.log(scale)));
                if (i < 0 || isNaN(i)) {
                        i = 0;
                } else if (i >= sizes.length) {
                        i = sizes.length - 1;
                }

                return [Math.round((val / Math.pow(scale, i)) * factor) / factor, sizes[i]];
        }

        static formatValue(val, decimals) {
                var sizes = ['', 'K', 'M', 'G', 'T'];
                if (val == 0) return '0';
                if ((val > 0) && (val < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE);
                if (decimals == undefined) decimals = 0;
                var res = NtopUtils.scaleValue(val, sizes, 1000, decimals);

                return res[0] + res[1];
        }

        static formatPackets(n) {
                return (NtopUtils.addCommas(n.toFixed(0)) + " Pkts");
        }

        static bytesToVolume(bytes) {
                var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
                if (bytes == 0) return '0 Bytes';
                if ((bytes > 0) && (bytes < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + " Bytes");
                var res = NtopUtils.scaleValue(bytes, sizes, 1024);

                return parseFloat(res[0]) + " " + res[1];
        };

        static bytesToVolumeAndLabel(bytes) {
                var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
                if (bytes == 0) return '0 Bytes';
                var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
                return [(bytes / Math.pow(1024, i)).toFixed(2), sizes[i]];
        };

        static bitsToSize(bits, factor) {
                factor = factor || 1000;
                var sizes = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
                if (bits == 0) return '0 bps';
                if ((bits > 0) && (bits < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + " bps");
                var res = NtopUtils.scaleValue(bits, sizes, factor);

                return res[0].toFixed(2) + " " + res[1];
        };

        static bitsToSize_no_comma(bits, factor) {
                factor = factor || 1000;
                var sizes = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
                if (bits == 0) return '0 bps';
                if ((bits > 0) && (bits < NTOPNG_MIN_VISUAL_VALUE)) return ('< ' + NTOPNG_MIN_VISUAL_VALUE + " bps");
                var res = NtopUtils.scaleValue(bits, sizes, factor);

                return res[0] + " " + res[1];
        };

        static secondsToTime(seconds) {

                if (seconds < 1) {
                        return ("< 1 sec")
                }

                let days = Math.floor(seconds / 86400)
                let hours = Math.floor((seconds / 3600) - (days * 24))
                let minutes = Math.floor((seconds / 60) - (days * 1440) - (hours * 60))
                let sec = seconds % 60
                let msg = "", msg_array = []

                if (days > 0) {
                        let years = Math.floor(days / 365)

                        if (years > 0) {
                                days = days % 365

                                msg = years + " year"
                                if (years > 1) {
                                        msg += "s"
                                }

                                msg_array.push(msg)
                                msg = ""
                        }
                        msg = days + " day"
                        if (days > 1) { msg += "s" }
                        msg_array.push(msg)
                        msg = ""
                }

                if (hours > 0) {
                        if (hours < 10) { msg = "0" }
                        msg += hours + ":";
                }

                if (minutes < 10) { msg += "0" }
                msg += minutes + ":";
                if (sec < 10) { msg += "0" }
                msg += sec;
                msg_array.push(msg)

                return msg_array.join(", ")
        }

        static msecToTime(msec) {
                if (msec >= 1000) {
                        return NtopUtils.secondsToTime(msec / 1000);
                } else {
                        var x = Math.round(msec * 1000) / 1000.;
                        return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",") + " ms";
                }
        }

        static epoch2Seen(epoch) {
                /* 08/01/13 15:12:37 [18 min, 13 sec ago] */
                var d = new Date(epoch * 1000);
                var tdiff = Math.floor(((new Date()).getTime() / 1000) - epoch);

                return (d.format("dd/MM/yyyy hh:mm:ss") + " [" + NtopUtils.secondsToTime(tdiff) + " ago]");
        }

        /* ticks for graph x axis */
        static graphGetXAxisTicksFormat(diff_epoch) {
                var tickFormat;

                if (diff_epoch <= 86400) {
                        tickFormat = "%H:%M:%S";
                } else if (diff_epoch <= 2 * 86400) {
                        tickFormat = "%b %e, %H:%M:%S";
                } else {
                        tickFormat = "%b %e";
                }

                return (tickFormat);
        }

        static paramsExtend(defaults, override) {
                return $.extend({}, defaults, override);
        }

        static paramsToForm(form, params) {
                form = $(form);

                for (var k in params) {
                        if (params.hasOwnProperty(k)) {
                                var input = $('<input type="hidden" name="' + k + '" value="' + params[k] + '">');
                                input.appendTo(form);
                        }
                }

                return form;
        }

        /*
         * This function creates a javascript object where each k->v pair of the input object
         * translates into two pairs in the output object: a key_[i]->k and a val_[i]->v, where
         * i is an incremental index.
         *
         * The output object can then be serialized to an URL. This conversion is required for
         * handling special characters: since ntopng strips special characters in _GET keys,
         * _GET values must be used.
         *
         * This function performs the inverse conversion of lua paramsPairsDecode.
         *
         */
        static paramsPairsEncode(params) {
                var i = 0;
                var res = {};

                for (var k in params) {
                        res["key_" + i] = k;
                        res["val_" + i] = params[k];
                        i = i + 1;
                }

                return res;
        }

        static hostkey2hostInfo(host_key) {
                var info;

                host_key = host_key.replace(/____/g, ":");
                host_key = host_key.replace(/___/g, "/");
                host_key = host_key.replace(/__/g, ".");

                info = host_key.split("@");
                return (info);
        }

        static handle_tab_state(nav_object, default_tab) {
                $('a', nav_object).click(function (e) {
                        e.preventDefault();
                });

                // store the currently selected tab in the hash value
                $(" > li > a", nav_object).on("shown.bs.tab", function (e) {
                        var id = $(e.target).attr("href").substr(1);
                        if (history.replaceState) {
                                // this will prevent the 'jump' to the hash
                                history.replaceState(null, null, "#" + id);
                        } else {
                                // fallback
                                window.location.hash = id;
                        }
                });

                // on load of the page: switch to the currently selected tab
                var hash = window.location.hash;
                if (!hash) hash = "#" + default_tab;
                $('a[href="' + hash + '"]', nav_object).tab('show');
        }

        static _add_find_host_link(form, name, data) {
                $('<input>').attr({
                        type: 'hidden',
                        id: name,
                        name: name,
                        value: data,
                }).appendTo(form);
        }

        /* Used while searching hosts a and macs with typeahead */
        static makeFindHostBeforeSubmitCallback(http_prefix) {
                return function (form, data) {
                        if (data.context && data.context == "historical") {
                                form.attr("action", http_prefix + "/lua/pro/db_search.lua");
                                if (data.type == "ip") {
                                        NtopUtils._add_find_host_link(form, "ip", data.ip);
                                } else if (data.type == "mac") {
                                        NtopUtils._add_find_host_link(form, "mac", data.mac);
                                } else if (data.type == "community_id") {
                                        NtopUtils._add_find_host_link(form, "community_id", data.community_id);
                                } else if (data.type == "ja3_client") {
                                        NtopUtils._add_find_host_link(form, "ja3_client", data.ja3_client);
                                } else if (data.type == "ja3_server") {
                                        NtopUtils._add_find_host_link(form, "ja3_server", data.ja3_server);
                                } else /* "hostname" */ {
                                        NtopUtils._add_find_host_link(form, "name", data.hostname ? data.hostname : data.name);
                                }
                        } else {
                                if (data.type == "mac") {
                                        form.attr("action", http_prefix + "/lua/mac_details.lua");
                                } else if (data.type == "network") {
                                        form.attr("action", http_prefix + "/lua/hosts_stats.lua");
                                        NtopUtils._add_find_host_link(form, "network", data.network);
                                } else if (data.type == "snmp") {
                                        form.attr("action", http_prefix + "/lua/pro/enterprise/snmp_interface_details.lua");
                                        NtopUtils._add_find_host_link(form, "snmp_port_idx", data.snmp_port_idx);
                                } else if (data.type == "snmp_device") {
                                        form.attr("action", http_prefix + "/lua/pro/enterprise/snmp_device_details.lua");
                                } else if (data.type == "asn") {
                                        form.attr("action", http_prefix + "/lua/hosts_stats.lua");
                                        NtopUtils._add_find_host_link(form, "asn", data.asn);
                                } else {
                                        form.attr("action", http_prefix + "/lua/host_details.lua");
                                        NtopUtils._add_find_host_link(form, "mode", "restore");
                                }
                        }

                        return true;
                }
        }

        static tstampToDateString(html_tag, format, tdiff) {
                tdiff = tdiff || 0;
                var timestamp = parseInt(html_tag.html()) + tdiff;
                var localized = d3.time.format(format)(new Date(timestamp * 1000));
                html_tag.html(localized).removeClass("hidden");
                return localized;
        }

        static noHtml(s) {
                return s.replace(/<[^>]+>/g, '');
        }

        static cleanCustomHostUrl(host) {
                /* Remove starting http(s). */
                return host
                        .replace(/^http:\/\//gi, '')
                        .replace(/^https:\/\//gi, '')
                        /* Remove starting www. */
                        .replace(/^www\./gi, '')
                        /* Remove non-allowed characters */
                        .replace(/[^0-9a-zA-Z\.:\/_-]/gi, '');
        }

        /* https://stackoverflow.com/questions/2090551/parse-query-string-in-javascript */
        static parseQuery(queryString) {
                var query = {};
                var pairs = (queryString[0] === '?' ? queryString.substr(1) : queryString).split('&');
                for (var i = 0; i < pairs.length; i++) {
                        var pair = pairs[i].split('=');
                        query[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
                }
                return query;
        }

        static getHistoryParameters(params) {
                var cur_params = NtopUtils.parseQuery(window.location.search);
                var new_params = $.extend(cur_params, params);
                var new_query = "?" + $.param(new_params, true);
                var baseUrl = [location.protocol, '//', location.host, location.pathname].join('');

                return baseUrl + new_query;
        }

        // return true if the status code is different from 200
        static check_status_code(status_code, status_text, $error_label) {

                const is_different = status_code != 200;

                if (is_different && $error_label != null) {

                        let message = i18n_ext.request_failed_message;
                        if (status_code && status_text) {
                                message += `: ${status_code} - ${status_text}`;
                        }

                        $error_label.text(message).show();
                }
                else if (is_different && $error_label == null) {
                        alert(`${i18n_ext.request_failed_message}: ${status_code} - ${status_text}`);
                }

                return is_different;
        }

        // To be used in conjunction with httpdocs/templates/config_list_components/import_modal.html
        static importModalHelper(params) {

                if (!params.loadConfigXHR) { throw ("importModalHelper:: Missing 'loadConfigXHR' param"); }

                $(`input#import-input`).on('change', function () {
                        $(`#btn-confirm-import`).removeAttr("disabled");
                });

                $(`#import-modal`).on('hidden.bs.modal', function () {
                        $(`#import-input`).val('');
                        $("#import-error").hide().removeClass('text-warning').addClass('invalid-feedback');
                        $(`#btn-confirm-import`).attr("disabled", "disabled");
                });

                $("#import-modal").on("submit", "form", function (e) {

                        e.preventDefault();

                        const $button = $('#btn-confirm-import');
                        $button.attr("disabled", "");

                        // read configuration file
                        const file = $('#import-input')[0].files[0];

                        if (!file) {
                                $("#import-error").text(`${i18n_ext.no_file}`).show();
                                $button.removeAttr("disabled");
                                return;
                        }

                        const reader = new FileReader();
                        reader.readAsText(file, "UTF-8");

                        reader.onload = function () {
                                // Client-side configuration file format check
                                let jsonConfiguration = null
                                try { jsonConfiguration = JSON.parse(reader.result); } catch (e) { }

                                if (!jsonConfiguration) {
                                        $("#import-error").text(i18n_ext.rest_consts[responseJSON.rc_str] || 'Not Implemented Yet').show();
                                        $button.removeAttr("disabled");
                                        return;
                                }

                                // Submit configuration file
                                params.loadConfigXHR(reader.result)
                                        .done((response, status, xhr) => {

                                                if (response.rc < 0) {
                                                        $("#import-error").text(response.rc_str).show();
                                                        return;
                                                }

                                                // if the operation was successful call the successCallback
                                                if (params.successCallback) {
                                                        params.successCallback(response);
                                                }

                                                const key = $(`input[name='configuration']:checked`).val();

                                                const body = (key == 'all')
                                                        ? i18n("manage_configurations.messages.import_all_success")
                                                        : i18n("manage_configurations.messages.import_success");

                                                // show a success alert message
                                                ToastUtils.showToast({
                                                        id: 'import-configuration-alert',
                                                        level: 'success',
                                                        title: i18n("success"),
                                                        body: body,
                                                        delay: 2000
                                                });

                                                $("#import-modal").modal('hide');

                                        })
                                        .fail(({ responseJSON }) => {

                                                const PARTIAL_IMPORT_RC = -28;

                                                if (params.failureCallback) {
                                                        params.failureCallback(responseJSON);
                                                }

                                                if (responseJSON && responseJSON.rc > 0) return;
                                                if (responseJSON.rc == PARTIAL_IMPORT_RC)
                                                        $(`#import-error`).removeClass('invalid-feedback').addClass('text-warning');

                                                $("#import-error").text(i18n_ext.rest_consts[responseJSON.rc_str] || i18n_ext.FAILED_HTTP_REQUEST).show();

                                        })
                                        .always(() => {
                                                $button.removeAttr("disabled");
                                        });
                        };
                });
        }

        static serializeFormArray(serializedArray) {
                const serialized = {};
                serializedArray.forEach((obj) => {
                        /* if the object is an array  */
                        if (obj.name.includes('[]')) {
                                return;
                        }
                        else {

                                // clean the string
                                if (typeof obj.value === "string") {
                                        obj.value = obj.value.trim();
                                }
                                serialized[obj.name] = obj.value;
                        }
                });
                return serialized;
        }

        static cleanForm(formSelector) {
                /* remove validation fields and tracks */
                $(formSelector).find('input,select,textarea').each(function (i, input) {
                        $(this).removeClass(`is-valid`).removeClass(`is-invalid`);
                });
                /* reset all the values */
                $(formSelector)[0].reset();
        }

        /**
         * Make a fetch call with a timeout option
         */
        static fetchWithTimeout(uri, options = {}, time = 5000) {

                const controller = new AbortController()
                const config = { ...options, signal: controller.signal }

                return fetch(uri, config)
                        .then((response) => {
                                if (!response.ok) {
                                        throw new Error(`${response.status}: ${response.statusText}`)
                                }
                                return response
                        })
                        .catch((error) => {
                                if (error.name === 'AbortError') {
                                        throw new Error('Response timed out')
                                }
                        })
        }

        static setPref(action, csrf, success, failure) {

                if (action == undefined) {
                        console.warn("An action key must be defined to set a preference!");
                        return;
                }

                const empty = () => { };
                const request = $.post(`${http_prefix}/lua/update_prefs.lua`, { action: action, csrf: csrf });
                request.done(success || empty);
                request.fail(failure || empty);
        }

        /**
         * Glue strings contained in array separated by a comma.
         * @param {array} array The array of strings. I.e. ["Hello", "World"]
         * @param {number} limit How many words the string contains
         *
         * @return {string} A string built by array's elements. i.e: "Hello, World"
         */
        static arrayToListString(array, limit) {

                if (array == undefined) return "";

                if (array.length > limit) {
                        return array.slice(0, limit).join(", ") + ` ${i18n_ext.and_x_more.replace('$num', array.length - limit)}`;
                }

                return array.slice(0, limit).join(", ");
        }

        static buildURL(location, params = {}, hasReferer = false, refererParams = {}) {

                const url = new URL(location, window.location);

                for (const [name, value] of Object.entries(params)) {
                        if (value || value === 0)
                                url.searchParams.set(name, value);
                        continue;
                }

                if (hasReferer) {

                        const refUrl = new URL(window.location.href);
                        for (const [name, value] of Object.entries(refererParams)) {
                                if (!value) continue;
                                refUrl.searchParams.set(name, value);
                        }

                        url.searchParams.set('referer', refUrl.toString());
                }

                return url.toString();
        }

        static getEditPoolLink(href, poolId) {
                const url = new URL(href, window.location);
                url.searchParams.set('pool_id', poolId);
                return url.toString();
        }

        static getPoolLink(poolType, poolId = 0) {
                return `${http_prefix}/lua/rest/v2/get/${poolType}/pools.lua?pool=${poolId}`;
        }

        static async getPool(poolType, id = 0) {

                if (poolType === null) throw 'A pool type must be defined!';

                try {

                        const request = await fetch(NtopUtils.getPoolLink(poolType, id));
                        const pool = await request.json();

                        if (pool.rc < 0) {
                                return [false, {}];
                        }

                        return [true, pool.rsp[0]];
                }
                catch (err) {
                        return [false, {}];
                }
        }

        /**
         * Save the scale of element inside the local storage
         * @param {object} $element 
         * @param {object} scale
         */
        static saveElementScale($element, scale = { width: 0, height: 0 }) {

                const key = NtopUtils.generateScaleElementKey($element);
                localStorage.setItem(key, JSON.stringify(scale));
        }

        static generateScaleElementKey($element) {
                let identificator;
                const page = location.pathname;
                const elementId = $element.attr('id');

                if (elementId !== "") {
                        identificator = elementId;
                }
                else {
                        const className = $element.attr('class');
                        identificator = className;
                }

                const key = `${identificator}-${page}-scale`;
                return key;
        }

        /**
         * Load the old scale value ofx element from the local storage
         * @param {object} $element 
         */
        static loadElementScale($element) {

                const key = NtopUtils.generateScaleElementKey($element);
                const currentValue = localStorage.getItem(key);
                if (currentValue == null) return undefined;

                return JSON.parse(currentValue);
        }

        static fillFieldIfValid($field, value) {

                if (value === undefined) {
                        $field.val('');
                }
                else {
                        $field.val(value);
                }

        }

        static copyToClipboard(text, item) {
                const el = document.createElement('textarea');
                el.value = text;
                el.setAttribute('readonly', '');
                el.style.position = 'absolute';
                el.style.left = '-9999px';
                document.body.appendChild(el);
                el.select();
                document.execCommand('copy');
                document.body.removeChild(el);
                $(item).attr("title", "Copied!").tooltip("dispose").tooltip().tooltip("show");
                $(item).removeAttr("data-bs-original-title")
                $(item).attr("title", text)
        }

        static stripTags(html) {
                let t = document.createElement("div");
                t.innerHTML = html;
                return t.textContent || t.innerText || "";
        }

        static shortenLabel(label, len, last_char) {
                let shortened_label = label
                if (label.length > len + 5) {
                        if (last_char) {
                                let last_index = label.lastIndexOf(last_char)
                                const requested_label = label.slice(last_index)
                                if (len > last_index)
                                        len = last_index
                                shortened_label = label.slice(0, len) + "... " + requested_label
                        } else {
                                shortened_label = label.slice(0, len) + "...";
                        }
                }

                return shortened_label
        }

        static sortAlphabetically(a, b) {
                const nameA = a.label?.toUpperCase(); // ignore upper and lowercase
                const nameB = b.label?.toUpperCase(); // ignore upper and lowercase
                if (nameA < nameB) { return -1; }
                if (nameA > nameB) { return 1; }
                return 0;
        }

        /* This function, given a name and a value, return a string
         * formatted in the following way:
         * name [value]
              * If max_name_len is different from 0, then it's going to cut the name string
              * to max_name_len
         */
        static formatNameValue(name, value, max_name_len) {
                let label = name;
                if (name != value) {
                        if (max_name_len && typeof (max_name_len) == 'number')
                                label = this.shortenLabel(label, max_name_len, '.');

                        label = `${label} [${value}]`
                }
                return label
        }

        /* This function, remove from a string the VLAN 0
         * name@0 -> name
         */
        static removeVlan(name) {
                let label = name
                const vlan_index = label.lastIndexOf('@');
                if (vlan_index != -1) {
                        const vlan = label.slice(vlan_index + 1);
                        if (vlan == 0) {
                                label = label.slice(0, vlan_index);
                        }
                }

                return label
        }

        /* Format an object with label and value from a column row */
        static formatGenericObj(obj, row) {
                let label = obj.label ? obj.label : obj.value;
                let key = obj.value;
                return label;
        }

        /* Format a country from a column object */
        static formatCountry(obj, row) {
                let country_code = obj.value;
                let label = obj.label ? obj.label : obj.value;
                return `${label} <img src="/dist/images/blank.gif" class="flag flag-${country_code.toLowerCase()}">`;
        }

        /* Format an host from a column object */
        static formatHost(obj, row, is_client) {
                let label = "";

                if (!obj) {
                        return label;
                }

                /* Link */
                let host_key = obj.ip;
                if (row.vlan_id && row.vlan_id.value)
                        host_key = host_key + '@' + row.vlan_id.value;

                /* Label */
                label = obj.label ? obj.label : obj.value;
                if (row.vlan_id && row.vlan_id.label)
                        label += `@${row.vlan_id.label}`;

                const url = NtopUtils.buildURL(`${http_prefix}/lua/host_details.lua`, { host: host_key });
                label = `<a href="${url}">${label}</a>`;

                /* Country */
                let country_obj = is_client ? row.cli_country : row.srv_country;
                if (!country_obj && row.country) country_obj = row.country;
                if (country_obj && country_obj.value)
                        label += ` <img src="${http_prefix}/dist/images/blank.gif" class="flag flag-${country_obj.value.toLowerCase()}" title="${country_obj.title}"></a>`;

                return label;
        }

        /* Format a network from a column object */
        static formatNetwork(obj, row) {
                let label = "";

                if (!obj) {
                        return label;
                }

                /* Link */
                let network_key = obj.value;

                /* Label */
                label = obj.label ? obj.label : obj.value;
                if (row.vlan_id && row.vlan_id.label)
                        label += `@${row.vlan_id.label}`;

                const url = NtopUtils.buildURL(`${http_prefix}/lua/hosts_stats.lua`, { network: network_key });
                label = `<a href="${url}">${label}</a>`;

                return label;
        }

        /* This function converts a mac address to a string*/
        static convertMACAddress(a) {
                return a.toLowerCase().replace(/[^a-f0-9]/g, '');
        }
        /* This function converts an ip to a number equale to the ip but without . or :: in case of ipv6
         * this is needed in case of ordering
         */
        static convertIPAddress(a) {
                var i, item;
                var m, n, t;
                var x, xa;

                if (!a) {
                        return 0;
                }

                a = a.replace(/<[\s\S]*?>/g, "");
                //IPv4:Port
                t = a.split(":");
                if (t.length == 2) {
                        m = t[0].split(".");
                }
                else {
                        m = a.split(".");
                }
                n = a.split(":");
                x = "";
                xa = "";

                if (m.length == 4) {
                        // IPV4
                        for (i = 0; i < m.length; i++) {
                                item = m[i];

                                if (item.length == 1) {
                                        x += "00" + item;
                                }
                                else if (item.length == 2) {
                                        x += "0" + item;
                                }
                                else {
                                        x += item;
                                }
                        }
                }
                else if (n.length > 0) {
                        // IPV6
                        var count = 0;
                        for (i = 0; i < n.length; i++) {
                                item = n[i];

                                if (i > 0) {
                                        xa += ":";
                                }

                                if (item.length === 0) {
                                        count += 0;
                                }
                                else if (item.length == 1) {
                                        xa += "000" + item;
                                        count += 4;
                                }
                                else if (item.length == 2) {
                                        xa += "00" + item;
                                        count += 4;
                                }
                                else if (item.length == 3) {
                                        xa += "0" + item;
                                        count += 4;
                                }
                                else {
                                        xa += item;
                                        count += 4;
                                }
                        }

                        // Padding the ::
                        n = xa.split(":");
                        var paddDone = 0;

                        for (i = 0; i < n.length; i++) {
                                item = n[i];

                                if (item.length === 0 && paddDone === 0) {
                                        for (var padding = 0; padding < (32 - count); padding++) {
                                                x += "0";
                                                paddDone = 1;
                                        }
                                }
                                else {
                                        x += item;
                                }
                        }
                }

                return x;
        }

        /* Format an AS from a column object */
        static formatASN(obj, row) {
                let label = "";

                if (!obj) {
                        return label;
                }

                /* Link */
                let asn_key = obj.value;

                /* Label */
                label = obj.label ? obj.label : obj.value;

                const url = NtopUtils.buildURL(`${http_prefix}/lua/hosts_stats.lua`, { asn: asn_key });
                label = `<a href="${url}">${label}</a>`;

                return label;
        }

        static createProgressBar(percentage) {
                return `<div class="d-flex flex-row align-items-center">
              <div class="col-9 progress">
                <div class="progress-bar bg-warning" aria-valuenow="${percentage}" aria-valuemin="0" aria-valuemax="100" style="width: ${percentage}%;">
                </div>
              </div>
              <div class="col"> ${percentage} %</div>
            </div>`
        }

        static createBreakdown(percentage_1, percentage_2, label_1, label_2) {
                return `<div class="d-flex flex-row align-items-center">
              <div class="col-12 progress">
                <div class="progress-bar bg-warning" aria-valuenow="${percentage_1}" aria-valuemin="0" aria-valuemax="100" style="width: ${percentage_1}%;">${label_1}</div>
                <div class="progress-bar bg-success" aria-valuenow="${percentage_2}" aria-valuemin="0" aria-valuemax="100" style="width: ${percentage_2}%;">${label_2}</div>
              </div>
            </div>`
        }

        /* Return the number of rows available in a table */
        static getNumTableRows() {
                return [10, 20, 50, 100];
        }

        static formatApexChartLabelFromXandName({ series, seriesIndex, dataPointIndex, w }) {
                const serie = w.config.series[seriesIndex]["data"][dataPointIndex];
                const name = serie["name"]
                const y_value = serie["y"];
                const host_name = serie["meta"]["label"];

                const x_axis_title = w.config.xaxis.title.text;
                const y_axis_title = w.config.yaxis[0].title.text;

                return (`
    <div class='apexcharts-theme-light apexcharts-active' id='test'>
        <div class='apexcharts-tooltip-title' style='font-family: Helvetica, Arial, sans-serif; font-size: 12px;'>
            ${host_name}
        </div>
        <div class='apexcharts-tooltip-series-group apexcharts-active d-block'>
            <div class='apexcharts-tooltip-text text-left'>
                <b>${x_axis_title}</b>: ${name}
            </div>
            <div class='apexcharts-tooltip-text text-left'>
                <b>${y_axis_title}</b>: ${y_value}
            </div>
        </div>
    </div>
    `)
        }

        static apexChartJumpToAlerts(event, chartContext, config) {
                const { seriesIndex, dataPointIndex } = config;
                const { series } = config.config;
                if (seriesIndex === -1) return;
                if (series === undefined) return;

                const serie = series[seriesIndex];
                const base_url = serie.base_url || series[0]['base_url']
                const default_url = serie.start_url || series[0]['start_url']
                if (base_url != null && default_url != null) {
                        const search = serie.data[dataPointIndex].meta.url_query;
                        location.href = `${base_url}?${default_url}${search}`;
                }
        }


        static apexChartJumpToHostDetails(event, chartContext, config) {
                const { seriesIndex, dataPointIndex } = config;
                const { series } = config.config;
                if (seriesIndex === -1) return;
                if (series === undefined) return;

                const serie = series[seriesIndex];

                const base_url = serie.base_url || series[0]['base_url']

                if (base_url != null) {
                        const url = `${base_url}?${serie.data[dataPointIndex].meta.url_query}`;
                        ntopng_url_manager.go_to_url(url);
                }
        }


        static formatApexChartLabelFromXandY({ series, seriesIndex, dataPointIndex, w }) {
                const serie = w.config.series[seriesIndex]["data"][dataPointIndex];

                const x_value = serie["x"];
                const y_value = serie["y"];
                const host_name = serie["meta"]["label"];

                const x_axis_title = w.config.xaxis.title.text;
                const y_axis_title = w.config.yaxis[0].title.text;

                return (`
      <div class='apexcharts-theme-light apexcharts-active' id='test'>
          <div class='apexcharts-tooltip-title' style='font-family: Helvetica, Arial, sans-serif; font-size: 12px;'>
              ${host_name}
          </div>
          <div class='apexcharts-tooltip-series-group apexcharts-active d-block'>
              <div class='apexcharts-tooltip-text text-left'>
                  <b>${x_axis_title}</b>: ${x_value}
              </div>
              <div class='apexcharts-tooltip-text text-left'>
                  <b>${y_axis_title}</b>: ${y_value}
              </div>
          </div>
      </div>
    `)
        }
}

$(function () {
        // if there are inputs with 'pattern' data attribute
        // then initialize them
        NtopUtils.initDataPatterns();
});


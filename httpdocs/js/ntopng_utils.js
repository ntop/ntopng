// 2014-18 - ntop.org

function is_good_ipv4(ipv4) {
    if (/^(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$/.test(ipv4)) {
	return(true);
    } else {
	return(false);
    }
}

function is_good_ipv6(ipv6) {
    if (/^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\:){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$|^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$/.test(ipv6)) {
	return(true);
    } else {
	return(false);
    }
}

function isNumeric(value) {
    return /^\d+$/.test(value);
}

function is_mac_address(what) {
    return /^([0-9A-Fa-f]{2}:){5}([0-9A-Fa-f]{2})$/.test(what);
}

function is_network_mask(what, optional_mask) {
    var elems = what.split("/");
    var mask = null;
    var ip_addr;

    if(elems.length != 2) {
      if (! optional_mask)
         return null;
      else
         ip_addr = what;
   } else {
      ip_addr = elems[0];

      if(!isNumeric(elems[1]))
         return null;

      mask = parseInt(elems[1]);

      if(mask < 0)
         return null;
   }

   if(is_good_ipv4(ip_addr)) {
      if (mask === null)
         mask = 32;
      else if (mask > 32)
         return null;

      return {
         type: "ipv4",
         address: ip_addr,
         mask: mask
      };
   } else if(is_good_ipv6(elems[0])) {
      if (mask === null)
         mask = 128;
      else if (mask > 128)
         return(false);

      return {
         type: "ipv6",
         address: ip_addr,
         mask: mask
      };
   }

   return null;
}

function fbits(bits) {
    var sizes = ['bps', 'Kbit/s', 'Mbit/s', 'Gbit/s', 'Tbit/s'];
    if(bits < 0.005) return '0';
    var bits_log1000 = Math.log(bits) / Math.log(1000)
    var i = parseInt(Math.floor(bits_log1000));
    if (i < 0 || isNaN(i)) {
	i = 0;
    } else if (i >= sizes.length) { // prevents overflows
	return "> "   + sizes[sizes.length - 1]
    }

    if (i <= 1) {
	return Math.round(bits / Math.pow(1000, i) * 100) / 100 + ' ' + sizes[i]
    } else {
	var ret = parseFloat(bits / Math.pow(1000, i)).toFixed(2)
	if (ret % 1 == 0)
	    ret = Math.round(ret)
	return ret + ' ' + sizes[i]
    }
//    console.log('bits:' + bits+ ' ' + parseFloat(bits / Math.pow(1000, i)))
//    return Math.round(bits / Math.pow(1000, i), 2) + ' ' + sizes[i];
}

function fbits_from_bytes(bytes) {
  return(fbits(bytes * 8));
}

function fpackets(pps) {
    var sizes = ['pps', 'Kpps', 'Mpps', 'Gpps', 'Tpps'];
    if(pps < 0.005) return '0';
    var res = scaleValue(pps, sizes, 1000);

    // Round to two decimal digits
    return Math.round(res[0] * 100) / 100 + ' ' + res[1];
}

function fflows(fps) {
    var sizes = ['fps', 'Kfps', 'Mfps', 'Gfps', 'Tfps'];
    if(fps < 0.005) return '0';
    var res = scaleValue(fps, sizes, 1000);

    // Round to two decimal digits
    return Math.round(res[0] * 100) / 100 + ' ' + res[1];
}

function fint(value) {
    var x = Math.round(value);
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

function fdate(when) {
    var epoch = when*1000;
    var d = new Date(epoch);

    return(d);
}

function capitaliseFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

String.prototype.startsWith = function (string) {
    return(this.indexOf(string) === 0);
};

function get_trend(actual, before) {
    if((before === undefined) || (actual == before)) {
	return("<i class=\"fa fa-minus\"></i>");
    } else {
	return("<i class=\"fa fa-arrow-up\"></i>");
    }
}

function getOSIcon(name) {
    var icon = "";

    if (name.search("Linux") != -1 || name.search("Ubuntu") != -1) icon = '<i class=\'fa fa-linux fa-lg\'></i> ';
    else if (name.search("Android") != -1) icon = '<i class=\'fa fa-android fa-lg\'></i> ';
    else if (name.search("Windows") != -1 || name.search("Win32") != -1 || name.search("MSIE") != -1) icon = '<i class=\'fa fa-windows fa-lg\'></i> ';
    else if (name.search("iPhone") != -1 || name.search("iPad") != -1 || name.search("OS X") != -1 ) icon = '<i class=\'fa fa-apple fa-lg\'></i> ';

    return icon;
}

function abbreviateString(str, len) {
    if (!str)
	return "";
    if (str.length < len)
	return str;
    return str.substring(0, len)+"...";
}

// Convert bytes to human readable format
function bytesToSize(bytes) {
    var precision = 2;
    var kilobyte = 1024;
    var megabyte = kilobyte * 1024;
    var gigabyte = megabyte * 1024;
    var terabyte = gigabyte * 1024;

    if ((bytes >= 0) && (bytes < kilobyte))
	return bytes.toFixed(precision) + " Bytes";
    else if ((bytes >= kilobyte) && (bytes < megabyte))
	return (bytes / kilobyte).toFixed(precision) + ' KB';
    else if((bytes >= megabyte) && (bytes < gigabyte))
	return (bytes / megabyte).toFixed(precision) + ' MB';
    else if((bytes >= gigabyte) && (bytes < terabyte))
	return (bytes / gigabyte).toFixed(precision) + ' GB';
    else if(bytes >= terabyte)
	return (bytes / terabyte).toFixed(precision) + ' TB';
    else
	return bytes.toFixed(precision) + ' Bytes';
}

String.prototype.capitalizeSingleWord = function() {
    var uc = this.toUpperCase();

    if((uc == "ASN") || (uc == "OS"))
	return(uc);
    else
	return this.charAt(0).toUpperCase() + this.slice(1);
}

String.prototype.capitalize = function() {
    var res = this.split(" ");

    for (var i in res) {
	res[i] = res[i].capitalizeSingleWord();
    }

    return(res.join(" "));
}

function drawTrend(current, last, withColor) {
  if(current == last) {
    return("<i class=\"fa fa-minus\"></i>");
  } else if(current > last) {
    return("<i class=\"fa fa-arrow-up\""+withColor+"></i>");
  } else {
    return("<i class=\"fa fa-arrow-down\"></i>");
  }   
}

function toggleAllTabs(enabled){
    if(enabled === true)
	$("#historical-tabs-container").find("li").removeClass("disabled").find("a").attr("data-toggle", "tab");
    else
	$("#historical-tabs-container").find("li").addClass("disabled").find("a").removeAttr("data-toggle");
}

function disableAllDropdownsAndTabs(){
    $("select").each(function() {
      $(this).prop("disabled", true);
    });
    toggleAllTabs(false)
}

function enableAllDropdownsAndTabs(){
    $("select").each(function() {
	$(this).prop("disabled", false);
    });
    toggleAllTabs(true)
}

function capitalize(s) {
    return s && s[0].toUpperCase() + s.slice(1);
}

function addCommas(nStr) {
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

function scaleValue(val, sizes, scale) {
  if(val == 0) return [0, sizes[0]];

  var i = parseInt(Math.floor(Math.log(val) / Math.log(scale)));
  if (i < 0 || isNaN(i)) {
    i = 0;
  } else if (i >= sizes.length)
    i = sizes.length - 1;

  return [val / Math.pow(scale, i), sizes[i]];
}

function formatValue(val) {
  var sizes = ['', 'K', 'M', 'G', 'T'];
  var res = scaleValue(val, sizes, 1000);

  return Math.round(res[0]) + res[1];
}

function formatPackets(n) {
  return(addCommas(n.toFixed(0))+" Pkts");
}

function formatFlows(n) {
  return(addCommas(n.toFixed(0))+" Flows");
}

function fmillis(value) {
  var x = Math.round(value);
  var res = scaleValue(x, ["ms", "s"], 1000);

  return res[0] + " " + res[1];
}

function bytesToVolume(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if(bytes == 0) return '0 Bytes';
  var res = scaleValue(bytes, sizes, 1024);

  return res[0].toFixed(2) + " " + res[1];
};

function bytesToVolumeAndLabel(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes == 0) return '0 Bytes';
  var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return [ (bytes / Math.pow(1024, i)).toFixed(2), sizes[i] ];
};

function bitsToSize(bits, factor) {
  factor = factor || 1000;
  var sizes = ['bit/s', 'kbit/s', 'Mbit/s', 'Gbit/s', 'Tbit/s'];
  if (bits == 0) return '0 bps';
  var res = scaleValue(bits, sizes, factor);

  return res[0].toFixed(2) + " " + res[1];
};

function secondsToTime(seconds) {
   if(seconds < 1) {
      return("< 1 sec")
   }

   var days = Math.floor(seconds / 86400)
   var hours =  Math.floor((seconds / 3600) - (days * 24))
   var minutes = Math.floor((seconds / 60) - (days * 1440) - (hours * 60))
   var sec = seconds % 60
   var msg = "", msg_array = []

   if(days > 0) {
      years = Math.floor(days/365)

      if(years > 0) {
	 days = days % 365

	 msg = years + " year"
	 if(years > 1) {
	    msg += "s"
	 }

         msg_array.push(msg)
         msg = ""
      }
      msg = days + " day"
      if(days > 1) { msg += "s" }
      msg_array.push(msg)
      msg = ""
   }

    if(hours > 0) {
	if(hours < 10) { msg = "0" }
	msg += hours + ":";
    }
    
    if(minutes < 10) { msg += "0" }
    msg += minutes + ":";
    if(sec < 10) { msg += "0" }
    msg += sec;
    msg_array.push(msg)
    
   return msg_array.join(", ")
}

Date.prototype.format = function(format) { //author: meizz
  var o = {
     "M+" : this.getMonth()+1, //month
     "d+" : this.getDate(),    //day
     "h+" : this.getHours(),   //hour
     "m+" : this.getMinutes(), //minute
     "s+" : this.getSeconds(), //second
     "q+" : Math.floor((this.getMonth()+3)/3),  //quarter
     "S" : this.getMilliseconds() //millisecond
  }

  if(/(y+)/.test(format)) format=format.replace(RegExp.$1,
						(this.getFullYear()+"").substr(4 - RegExp.$1.length));
  for(var k in o)if(new RegExp("("+ k +")").test(format))
    format = format.replace(RegExp.$1,
			    RegExp.$1.length==1 ? o[k] :
			    ("00"+ o[k]).substr((""+ o[k]).length));
  return format;
}


function epoch2Seen(epoch) {
  /* 08/01/13 15:12:37 [18 min, 13 sec ago] */
  var d = new Date(epoch*1000);
  var tdiff = Math.floor(((new Date()).getTime()/1000)-epoch);

  return(d.format("dd/MM/yyyy hh:mm:ss")+" ["+secondsToTime(tdiff)+" ago]");
}

/* ticks for graph x axis */
function graphGetXAxisTicksFormat(diff_epoch) {
  var tickFormat;

   if(diff_epoch <= 86400) {
      tickFormat = "%H:%M:%S";
   } else if(diff_epoch <= 2*86400) {
      tickFormat = "%b %e, %H:%M:%S";
   } else {
      tickFormat = "%b %e";
   }

   return(tickFormat);
}

function paramsExtend(defaults, override) {
    return $.extend({}, defaults, override);
}

function paramsToForm(form, params) {
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
function paramsPairsEncode(params) {
   var i=0;
   var res = {};

   for (var k in params) {
      res["key_" + i] = k;
      res["val_" + i] = params[k];
      i = i+1;
   }

   return res;
}

// Extended disable function
jQuery.fn.extend({
    disable: function(state) {
        return this.each(function() {
            var $this = $(this);
            if($this.is('input, button, textarea, select'))
              this.disabled = state;
            else
              $this.toggleClass('disabled', state);
        });
    }
});

function hostkey2hostInfo(host_key) {
    var info;
    var hostinfo = [];

    host_key = host_key.replace(/____/g, ":");
    host_key = host_key.replace(/___/g, "/");
    host_key = host_key.replace(/__/g, ".");

    info = host_key.split("@");
    return(info);
} 

function handle_tab_state(nav_object, default_tab) {
   $('a', nav_object).click(function(e) {
     e.preventDefault();
   });

   // store the currently selected tab in the hash value
   $(" > li > a", nav_object).on("shown.bs.tab", function(e) {
      var id = $(e.target).attr("href").substr(1);
      if(history.replaceState) {
         // this will prevent the 'jump' to the hash
         history.replaceState(null, null, "#"+id);
      } else {
         // fallback
         window.location.hash = id;
      }
   });

   // on load of the page: switch to the currently selected tab
   var hash = window.location.hash;
   if (! hash) hash = "#" + default_tab;
   $('a[href="' + hash + '"]', nav_object).tab('show');
}

// "{0} to {1}".sformat(1, 10) -> "1 to 10"
String.prototype.sformat = function() {
  var args = arguments;
  return this.replace(/{(\d+)}/g, function(match, number) { 
    return typeof args[number] != 'undefined'
      ? args[number]
      : match
    ;
  });
};

if (typeof(String.prototype.contains) === "undefined") {
  String.prototype.contains = function(s) {
    return this.indexOf(s) !== -1;
  }
}

/* Used while searching hosts a and macs with typeahead */
function makeFindHostBeforeSubmitCallback(http_prefix) {
  return function(form, data) {
    if (data.type == "mac")
      form.attr("action", http_prefix + "/lua/mac_details.lua");
    else if (data.type == "snmp")
      form.attr("action", http_prefix + "/lua/pro/enterprise/snmp_device_details.lua");
    else
      form.attr("action", http_prefix + "/lua/host_details.lua");

    return true;
  }
}

function tstampToDateString(html_tag, format, tdiff) {
  tdiff = tdiff || 0;
  var timestamp = parseInt(html_tag.html()) + tdiff;
  var localized = d3.time.format(format)(new Date(timestamp*1000));
  html_tag.html(localized).removeClass("hidden");
  return localized;
}

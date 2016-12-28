// 2014-15 - ntop.org

function is_good_ipv4(ipv4) {
    if (/^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$|^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$|^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$/.test(ipv4)) {
	return(true);
    } else {
	return(false);
    }
}

function is_good_ipv6(ipv6) {
    if (/^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$|^(([a-zA-Z]|[a-zA-Z][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z]|[A-Za-z][A-Za-z0-9\-]*[A-Za-z0-9])$|^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$/.test(ipv6)) {
	return(true);
    } else {
	return(false);
    }
}

function isNumeric(value) {
    return /^\d+$/.test(value);
}

function is_network_mask(what) {
    var elems = what.split("/");
    var mask;

    if(!isNumeric(elems[1])) {
	return(false);
    }

    mask = parseInt(elems[1]);
    if(mask < 0) {
	return(false);
    }

    if(is_good_ipv4(elems[0])) {
	if(mask > 32) { return(false); }
	return(true);
    } else if(is_good_ipv6(elems[0])) {
	if(mask > 128) { return(false); }
	return(true);
    }

    return(false);
}

function fbits(bits) {
    var sizes = ['bps', 'Kbit/s', 'Mbit/s', 'Gbit/s', 'Tbit/s'];
    if(bits <= 0) return '0';
    var bits_log1000 = Math.log(bits) / Math.log(1000)
    var i = parseInt(Math.floor(bits_log1000));
    if (i < 0 || isNaN(i)) {
	return "< 1 " + sizes[0];
    } else if (i >= sizes.length) { // prevents overflows
	return "> "   + sizes[sizes.length - 1]
    } else if (i <= 1) {
	return Math.round(bits / Math.pow(1000, i)) + ' ' + sizes[i]
    } else {
	var ret = parseFloat(bits / Math.pow(1000, i)).toFixed(2)
	if (ret % 1 == 0)
	    ret = Math.round(ret)
	return ret + ' ' + sizes[i]
    }
//    console.log('bits:' + bits+ ' ' + parseFloat(bits / Math.pow(1000, i)))
//    return Math.round(bits / Math.pow(1000, i), 2) + ' ' + sizes[i];
}

function fpackets(pps) {
    var sizes = ['pps', 'Kpps', 'Mpps', 'Gpps', 'Tpps'];
    if(pps == 0) return '0';
    var i = parseInt(Math.floor(Math.log(pps) / Math.log(1000)));
    if (i < 0 || isNaN(i)) {
	i = 0;
	return "< 1 " + sizes[0];
    }
    return Math.round(pps / Math.pow(1000, i), 2) + ' ' + sizes[i];
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
	return bytes + " Bytes";
    else if ((bytes >= kilobyte) && (bytes < megabyte))
	return (bytes / kilobyte).toFixed(precision) + ' KB';
    else if((bytes >= megabyte) && (bytes < gigabyte))
	return (bytes / megabyte).toFixed(precision) + ' MB';
    else if((bytes >= gigabyte) && (bytes < terabyte))
	return (bytes / gigabyte).toFixed(precision) + ' GB';
    else if(bytes >= terabyte)
	return (bytes / terabyte).toFixed(precision) + ' TB';
    else
	return bytes + ' B';
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

function formatPackets(n) {
  return(addCommas(n)+" Pkts");
}

function bytesToVolume(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes == 0) return '0 Bytes';
  var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return (bytes / Math.pow(1024, i)).toFixed(2) + ' ' + sizes[i];
};

function bytesToVolumeAndLabel(bytes) {
  var sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes == 0) return '0 Bytes';
  var i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return [ (bytes / Math.pow(1024, i)).toFixed(2), sizes[i] ];
};

function bitsToSize(bits, factor) {
  var sizes = ['bps', 'Kbps', 'Mbps', 'Gbps', 'Tbps'];
  if (bits == 0) return '0 bps';
  var i = parseInt(Math.floor(Math.log(bits) / Math.log(1024)));
  if (i == 0) return bits + ' ' + sizes[i];
  return (bits / Math.pow(factor, i)).toFixed(2) + ' ' + sizes[i];
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
      msg = hours + " hour";
      if(hours > 1) { msg +=  "s" }
      msg_array.push(msg)
      msg = ""
   }

   if(minutes > 0) {
      msg_array.push(minutes + " min")
   }

   if(sec > 0) {
      msg_array.push(sec + " sec")
   }

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

/* ticks for graph tooltip header */
function graphGetHeaderTicksFormat(diff_epoch) {
   var tickFormat;

   /*if(diff_epoch < 86400) {
      tickFormat = "%H:%M:%S";
   } else {*/
   tickFormat = "%b %e, %H:%M:%S";

   return(tickFormat);
}

function nvGraphSetXTicksFormat(chart, diff_epoch) {
    /* Set the tooltip displayed on mouse over/move */
    chart.interactiveLayer.tooltip.headerFormatter(function (d) {
      return d3.time.format(graphGetHeaderTicksFormat(diff_epoch))(new Date(d*1000));
    });

    /* Set the x axis format */
    chart.xAxis.tickFormat(function(d) { return d3.time.format(graphGetXAxisTicksFormat(diff_epoch))(new Date(d*1000)) });
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

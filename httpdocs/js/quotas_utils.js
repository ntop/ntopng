
var quotas_utils_opts = {}

function initQuotaUtils(url_update_callback, pool_id, empty_quota_bar, disabled, reduced_timeout, proto_id_getter, traffic_quota_getter, time_quota_getter) {
   quotas_utils_opts = {
      url_update_callback: url_update_callback,
      pool_id: pool_id,
      empty_quota_bar: empty_quota_bar,
      reduced_timeout: reduced_timeout,
      disabled: disabled,
      proto_id_getter: proto_id_getter || function(row) { return $("td:first select", row).val(); },
      traffic_quota_getter: traffic_quota_getter || function(row) { return $("td:nth-child(4) div.progress", row).parent(); },
      time_quota_getter: time_quota_getter || function(row) { return $("td:nth-child(5) div.progress", row).parent(); },
   }
}

function replaceCtrlId(v, with_this) {
  return v.replace(/\_\_\_CTRL\_ID\_\_\_/g, with_this);
}

function makeResolutionButtonsAtRuntime(td_object, template_html, template_js, input_name, extra) {
   var extra = extra || {};
   var value = (extra.value !== undefined) ? (extra.value) : (td_object.html());
   var disabled = extra.disabled;
   var hidden = extra.hidden;
   var maxvalue = extra.max_value;
   var minvalue = extra.min_value;

   // fix ctrl id
   var buttons = $(replaceCtrlId(template_html, input_name));
   var div = $('<div class="text-center form-group ' + (extra.form_group_class || "") + '" style="padding:0; margin:0;"></div>');
   td_object.html("");
   div.appendTo(td_object);
   buttons.appendTo(div);

   var input = $('<input name="' + input_name + '" class="form-control" type="number" style="width:6em; text-align:right; margin-left:0.5em; display:inline;" required/>');
   if (maxvalue !== null)
      input.attr("data-max", maxvalue);

   input.attr("data-min", (minvalue !== null) ? minvalue : -1);
   input.appendTo($("td:first", div));

   if (disabled) {
      input.attr("disabled", "disabled");
      buttons.find("label").attr("disabled", "disabled");
   }

   // Add steps if available
   for (resol in extra.steps)
      input.attr("data-step-"+resol, extra.steps[resol]);

   // execute group specific code
   eval(replaceCtrlId(template_js, input_name));

   // set initial value
   resol_selector_set_value(input, value);

   return input;
}

function makeTrafficQuotaButtons(tr_obj, proto_id, field_selector, form_group_class) {
   field_selector = field_selector || "td:nth-child(4)";
   makeResolutionButtonsAtRuntime($(field_selector, tr_obj), traffic_buttons_html, traffic_buttons_code, "qtraffic_" + proto_id, {
      max_value: 100*1024*1024*1024 /* 100 GB */,
      min_value: 0,
      form_group_class: form_group_class,
   });
}

function makeTimeQuotaButtons(tr_obj, proto_id, field_selector, form_group_class) {
   field_selector = field_selector || "td:nth-child(5)";
   makeResolutionButtonsAtRuntime($(field_selector, tr_obj), time_buttons_html, time_buttons_code, "qtime_" + proto_id, {
      max_value: 23*60*60 /* 23 hours */,
      min_value: 0,
      form_group_class: form_group_class,
   });
}


var quota_update = null;
var quota_update_xhr = null;

function quotaUpdateCallback(url) {
   if (quota_update_xhr !== null) {
      quota_update_xhr.abort();
      quota_update_xhr = null;
   }

   quota_update_xhr = $.ajax({
      type: "GET",
      url: quotas_utils_opts.url_update_callback,
      data: {pool: quotas_utils_opts.pool_id, include_unlimited:true},
      success: function(response) {
         var rsp = $("<table>"+response+"</table>");

         $("#table-protos > div > table > tbody > tr").each(function() {
            var proto_id = quotas_utils_opts.proto_id_getter($(this)) || "default";
            var traffic_quota = quotas_utils_opts.traffic_quota_getter($(this));
            var time_quota = quotas_utils_opts.time_quota_getter($(this));

            if (typeof(proto_id) !== "undefined") {
               var tr_quota = $("tr[data-protocol='" + proto_id + "']", rsp);

               if (tr_quota.length === 1) {
                  var input_traffic_bar = $("div.progress:first", tr_quota);
                  var traffic_label = input_traffic_bar.closest("td").find("> span");
                  traffic_quota.html("<div class='text-center'><small>" + traffic_label.html() + "</small></div>");
                  input_traffic_bar
                     .css("height", "20px")
                     .css("margin", "2px 0 12px 0")
                     .appendTo(traffic_quota);

                  var input_time_bar = $("div.progress:last", tr_quota);
                  var time_label = input_time_bar.closest("td").find("> span");
                  time_quota.html("<div class='text-center'><small>" + time_label.html() + "</small></div>");
                  input_time_bar
                     .css("height", "20px")
                     .css("margin", "2px 0 12px 0")
                     .appendTo(time_quota);
               } else {
                  traffic_quota.html(quotas_utils_opts.empty_quota_bar);
                  time_quota.html(quotas_utils_opts.empty_quota_bar);
               }
            }
         });
      }
   });

   /* Periodic timeout */
   quota_update = setTimeout(quotaUpdateCallback, 5000);
}

function refreshQuotas() {
   if (quotas_utils_opts.disabled) {
      return null;
   }

   if (quota_update !== null) {
      clearTimeout(quota_update);
      quota_update = null;
   }

   /* Reduced timeout (only once) */
   quota_update = setTimeout(quotaUpdateCallback, quotas_utils_opts.reduced_timeout);
}

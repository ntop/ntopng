export function makeUniqueValidator(items_function) {
  return function(field) {
    var cmp_name = field.val();
    var count = 0;

    // this will be checked separately, with 'required' argument
    if(! cmp_name)
      return true;

    items_function(field).each(function() {
      var name = $(this).val();
      if (name == cmp_name)
        count = count + 1;
    });

    return count == 1;
  }
}

export function memberValueValidator(input) {
  var member = input.val();
  if (member === "") return true;

  return NtopUtils.is_mac_address(member) || NtopUtils.is_network_mask(member, true);
}

export function makePasswordPatternValidator(pattern) {
  return function passwordPatternValidator(input) {
    // required is checked separately
    if(!input.val()) return true;
    return $(input).val().match(pattern);
  }
}

export function passwordMatchValidator(input) {
  var other_input = $(input).closest("form").find("[data-passwordmatch]").not(input);
  if(!input.val() || !other_input.val()) return true;
  return other_input.val() === input.val();
}

export function poolnameValidator(input) {
  // required is checked separately
  if(!input.val()) return true;
  return $(input).val().match(/^[a-z0-9_]*$/);
}

export function passwordMatchRecheck(form) {
  var items = $(form).find("[data-passwordmatch]");
  var not_empty = 0;

  items.each(function() {
    if($(this).val() != "") not_empty++;
  });

  if(not_empty == items.length) items.trigger('input');
}

export function hostOrMacValidator(input) {
  var host = input.val();

  /* Handled separately */
  if (host === "") return true;

  return NtopUtils.is_mac_address(host) || NtopUtils.is_good_ipv4(host) || NtopUtils.is_good_ipv6(host);
}

export function ipAddressValidator(input) {
  var host = input.val();

  /* Handled separately */
  if (host === "") return true;

  return NtopUtils.is_good_ipv4(host) || NtopUtils.is_good_ipv6(host);
}

var filters_to_validate = {};

export function bpfValidator(filter_field, sync = false) {
  var filter = filter_field.val();

  if (filter.trim() === "") {
    return true;
  }

  var key = filter_field.attr("name");
  var timeout = 250;

  if (!filters_to_validate[key])
     filters_to_validate[key] = {ajax_obj:null, valid:true, timer:null, submit_remind:false, last_val:null};
  var status = filters_to_validate[key];

  var sendAjax = function () {
    status.timer = null;

    var finally_check = function (valid) {
      status.ajax_obj = null;
      status.valid = valid;
      status.last_val = filter;
    }

    if (status.last_val !== filter) {
      if (status.ajax_obj)
        status.ajax_obj.abort();

      status.ajax_obj = $.ajax({
        type: "GET",
        url: `${http_prefix}/lua/pro/rest/v2/check/filter.lua`,
        async: !sync,
        data: {
          query: filter,
        }, error: function() {
          finally_check(status.valid);
        }, success: function(data) {
          var valid = data.response ? true : false;
          finally_check(valid);
        }
      });
    } else {
      // possibly process the reminder
      finally_check(status.valid);
    }
  }

  if (sync) {
    sendAjax();
  } else if (status.last_val === filter) {
    // Ignoring
  } else {
    if (status.timer) {
      clearTimeout(status.timer);
      status.submit_remind = false;
    }
    status.timer = setTimeout(sendAjax, timeout);
  }

  return status.valid;
}


function makeUniqueValidator(items_function) {
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

function memberValueValidator(input) {
  var member = input.val();
  if (member === "") return true;

  return is_mac_address(member) || is_network_mask(member, true);
}

function makePasswordPatternValidator(pattern) {
  return function passwordPatternValidator(input) {
    // required is checked separately
    if(!input.val()) return true;
    return $(input).val().match(pattern);
  }
}

function passwordMatchValidator(input) {
  var other_input = $(input).closest("form").find("[data-passwordmatch]").not(input);
  if(!input.val() || !other_input.val()) return true;
  return other_input.val() === input.val();
}

function poolnameValidator(input) {
  // required is checked separately
  if(!input.val()) return true;
  return $(input).val().match(/^[a-z0-9_]*$/);
}

function passwordMatchRecheck(form) {
  var items = $(form).find("[data-passwordmatch]");
  var not_empty = 0;

  items.each(function() {
    if($(this).val() != "") not_empty++;
  });

  if(not_empty == items.length) items.trigger('input');
}

function hostOrMacValidator(input) {
  var host = input.val();

  /* Handled separately */
  if (host === "") return true;

  return is_mac_address(host) || is_good_ipv4(host) || is_good_ipv6(host);
}

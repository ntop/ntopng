/* 2016 - ntop.org
 * 
 * Utility functions for the are-you-sure jquery library.
 */

function aysHandleForm(form_selector, options) {
  if (! form_selector) form_selector = "form";      /* Form selector to attach are-you-sure to. Default is to apply it to every form in the page. */

  if (form_selector === "form") {
    /* Exclude data-ays-ignore forms by default */
    form_selector = 'form:not([data-ays-ignore="true"])';
  }

  var default_options = {
    submit_selector:   'button[type="submit"]:not([data-ays-ignore="true"])',
    on_dirty_callback: $.noop,      /* The callback to invoke when ays detects changes */
    on_clean_callback: $.noop,      /* The callback to invoke when ays detects form is clean */
    handle_submit_buttons: true,    /* If true, form submit buttons will be disabled when the form is clean, enabled when it's dirty */
    handle_datatable: false,        /* If true, datatable navigation buttons will be disabled when the form is dirty, enabled when it's clean. Note: you should call aysResetForm in the tableCallback */
    handle_tabs: false,             /* If true, navigation between bootstrap tabs will be disabled when the form is dirty, enabled when it's clean */
    disable_on_dirty: "",           /* An additional selector of items to be disabled on form dirty */
    ays_options: {},                /* Options to pass to are-you-sure initializer */
  };

  // note: recursive extend enabled
  var o = $.extend(true, {}, default_options, options);
  o.form_selector = form_selector;

  $(function() {
    $(o.form_selector).areYouSure(o.ays_options);

    if (o.handle_submit_buttons)
      // Initially submit buttons
      $(o.form_selector).find(o.submit_selector).attr("disabled", "disabled");

    $(o.form_selector).on('dirty.areYouSure', function() {
      if (o.handle_submit_buttons)
        $(this).find(o.submit_selector).removeAttr('disabled');

      if (o.handle_datatable) {
        // Disable pagination controls
        $(this).find("a.dropdown-toggle").attr("disabled", "disabled");
        $(this).find("ul.pagination a").css("pointer-events", "none").css("cursor", "default");
      }

      if (o.handle_tabs) {
        // Disable navigation between tabs
        $(".nav-tabs").find("a").each(function() {
          if (! $(this).closest("li").hasClass("active"))
            $(this).removeAttr("data-toggle").closest("li").addClass("disabled");
         });
      }

      $(o.disable_on_dirty).addClass("disabled");

      o.on_dirty_callback.bind(this)();
   });

   $(o.form_selector).on('clean.areYouSure', function() {
    if (o.handle_submit_buttons)
      $(this).find(o.submit_selector).attr("disabled", "disabled");

    if (o.handle_datatable) {
        // Enabled pagination controls
        $(this).find("a.dropdown-toggle").removeAttr("disabled");
        $(this).find("ul.pagination a").css("pointer-events", "").css("cursor", "");
      }

      if (o.handle_tabs) {
        // Enable navigation between tabs
        $(".nav-tabs").find("a").each(function() {
          $(this).attr("data-toggle", "tab").closest("li").removeClass("disabled");
        });
      }

      $(o.disable_on_dirty).removeClass("disabled");

      o.on_clean_callback.bind(this)();
    });
  });
}

/*
 * This should be triggered when a form monitored by ays changes input set.
 * It will reset ays state to the new form inputs.
 */
function aysResetForm(form_selector) {
  $(form_selector).trigger('reinitialize.areYouSure');
}

/*
 * This should be triggered when a form monitored by ays changes input set.
 * It will rescan the form input to update ays state.
 */
function aysUpdateForm(form_selector) {
  $(form_selector).trigger('rescan.areYouSure');
}

/*
 * This should be triggered when you manually update some input into a form
 * monitored by ays. It will recheck the form to determine form dirtiness.
 */
function aysRecheckForm(form_selector) {
  $(form_selector).trigger('checkform.areYouSure');
}

/*
 * Get a list of dirty fields. Useful for debugging.
 */
function aysGetDirty(form_selector, fields_selector) {
  fields_selector = fields_selector || ":input:not(input[type=submit]):not(input[type=button])";

  /* Note: this code is from ays */
  var getValue = function($field) {
    if ($field.hasClass('ays-ignore')
        || $field.hasClass('aysIgnore')
        || $field.attr('data-ays-ignore')
        || $field.attr('name') === undefined) {
      return null;
    }

    if ($field.is(':disabled')) {
      return 'ays-disabled';
    }

    var val;
    var type = $field.attr('type');
    if ($field.is('select')) {
      type = 'select';
    }

    switch (type) {
      case 'checkbox':
      case 'radio':
        val = $field.is(':checked');
        break;
      case 'select':
        val = '';
        $field.find('option').each(function(o) {
          var $option = $(this);
          if ($option.is(':selected')) {
            val += $option.val();
          }
        });
        break;
      default:
        val = $field.val();
    }

    return val;
  };

  var isFieldDirty = function($field) {
    var origValue = $field.data('ays-orig');
    var curValue = getValue($field);
    var dirty = (undefined !== origValue) && (origValue != curValue);

    return {dirty:dirty, origValue:origValue, curValue:curValue};
  };

  var l = [];

  $(form_selector).find(fields_selector).each(function() {
    var dirty_status = isFieldDirty($(this));

    if (dirty_status.dirty) {
      dirty_status.input = $(this);
      l.push(dirty_status);
    }
  });

  return l;
}

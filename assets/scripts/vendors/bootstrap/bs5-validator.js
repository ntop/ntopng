/*!
 * Bootstrap 5 Form Validator
 */
+function ($) {
  'use strict';

  var Validator = function (element, options) {
    this.$element = $(element);
    this.options = $.extend({}, Validator.DEFAULTS, options);
    this.options.errors = $.extend({}, Validator.DEFAULTS.errors, options.errors);

    for (var custom in this.options.custom) {
      if (!this.options.errors[custom]) {
        throw new Error('Missing error message for custom validator: ' + custom);
      }
    }

    // Register custom validators (class-level, same behaviour as old plugin)
    $.extend(Validator.VALIDATORS, this.options.custom);

    // Disable native browser validation bubbles
    this.$element.attr('novalidate', true);
    this.toggleSubmit();

    this.$element.on(
      'input.bs.validator change.bs.validator focusout.bs.validator',
      $.proxy(this.validateInput, this)
    );
    this.$element.on('submit.bs.validator', $.proxy(this.onSubmit, this));
  };

  Validator.INPUT_SELECTOR = ':input:not([type="submit"], button):enabled:visible';

  Validator.DEFAULTS = {
    delay: 500,
    disable: true,
    custom: {},
    errors: {}
  };

  // Class-level validators; custom ones are merged in at init time
  Validator.VALIDATORS = {
    'native': function ($el) {
      var el = $el[0];
      return el.checkValidity ? el.checkValidity() : true;
    }
  };

  Validator.prototype.validateInput = function (e) {
    var $el = $(e.target);

    if ($el.is('[type="radio"]')) {
      $el = this.$element.find('input[name="' + $el.attr('name') + '"]');
    }

    this.$element.trigger(e = $.Event('validate.bs.validator', { relatedTarget: $el[0] }));
    if (e.isDefaultPrevented()) return;

    var self = this;
    var errors = this.runValidators($el);

    $el.data('bs.validator.errors', errors);
    errors.length ? self.showErrors($el) : self.clearErrors($el);

    self.toggleSubmit();
    self.$element.trigger($.Event('validated.bs.validator', { relatedTarget: $el[0] }));
  };

  Validator.prototype.runValidators = function ($el) {
    var errors = [];
    var options = this.options;

    function getErrorMessage(key) {
      return $el.data(key + '-error')
        || $el.data('error')
        || (key === 'native' && $el[0].validationMessage)
        || options.errors[key];
    }

    $.each(Validator.VALIDATORS, function (key, validator) {
      if ((key === 'native' || $el.data(key) !== undefined) && !validator.call(null, $el)) {
        var error = getErrorMessage(key);
        if (error && errors.indexOf(error) === -1) errors.push(error);
      }
    });

    return errors;
  };

  Validator.prototype.validate = function () {
    var delay = this.options.delay;
    this.options.delay = 0;
    this.$element.find(Validator.INPUT_SELECTOR).trigger('input.bs.validator');
    this.options.delay = delay;
    return this;
  };

  Validator.prototype.showErrors = function ($el) {
    var $group = $el.closest('.form-group');
    var $block = $group.find('.help-block.with-errors');
    var errors = $el.data('bs.validator.errors') || [];

    if (!errors.length) return;

    var $list = $('<ul/>').addClass('list-unstyled')
      .append($.map(errors, function (error) { return $('<li/>').text(error); }));

    $block.empty().append($list);
    $group.addClass('has-error');
  };

  Validator.prototype.clearErrors = function ($el) {
    var $group = $el.closest('.form-group');
    var $block = $group.find('.help-block.with-errors');

    $block.empty();
    $group.removeClass('has-error');
  };

  Validator.prototype.hasErrors = function () {
    return !!this.$element.find(Validator.INPUT_SELECTOR).filter(function () {
      return !!(($(this).data('bs.validator.errors') || []).length);
    }).length;
  };

  Validator.prototype.isIncomplete = function () {
    return !!this.$element.find(Validator.INPUT_SELECTOR).filter('[required]').filter(function () {
      return this.type === 'checkbox' ? !this.checked
        : this.type === 'radio' ? !$('[name="' + this.name + '"]:checked').length
        : $.trim(this.value) === '';
    }).length;
  };

  Validator.prototype.onSubmit = function (e) {
    this.validate();
    if (this.isIncomplete() || this.hasErrors()) e.preventDefault();
  };

  Validator.prototype.toggleSubmit = function () {
    if (!this.options.disable) return;

    var $btn = $('button[type="submit"], input[type="submit"]')
      .filter('[form="' + this.$element.attr('id') + '"]')
      .add(this.$element.find('input[type="submit"], button[type="submit"]'));

    $btn.toggleClass('disabled', this.isIncomplete() || this.hasErrors());
  };

  Validator.prototype.destroy = function () {
    this.$element
      .removeAttr('novalidate')
      .removeData('bs.validator')
      .off('.bs.validator');

    this.$element.find(Validator.INPUT_SELECTOR)
      .off('.bs.validator')
      .removeData(['bs.validator.errors', 'bs.validator.deferred']);

    this.$element.find('.help-block.with-errors').empty();
    this.$element.find('.has-error').removeClass('has-error');
    this.$element.find('input[type="submit"], button[type="submit"]').removeClass('disabled');

    return this;
  };

  function Plugin(option) {
    return this.each(function () {
      var $this = $(this);
      var options = $.extend(
        {}, Validator.DEFAULTS, $this.data(),
        typeof option === 'object' && option
      );
      var data = $this.data('bs.validator');

      if (!data && option === 'destroy') return;
      if (!data) $this.data('bs.validator', (data = new Validator(this, options)));
      if (typeof option === 'string') data[option]();
    });
  }

  var old = $.fn.validator;
  $.fn.validator = Plugin;
  $.fn.validator.Constructor = Validator;

  $.fn.validator.noConflict = function () {
    $.fn.validator = old;
    return this;
  };

  // Data API — auto-init forms with data-bs-toggle="validator"
  $(window).on('load', function () {
    $('form[data-bs-toggle="validator"]').each(function () {
      var $form = $(this);
      Plugin.call($form, $form.data());
    });
  });

}(jQuery);

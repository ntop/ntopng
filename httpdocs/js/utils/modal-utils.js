(function ($) {

    class ModalHandler {

        constructor(element, settings) {
            this.element = element;
            this.settings = settings;
            this.csrf = settings.csrf;
            this.observer = new MutationObserver((list) => {
                this.bindFormValidation();
            });
            this.observer.observe(this.element[0], {
                childList: true,
                subtree: true
            });

            const submitButton = $(this.element).find(`[type='submit']`);
            if (!submitButton) throw new Error("The submit button was not found inside the form!");
        }

        fillFormModal() {
            return this.settings.loadFormData();
        }

        invokeModalInit() {
            this.settings.onModalInit(this.fillFormModal());
        }

        updateCsrf(newCsrf) {
            this.csrf = newCsrf;
        }

        delegateSubmit() {

            this.bindFormValidation();

            const self = this;
            $(this.element).on('submit', function(e) {
                e.preventDefault(); e.stopPropagation();
                self.makeRequest();
            });
        }

        bindFormValidation() {
            $(this.element).find(`input,textarea,select`).each(function(i, input) {

                const $input = $(this);
                function checkValidation(insertError) {

                    const $parent = $input.parent();
                    let $error = $parent.find(`.invalid-feedback`);
                    if ($error.length == 0) $error = $(`<span class='invalid-feedback'></span>`);

                    if (!input.validity.valid && input.validationMessage) {

                        $input.removeClass('is-valid').addClass('is-invalid');
                        $error.text(input.validationMessage);

                        if (insertError) $parent.append($error);
                    }
                    else {
                        $input.removeClass('is-invalid').addClass('is-valid');
                        $error.remove();
                    }

                }

                $(this).on('input', function(e) { checkValidation(false); });

                $(this).on('invalid', function(e) {
                    e.preventDefault();
                    checkValidation(true);
                });

            });
        }

        cleanForm() {
            /* remove validation fields and tracks */
            $(this.element).find('input,select,textarea').each(function(i, input) {
                $(this).removeClass(`is-valid`).removeClass(`is-invalid`);
            });
            /* reset all the values */
            $(this.element)[0].reset();
        }

        makeRequest() {

            const submitButton = $(this.element).find(`[type='submit']`);
            let dataToSend = this.settings.beforeSumbit();

            if (this.settings.method == 'post') dataToSend.csrf = this.csrf;
            dataToSend = $.extend(dataToSend, this.settings.submitOptions);

            /* clean previous state and disable button */
            submitButton.attr("disabled", "disabled");

            const self = this;
            const method = (this.settings.method == 'post') ? $.post : $.get;

            method(this.settings.endpoint, dataToSend)
                .done(function (response, textStatus) {
                    if (response.csrf) self.updateCsrf(response.csrf);
                    self.cleanForm();
                    self.settings.onSubmitSuccess(response, dataToSend);
                    /* unbind the old closure on submit event and bind a new one */
                    $(self.element).off('submit');
                    self.delegateSubmit();
                })
                .fail(function (jqxhr, textStatus, errorThrown) {
                    self.settings.onSubmitError(dataToSend, errorThrown);
                })
                .always(function (d) {
                    submitButton.removeAttr("disabled");
                });
        }

        delegateResetButton() {

            const resetButton = $form.find(`button[type='reset']`);
            if (!resetButton) return;
            resetButton.click(function(event) {

            });
        }
    }

    $.fn.modalHandler = function(args) {

        if (this.length != 1) throw new Error("Only an element can by initialized!");

        const settings = $.extend({
            csrf:               '',
            endpoint:           '',
            method:             'get',
            submitOptions:      {},
            loadFormData:       function() {},
            onModalInit:        function(d) {},
            onSubmitSuccess:    function(r, s) {},
            onSubmitError:      function(s) {},
            onModalReset:       function(d) {},
            beforeSumbit:       function() {}
        }, args);

        const mh = new ModalHandler(this, settings);
        mh.invokeModalInit();
        mh.delegateSubmit();

        return mh;
    }
}(jQuery));
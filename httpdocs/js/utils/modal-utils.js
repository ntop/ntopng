(function ($) {

    /* Use with:
     *
     * $('#edit-recipient-modal form').modalHandler({ ... })
     */
    class ModalHandler {

        constructor(form, options) {

            if (typeof options.csrf === "undefined") {
                throw new Error("ModalHandler::Missing CSRF token!");
            }

            this.element = form;
            this.dialog = $(form).closest(".modal");

            this.options = options;
            this.csrf = options.csrf;
            this.dontDisableSubmit = options.dontDisableSubmit;

            this.observer = new MutationObserver((list) => {
                this.bindFormValidation();
                this.toggleFormSubmission();
                this.initDataPatterns();
            });

            this.observer.observe(this.element[0], {
                childList: true,
                subtree: true
            });

            this.initialState = null;
            this.currentState = null;
            this.firstCloseAttempt = false;
            this.isSubmitting = false;

            const submitButton = $(this.element).find(`[type='submit']`);
            if (submitButton.length == 0) {
                throw new Error("ModalHandler::The submit button was not found inside the form!");
            }

            this.toggleFormSubmission();

        }

        initDataPatterns() {
            NtopUtils.initDataPatterns();
        }

        /**
         * Create a form's snapshot to save a form state
         */
        createFormSnapshot() {

            const snapshot = {
                inputs: {},
                hidden: []
            };

            $(this.element).find('textarea,select,input[type!="radio"]').each(function () {

                const type = $(this).prop('nodeName').toLowerCase();
                const name = $(this).attr('name');
                snapshot.inputs[`${type}[name='${name}']`] = $(this).val();
            });

            $(this.element).find(`[style='display: none;'], span.invalid-feedback`).each(function () {
                snapshot.hidden.push($(this));
            });

            return snapshot;
        }

        compareFormSnaphsot(s1, s2) {

            if (s1 == null || s2 == null) return true;

            for (let [key, value] of Object.entries(s1.inputs)) {
                if (s2.inputs[key] != value) return false;
            }

            return true;
        }

        delegateModalClosing() {

            const self = this;

            $(this.dialog).find('button.cancel').off('click').click(function () {

                self.firstCloseAttempt = false;
                $(self.element)[0].reportValidity();
                $(self.dialog).find('.confirm-closing').fadeOut(100, function () {
                    $(self.dialog).find('button.close').fadeIn(100);
                });
            });

            $(this.dialog).off('hide.bs.modal').on('hide.bs.modal', function (event) {

                if (self.isSubmitting) {
                    event.preventDefault();
                    return;
                }

                // if the form state hasn't changed then don't show the message
                if (self.compareFormSnaphsot(self.currentState, self.initialState)) {
                    return;
                }

                if (self.firstCloseAttempt) return;
                // abort the modal closing event
                event.preventDefault();

                // flag a close attempt has been invoked
                self.firstCloseAttempt = true;

                // show an alert to inform the user
                $(self.dialog).find('button.close').fadeOut(100, function () {
                    $(self.dialog).find('.confirm-closing').fadeIn(100);
                });

                return;

            });

            $(this.dialog).off('hidden.bs.modal').on('hidden.bs.modal', function (event) {

                // for each input inside the form restore the initial value
                // from the snapshot taken at init
                for (const [selector, value] of Object.entries(self.initialState.inputs)) {
                    $(self.dialog).find(selector).val(value);
                    $(self.dialog).find(selector).removeClass('is-invalid');
                }

                // hide the shwon elements
                self.initialState.hidden.forEach(($hidden) => {
                    $hidden.hide();
                });

                self.element.find(`[type='submit']`).attr("disabled", "disabled");
                self.currentState = null;
                self.firstCloseAttempt = false;

                $(self.dialog).find('.confirm-closing').fadeOut(100, function () {
                    $(self.dialog).find('button.close').fadeIn(100);
                });

                // clean the form when the modal is closed
                // to prevent the fields flickering
                self.cleanForm();
            });
        }

        fillFormModal() {
            return this.options.loadFormData();
        }

        invokeModalInit(data = {}) {

            const self = this;

            // reset form values when the modal closes
            this.delegateModalClosing();
            this.data = data || this.fillFormModal();
            this.options.onModalInit(this.data, this);

            $(this.element).parents('.modal').on('show.bs.modal', function () {
                self.options.onModalShow();
            });

            // create a initial form snapshot to restore elements on closing
            this.initialState = this.createFormSnapshot();
            this.currentState = null;

            this.delegateResetButton();
        }

        delegateSubmit() {

            this.bindFormValidation();

            const self = this;

            this.submitHandler = function (e) {
                if (!self.options.isSyncRequest) {
                    e.preventDefault();
                    e.stopPropagation();
                    self.makeRequest();
                }
            };

            $(this.element).on('submit', this.submitHandler);
        }

        bindFormValidation() {

            const self = this;

            // handle input validation
            $(this.element).find(`input,select,textarea`).each(async function (i, input) {

                // jQuery object of the current input
                const $input = $(this);
                // id to handle the current timeout set to show errors
                let timeoutId = -1;

                const validHostname = async () => {

                    // show the spinner to the user and set the input to readonly
                    const $spinner = $input.parent().find('.spinner-border');
                    $input.attr("readonly", true);
                    $spinner.show();

                    const response = await NtopUtils.resolveDNS($(input).val());

                    // hide the spinner and renable write to the input
                    $input.removeAttr("readonly");
                    $spinner.hide();

                    // if the response was negative then alert the user
                    if (response.rc < 0) {
                        input.setCustomValidity(response.rc_str);
                        return [false, i18n[response.rc_str]];
                    }

                    // return success for valid resolved hostnmae
                    input.setCustomValidity("");

                    return [true, "Success"];
                }

                const validInput = async (validation) => {

                    // if the input require to validate host name then perform a DNS resolve
                    if (validation.data.resolveDNS && $input.val().match(NtopUtils.REGEXES.domainName)) {
                        return await validHostname();
                    }

                    if (validation.data.cannotBeEmpty && validation.isInputEmpty) {
                        // trigger input validation flag
                        input.setCustomValidity("Please fill the input.");
                        return [false, validation.data.validationEmptyMessage || i18n.missing_field];
                    }

                    if (input.validity.patternMismatch) {
                        input.setCustomValidity("Pattern mismatch.");
                        return [false, validation.data.validationMessage || i18n.invalid_field];
                    }

                    if (input.validity.rangeOverflow) {
                        input.setCustomValidity("Value exceed the maximum value.");
                        return [false, validation.data.rangeOverflowMessage || i18n.invalid_field];
                    }

                    if (input.validity.rangeUnderflow) {
                        input.setCustomValidity("Value is under the minimum value.");
                        return [false, validation.data.rangeUnderflowMessage || i18n.invalid_field];
                    }

                    // set validation to true
                    input.setCustomValidity("");
                    return [true, "Success"];
                }

                const checkValidation = async () => {

                    const validation = {
                        data: {
                            validationMessage: $input.data('validationMessage'),
                            validationEmptyMessage: $input.data('validationEmptyMessage'),
                            cannotBeEmpty: ($input.attr('required') === "required") || ($input.data("validationNotEmpty") == true),
                            resolveDNS: $input.data('validationResolvedns'),
                            rangeOverflowMessage: $input.data('validationRangeOverflowMessage'),
                            rangeUnderflowMessage: $input.data('validationUnderflowOverflowMessage'),
                        },
                        isInputEmpty: (typeof($input.val()) === "string" ? $input.val().trim() == "" : false)
                    };

                    const [isValid, messageToShow] = await validInput(validation);
                    let $error = $input.parent().find(`.invalid-feedback`);

                    // if the error element doesn't exist then create a new one
                    if ($error.length == 0) {
                        $error = $(`<span class='invalid-feedback'></span>`);
                    }

                    // display the errors and color the input box
                    if (!isValid) {
                        $input.addClass('is-invalid');
                        $input.parent().append($error);
                        $error.text(messageToShow);
                    }
                    else {
                        // clean the validation message and remove the error
                        $input.removeClass('is-invalid');
                        $error.fadeOut(500, function () { $(this).remove(); });
                    }
                }

                $(this).off('input').on('input', function (e) {

                    self.currentState = self.createFormSnapshot();

                    // if exists already a Timeout then clear it
                    if (timeoutId != -1) clearTimeout(timeoutId);

                    if (!$input.attr("formnovalidate")) {
                        // trigger input validation after 300msec
                        timeoutId = setTimeout(() => {
                            checkValidation();
                            // trigger form validation to enable the submit button
                            self.toggleFormSubmission();
                        }, 300);
                        // the user has changed the input, we can abort the first close attempt
                        self.firstCloseAttempt = false;
                    }
                });

                $(this).off('invalid').on('invalid', function (e) {
                    e.preventDefault();
                    if (!$input.attr("formnovalidate")) {
                        checkValidation();
                    }
                });
            });

        }

        getModalID() {
            return $(this.element).parents('.modal').attr('id');
        }

        toggleFormSubmission() {

            let isValid = true;

            // if each input is marked as valid then enable the form submit button
            $(this.element).find('input:not(:disabled),select:not(:disabled),textarea:not(:disabled)').each(function (idx, input) {
                // make a concatenate & between valid flags
                isValid &= input.validity.valid;
            });

            isValid
                ? $(this.element).find(`[type='submit'],[type='test']`).removeAttr("disabled")
                : $(this.element).find(`[type='submit'],[type='test']`).attr("disabled", "disabled");
        }

        cleanForm() {
            /* remove validation class from fields */
            $(this.element).find('input,textarea,select').each(function (i, input) {
                $(this).removeClass(`is-valid`).removeClass(`is-invalid`);
            });
            /* reset all the values */
            $(this.element)[0].reset();
        }

        makeRequest() {

            const $feedbackLabel = $(this.element).find(`.invalid-feedback`);
            const submitButton = $(this.element).find(`[type='submit']`);
            let dataToSend = this.options.beforeSumbit(this.data);

            dataToSend.csrf = this.csrf;
            dataToSend = $.extend(dataToSend, this.options.submitOptions);

            /* clean previous state and disable button */
            submitButton.attr("disabled", "disabled");

            const self = this;

            if (this.options.endpoint) {
                let request;

                if (self.options.method == "post") {
                    request = $.ajax({
                        url: this.options.endpoint,
                        data: JSON.stringify(dataToSend),
                        method: self.options.method,
                        dataType: "json",
                        contentType: "application/json; charset=utf-8"
                    });
                }
                else {
                    request = $.get(this.options.endpoint, dataToSend);
                }

                this.isSubmitting = true;

                request.done(function (response, textStatus) {

                    // clear submitting state
                    self.isSubmitting = false;
                    // clear the current form state
                    self.currentState = null;

                    if (self.options.resetAfterSubmit) self.cleanForm();
                    $feedbackLabel.hide();

                    const success = self.options.onSubmitSuccess(response, dataToSend, self);
                    // if the submit return a true boolean then close the modal
                    if (success) {
                        self.dialog.modal('hide');
                    }

                    /* unbind the old closure on submit event and bind a new one */
                    $(self.element).off('submit', self.submitHandler);
                    self.delegateSubmit();
                })
                .fail(function (jqxhr, textStatus, errorThrown) {

                    self.isSubmitting = false;
                    const response = jqxhr.responseJSON;
                    if (response.rc !== undefined && response.rc < 0) {
                        $feedbackLabel.html(i18n.rest[response.rc_str]).show();
                    }

                    self.options.onSubmitError(response, dataToSend, textStatus, errorThrown);
                })
                .always(function (d) {
                    submitButton.removeAttr("disabled");
                });

            } else { // no endpoint

                    // clear the current form state
                    self.currentState = null;

                    //if (self.options.resetAfterSubmit) self.cleanForm();
                    $feedbackLabel.hide();

                    const success = self.options.onSubmitSuccess({}, dataToSend, self);
                    // if the submit return a true boolean then close the modal
                    if (success) {
                        self.dialog.modal('hide');
                    }

                    /* unbind the old closure on submit event and bind a new one */
                    $(self.element).off('submit', self.submitHandler);
                    self.delegateSubmit();

                    submitButton.removeAttr("disabled");
            }
        }

        delegateResetButton() {

            const self = this;
            const resetButton = $(this.element).find(`[type='reset']`);
            if (resetButton.length == 0) return;

            const defaultValues = NtopUtils.serializeFormArray($(this.element).serializeArray());

            resetButton.click(function (e) {

                e.preventDefault();

                // reset the previous values
                $(self.element).find('input:visible,select').each(function (i, input) {
                    const key = $(input).attr('name');
                    $(input).val(defaultValues[key])
                        .removeClass('is-invalid').removeClass('is-valid');
                });
            });
        }
    }

    $.fn.modalHandler = function (args) {

        if (this.length != 1) throw new Error("Only a form element can by initialized!");

        const options = $.extend({
            csrf: '',
            endpoint: '',
            resetAfterSubmit: true,
            /* True to skip the are-you-sure check on the dialog */
            dontDisableSubmit: false,
            /* True if the request isn't done by AJAX request */
            isSyncRequest: false,
            method: 'get',
            /**
             * Fetch data asynchronusly from the server or
             * loads data directly from the current page.
             * The function must returns the fetched data.
             *
             * @returns Returns the fetched data.
             * @example Below there is an example showing
             * how to use the function when fetching data from the server
             * ```
             * loadFormData: async function() {
             *      const data = await fetch(`endpoint/to/data`);
             *      const user = await data.json();
             *      return user;
             * }
             * ```
             */
            loadFormData: function () { },

            /**
             * onModalInit() is invoked when the plugin has been initialized.
             * This function is used to load the fetched data from `loadFormData()`
             * inside the form modal inputs.
             *
             * @param {object} loadedData This argument contains the fetched data obtained
             * from `loadFormData()`
             * @example Below there is an example showing how to use
             * the function (we suppose that loadFormData() returns the following
             * object: `loadedUser = {firstname: 'Foo', lastname: 'Bar', id: 1428103}`)
             * ```
             * onModalInit: function(loadedUser) {
             *      $(`#userModal form input#firstname`).val(loadedUser.firstname);
             *      $(`#userModal form input#lastname`).val(loadedUser.lastname);
             *      $(`#userModal form input#id`).val(loadedUser.id);
             * }
             * ```
             */
            onModalInit: function (loadedData) { },

            onModalShow: function () { },

            /**
             * The function beforeSubmit() is invoked after the user
             * submit the form. The function must return the data to
             * send to the endpoint. If the chosen method is `post`
             * a csrf will be add to the returned object.
             *
             * @example We show below a simple example how to use the function:
             * ```
             * beforeSubmit: function() {
             *      const body = {
             *          action: 'edit',
             *          JSON: JSON.stringify(serializeArrayForm($(`form`).serializeArray()))
             *      };
             *      return body;
             * }
             * ```
             */
            beforeSumbit: function () { return {} },

            /**
             * This function is invoked when the request to the endpoint
             * terminates successfully (200). Before the call of this function
             * a new csrf retrived from the server will be set for
             * future calls.
             *
             * @param {object} response This object contains the response
             * from the server
             *
             * @example Below there is an example showing a simple user case:
             * ```
             * onSubmitSuccess: function(response) {
             *      if (response.success) {
             *          console.log(`The user info has been edit with success!`);
             *      }
             * }
             * ```
             */
            onSubmitSuccess: function (response) { },

            /**
             * This function is invoked when the request to the endpoint
             * terminates with failure (!= 200). Before the call of this function
             * a new csrf retrived from the server will be set for
             * future calls.
             *
             * @param {object} sent This object contains the sent data to the endpoint
             * @param {string} textStatus It contains the error text status obtained
             * @param {object} errorThrown This object contains info about the error
             *
             * @example Below there is an example showing a simple user case:
             * ```
             * onSubmitError: function(sent, textStatus, errorThrown) {
             *      if (errorThrown) {
             *          console.error(`Ops, something went wrong!`);
             *          console.error(errorThrown);
             *      }
             * }
             * ```
             */
            onSubmitError: function (sent, textStatus, errorThrown) { },

            /**
             * This function is invoked when the user click the reset input
             * inside the form.
             *
             * @param {object} defaultData It contains the fetched data from
             * `loadFormData()`.
             *
             * @example Below there is an example how to use the function:
             * ```
             * onModalReset: function(defaultData) {
             *      $(`input#id`).val(defaultData.id);
             *      $(`input#name`).val(defaultData.name);
             *      $(`input#address`).val(defaultData.address);
             * }
             * ```
             */
            onModalReset: function (defaultData) { },
        }, args);

        const mh = new ModalHandler(this, options);
        mh.delegateSubmit();

        return mh;
    }
}(jQuery));

(function ($) {
    /* Assign a unique ID to each modal */
    let modal_id_ctr = 0;

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
                this.isFormValid();
            });

            this.observer.observe(this.element[0], {
                childList: true,
                subtree: true
            });

            const submitButton = $(this.element).find(`[type='submit']`);
            if (submitButton.length == 0) {
                throw new Error("ModalHandler::The submit button was not found inside the form!");
            }

            submitButton.attr("disabled", "disabled");

        }

        /**
         * Create a form's snapshot to save a form state
         */
        createFormSnapshot() {

            const snapshot = {
                inputs: {},
                hidden: []
            };

            $(this.element).find('textarea,select,input').each(function() {

                const type = $(this).prop('nodeName').toLowerCase();
                const name = $(this).attr('name');
                snapshot.inputs[`${type}[name='${name}']`] = $(this).val();
            });

            $(this.element).find(`[style='display: none;'], span.invalid-feedback`).each(function() {
                snapshot.hidden.push($(this));
            });

            return snapshot;

        }

        cleanFormOnModalClose() {

            const self = this;

            $(this.dialog).on('hidden.bs.modal', function() {

                // for each input inside the form restore the initial value
                // from the snapshot taken at init
                for (const [selector, value] of Object.entries(self.initialState.inputs)) {
                    $(selector).val(value);
                    $(selector).removeClass('is-invalid');
                }

                // hide the shwon elements
                self.initialState.hidden.forEach(($hidden) => {
                    $hidden.hide();
                });

                self.element.find(`[type='submit']`).attr("disabled", "disabled");
            });
        }

        fillFormModal() {
            return this.options.loadFormData();
        }

        invokeModalInit() {

            const self = this;

            // create a initial form snapshot to restore elements on closing
            this.initialState = this.createFormSnapshot();
            // reset form values when the modal closes
            this.cleanFormOnModalClose();

            this.options.onModalInit(this.fillFormModal());

            $(this.element).parents('.modal').on('show.bs.modal', function() {
                self.options.onModalShow();
            });

            this.delegateResetButton();
        }

        delegateSubmit() {

            this.bindFormValidation();

            const self = this;

            this.submitHandler = function(e) {

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
            $(this.element).find(`input,select,textarea`).each(function(i, input) {

                const $input = $(this);

                const checkValidation = (insertError) => {

                    const $parent = $input.parent();
                    let $error = $parent.find(`.invalid-feedback`);
                    if ($error.length == 0) $error = $(`<span class='invalid-feedback'></span>`);

                    if (!input.validity.valid && input.validationMessage) {

                        $input.addClass('is-invalid');
                        $error.text(input.validationMessage);

                        if (insertError) $parent.append($error);
                    }
                    else {
                        $input.removeClass('is-invalid');
                        $error.remove();
                    }

                }

                $(this).off('input').on('input', function(e) {
                    if (!$input.attr("formnovalidate")) {
                        checkValidation(false);
                        self.isFormValid();
                    }
                });

                $(this).off('invalid').on('invalid', function(e) {

                    e.preventDefault();
                    if (!$input.attr("formnovalidate"))
                        checkValidation(true);
                });

            });
        }

        isFormValid() {

            let isValid = true;

            $(this.element).find('input,select,textarea').each(function(idx, input) {
                isValid &= input.validity.valid;
            });

            isValid
                ? $(this.element).find(`[type='submit']`).removeAttr("disabled")
                : $(this.element).find(`[type='submit']`).attr("disabled", "disabled");
        }

        cleanForm() {
            /* remove validation fields */
            $(this.element).find('input,textarea,select').each(function(i, input) {
                $(this).removeClass(`is-valid`).removeClass(`is-invalid`);
            });
            /* reset all the values */
            $(this.element)[0].reset();
        }

        makeRequest() {

            const submitButton = $(this.element).find(`[type='submit']`);
            let dataToSend = this.options.beforeSumbit();

            dataToSend.csrf = this.csrf;
            dataToSend = $.extend(dataToSend, this.options.submitOptions);

            /* clean previous state and disable button */
            submitButton.attr("disabled", "disabled");

            let request;
            const self = this;

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

            request.done(function (response, textStatus) {
                if (self.options.resetAfterSubmit) self.cleanForm();
                self.options.onSubmitSuccess(response, dataToSend, self);
                /* unbind the old closure on submit event and bind a new one */
                $(self.element).off('submit', self.submitHandler);
                self.delegateSubmit();

                /* Allow the form to be closed */
                if (!self.dontDisableSubmit)
                    aysResetForm(self.form_sel);
            })
            .fail(function (jqxhr, textStatus, errorThrown) {
                self.options.onSubmitError(dataToSend, textStatus, errorThrown);
            })
            .always(function (d) {
                submitButton.removeAttr("disabled");
            });
        }

        delegateResetButton() {

            const self = this;
            const resetButton = $(this.element).find(`[type='reset']`);
            if (resetButton.length == 0) return;

            const defaultValues = serializeFormArray($(this.element).serializeArray());

            resetButton.click(function(e) {

                e.preventDefault();

                // reset the previous values
                $(self.element).find('input:visible,select').each(function(i, input) {
                    const key = $(input).attr('name');
                    $(input).val(defaultValues[key])
                        .removeClass('is-invalid').removeClass('is-valid');
                });
            });
        }
    }

    $.fn.modalHandler = function(args) {

        if (this.length != 1) throw new Error("Only a form element can by initialized!");

        const options = $.extend({
            csrf:               '',
            endpoint:           '',
            resetAfterSubmit:   true,
            /* True to skip the are-you-sure check on the dialog */
            dontDisableSubmit:  false,
            /* True if the request isn't done by AJAX request */
            isSyncRequest:      false,
            method:             'get',
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
            loadFormData:       function() {},

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
            onModalInit:        function(loadedData) {},

            onModalShow:        function() {},

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
            beforeSumbit:       function() { return {} },

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
            onSubmitSuccess:    function(response) {},

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
            onSubmitError:      function(sent, textStatus, errorThrown) {},

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
            onModalReset:       function(defaultData) {},
        }, args);

        const mh = new ModalHandler(this, options);
        mh.delegateSubmit();

        return mh;
    }
}(jQuery));

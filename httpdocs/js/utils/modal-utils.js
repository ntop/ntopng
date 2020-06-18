(function ($) {
    /* Assign a unique ID to each modal */
    let modal_id_ctr = 0;

    /* Use with:
     *
     * $('#edit-recipient-modal form').modalHandler({ ... })
     */
    class ModalHandler {

        /* element is the form object */
        constructor(element, options) {
            /* Check mandatory options */
            if(typeof options.csrf === "undefined")
                throw "ModalHandler: Missing CSRF token!";

            this.element = element;
            this.dialog = $(element).closest(".modal");
            this.options = options;
            this.csrf = options.csrf;
            this.dontDisableSubmit = options.dontDisableSubmit;
            this.observer = new MutationObserver((list) => {
                this.bindFormValidation();
            });
            this.observer.observe(this.element[0], {
                childList: true,
                subtree: true
            });

            const submitButton = $(this.element).find(`[type='submit']`);
            if (!submitButton) throw new Error("The submit button was not found inside the form!");

            /* Are you sure */
            if(!this.dontDisableSubmit) {

                const modal_id = modal_id_ctr++;

                $(this.element).attr("data-modal-handler-id", modal_id);
                this.form_sel = `[data-modal-handler-id="${modal_id}"]`;
                aysHandleForm(this.form_sel);

                const self = this;

                // handle modal-script close event
                this.dialog.on("hide.bs.modal", function(e) {
                    // If the form data has changed, ask the user if he wants to discard
                    // the changes
                    if($(self.element).hasClass('dirty')) {
                        // ask to user if he REALLY wants close modal
                        const result = confirm(`${i18n.are_you_sure}`);

                        if(!result)
                            e.preventDefault();
                        else
                            aysResetForm(self.form_sel);
                    }
                })
                .on("shown.bs.modal", function(e) {
                    // add focus to btn apply to enable focusing on the modal hence user can press escape button to
                    // close the modal
                    $(self.element).find("[type='submit']").trigger('focus');

                    // Reinitialize the form AYS state with the new data
                    aysResetForm(self.form_sel);
                });
            }
        }

        fillFormModal() {
            return this.options.loadFormData();
        }

        invokeModalInit() {
            this.options.onModalInit(this.fillFormModal());
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
                else {
                    aysResetForm(self.form_sel);
                }
            };
            $(this.element).on('submit', this.submitHandler);
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
            $(this.element).find('input:visible,textarea:visible,select').each(function(i, input) {
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

            const self = this;
            const method = (this.options.method == 'post') ? $.post : $.get;

            method(this.options.endpoint, dataToSend)
                .done(function (response, textStatus) {
                    if (self.options.resetAfterSubmit) self.cleanForm();
                    self.options.onSubmitSuccess(response, dataToSend);
                    /* unbind the old closure on submit event and bind a new one */
                    $(self.element).off('submit', self.submitHandler);
                    self.delegateSubmit();

                    /* Allow the form to be closed */
                    if(!self.dontDisableSubmit)
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

            const resetButton = $form.find(`[type='reset']`);
            const self = this;
            if (!resetButton) return;
            resetButton.click(function(event) {
                /* TODO: finish the reset logic */
                if(!self.dontDisableSubmit)
                    aysResetForm(self.form_sel);
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

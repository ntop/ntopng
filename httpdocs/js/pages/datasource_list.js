$(document).ready(function () {

    class TimeserieSourceBuilder {

        constructor() {
            this.counter = 0;
            this.currentSources = [];
            this.MIN_SOURCE_COUNTER = 1;
            this.MAX_SOURCE_COUNTER = 4;
        }

        canCreateSource() {
            return (this.currentSources.length <= this.MAX_SOURCE_COUNTER);
        }

        canRemoveSource() {
            return (this.currentSources.length > this.MIN_SOURCE_COUNTER);
        }

        buildNewSource(accordionName, name = `source-${this.counter++}`) {

            const timeserieSourceTemplate = $(`template#ds-source`).html();
            const tagTemplate = $(`template#ds-source-tag`).html();
            const timeseriesSourceInstance = new TimeserieSource({
                name: name,
                tagTemplate: tagTemplate,
                timeseriesFamilies: timeseriesFamilies,
                builder: this,
                accordionName: accordionName,
                $domElement: $(timeserieSourceTemplate),
                $tagElement: $(tagTemplate),
            });

            this.currentSources.push(timeseriesSourceInstance);

            return timeseriesSourceInstance;
        }

        emptyCurrentSources() {
            this.currentSources = [];
        }
    }

    class TimeserieSource {

        constructor(args) {

            const { $domElement, $tagElement, name, timeseriesFamilies, builder, accordionName } = args;
            this.$domElement = $domElement;
            this.$cardTitle = $domElement.find(`a[data-toggle='collapse']`);
            this.$btnRemoveSource = $domElement.find(`.btn-remove-source`);
            this.$familiesSelect = $domElement.find(`select.family`);
            this.$schemasSelect = $domElement.find(`select.schema`);
            this.$metricsSelect = $domElement.find(`select.metric`);
            this.$tagsContainer = $domElement.find('.tags-container');
            this.$tagElement = $tagElement;

            this.parentName = accordionName;
            this.steps = [$domElement.find('.step-1'), $domElement.find('.step-2')];
            this.stepsCompleted = [false, false];
            this.timeseriesFamilies = timeseriesFamilies;
            this.builder = builder;

            this.setSourceId(name);
            this.setAccordionParent(this.parentName);
            this.bindEventListeners();
        }

        get getDomElement() {
            return this.$domElement;
        }

        get identifierSource() {
            return `${this.$familiesSelect.val()}-${this.$schemasSelect.val()}-${this.$metricsSelect.val()}`;
        }

        setAccordionParent(parentName) {
            this.$domElement.find('.collapse').attr('data-parent', parentName);
        }

        bindEventListeners() {
            const self = this;
            this.$familiesSelect.change(function (e) {
                self.onFamilySelect(e);
            });
            this.$schemasSelect.change(function (e) {
                self.onSchemaSelect(e);
            });
            this.$metricsSelect.change(function (e) {
                self.onMetricSelect(e);
            });
            this.$btnRemoveSource.click(function (e) {
                self.onRemoveSourceClick(e);
            });
        }

        setSourceId(name) {
            this.$cardTitle.attr('href', `#source-${name}`);
            this.$domElement.find(`div.collapse.show`).attr('id', `source-${name}`);
            this.setCardTitle(name);
        }

        setCardTitle(title) {
            this.$cardTitle.html(`<b>${title}</b>`);
        }

        generateTag(tagName, tagValue) {
            const $tagElement = this.$tagElement.clone();
                $tagElement.find('span').html(`<b>${tagName}</b>`);
                $tagElement.find('input').val(`${tagValue}`)
                    .attr('pattern', `(\\\$${tagName}|[0-9]+)`)
                    .attr('minlength', 1)
                    .attr(`data-name`, tagName);
                this.$tagsContainer.append($tagElement);
            return $tagElement;
        }

        generateTags(tags) {

            this.$tagsContainer.empty();

            for (const tag of tags) {
                this.$tagsContainer.append(this.generateTag(tag, `$${tag}`));
            }
        }

        generateFilledTags(tags) {
            this.$tagsContainer.empty();
            for (const [tagName, tagValue] of Object.entries(tags)) {
                this.$tagsContainer.append(this.generateTag(tagName, tagValue));
            }
        }

        generateSelectOptions($select, values, generateEmpty = true, titleDummy = "Select ...") {

            const generateOption = (val, label, disabled = false) => {
                const $option = $(`<option value ${disabled ? 'disabled hidden selected' : ''}>${label}</option>`);
                if (val) {
                    $option.attr('value', val);
                }
                $select.append($option);
            };

            /* clean all the options */
            $select.find('option').remove();

            if (generateEmpty) generateOption(undefined, '', true);

            // generate dummy option
            generateOption(null, titleDummy, true);

            if (values.length > 0) {
                for (const val of values) generateOption(val, val);
                return;
            }

            for (const [key, _] of Object.entries(values).sort((a, b) => a[0].localeCompare(b[0])))
                generateOption(key, key);

        }

        onFamilySelect(event) {
            /* render only schema which belongs to the selected family */
            const schemas = this.timeseriesFamilies[this.$familiesSelect.val()];
            this.generateSelectOptions(this.$schemasSelect, schemas, "Select a schema...");
            /* show step one inside the card */
            if (!this.stepsCompleted[0]) {
                this.steps[0].fadeIn();
                this.stepsCompleted[0] = true;
            }
            if (this.stepsCompleted[1]) {
                this.steps[1].fadeOut();
                this.$schemasSelect.prop('selectedIndex', -1).removeClass('is-valid');
                this.stepsCompleted[0] = false;
            }
        }

        onSchemaSelect(event) {
            /* render only schema which belongs to the selected family */
            const schema = this.timeseriesFamilies[this.$familiesSelect.val()][this.$schemasSelect.val()];
            const { metrics, tags } = schema;
            this.generateSelectOptions(this.$metricsSelect, metrics, false, "Select a metric...");
            if (!this.preCreated) this.generateTags(tags);

            this.steps[1].fadeIn();
            this.stepsCompleted[1] = true;

        }

        onMetricSelect(event) {

            // check if exists a source with the same id
            const self = this;
            const exists = this.builder.currentSources.some((source) => {
                if (source == self) return false;
                return (source.identifierSource == self.identifierSource);
            });

            if (exists) {
                event.stopPropagation();
                event.preventDefault();
                this.$metricsSelect
                    .removeClass('is-valid').addClass('is-invalid');

                this.$metricsSelect.parent().append("<span class='invalid-feedback'>${i18n.source_exists}</span>");
                this.$metricsSelect.parents('form').find(`button[type='submit']`).attr("disabled", "disabled");
                return;
            }
            else {
                this.$metricsSelect.parent().find(`span.invalid-feedback`).remove();
                this.$metricsSelect.parents('form').find(`button[type='submit']`).removeAttr("disabled");
            }

            this.setCardTitle(`${this.$schemasSelect.val()} / ${this.$metricsSelect.val()}`);
        }

        onRemoveSourceClick(event) {

            if (!this.builder.canRemoveSource()) return;
            event.preventDefault();
            this.$domElement.fadeOut(200, function () { $(this).remove(); });
            this.removeSourceFromBuilder();
        }

        removeSourceFromBuilder() {
            const index = this.builder.currentSources.indexOf(this);
            if (index > -1) {
                this.builder.currentSources.splice(index, 1);
            }
        }

        fillSource(args) {

            const {metric, schema, tags} = args;
            const family = schema.split(":")[0];

            this.$familiesSelect.val(family).trigger('change');
            this.$schemasSelect.val(schema).trigger('change');
            this.$metricsSelect.val(metric);

            this.generateFilledTags(tags);
        }

    }

    const timeseriesSourceBuilder = new TimeserieSourceBuilder();

    let dtConfig = DataTableUtils.getStdDatatableConfig( [
        {
            text: '<i class="fas fa-plus"></i>',
            className: 'btn-link',
            action: function (e, dt, node, config) {
                $('#add-datasource-modal').modal('show');
            }
        }
    ]);
    dtConfig = DataTableUtils.setAjaxConfig(
        dtConfig,
        `${http_prefix}/lua/get_datasources.lua`,
    );
    dtConfig = DataTableUtils.extendConfig(dtConfig, {
        columns: [
            { data: 'alias' },
            {
                data: 'hash',
                render: (hash) => `<a target=\"_blank\" href=\"/datasources/${hash}\"'>${hash}</a>`
            },
            { data: 'scope' },
            { data: 'origin' },
            { data: 'data_retention' },
            {
                targets: -1,
                className: 'text-center',
                data: null,
                render: function (data) {

                    const isDeleteDisabled = data.in_use;

                    return (`
                        <div class='btn-group btn-group-sm'>
                            <a data-toggle='modal' href='#edit-datasource-modal' class="btn btn-info">Edit</a>
                            <a
                                data-toggle='modal'
                                href='${isDeleteDisabled ? '#' : '#remove-datasource-modal'}'
                                class="btn btn-${isDeleteDisabled ? 'secondary' : 'danger'}"></a>
                        </div<
                    `);
                }
            }
        ]
    });

    const $datasources_table = $(`#datasources-list`).DataTable(dtConfig);

    const prepareFormData = (form) => {

        const $form = $(form);
        const serialized = NtopngUtils.serializeFormArray($form.serializeArray());
        serialized.schemas = {};

        $form.find('fieldset').each(function(i, fieldset) {

            const schemaKey = $(this).find(`[name='schema[]']`).val();
            const metric = $(this).find(`[name='metric[]']`).val();
            const tags = {};

            $(this).find(`.tag`).each(function(i, tag) {
                tags[$(this).attr('data-name')] = $(this).val();
            });

            serialized.schemas[schemaKey] = {
                metric: metric,
                tags: tags
            };
        });

        return serialized;
    }

    let rowData = null;

    const edit_datasource_modal = $('#edit-datasource-modal form').modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_datasources.lua`,
        csrf: ds_csrf,
        beforeSumbit: function () {
            return {
                action: 'edit',
                JSON: JSON.stringify(prepareFormData(`#edit-datasource-modal form`))
            };
        },
        loadFormData: function() {
            return rowData;
        },
        onModalInit: function(data) {

            /* fill default datasource values */
            $(`#edit-datasource-modal form`).find('[name]').each(function(e) {
                $(this).val(data[$(this).attr('name')]);
            });

            const $sourcesContainer = $(`#edit-datasource-modal .ds-source-container`);
            const $btnAddSource = $(`#edit-datasource-modal .btn-add-source`);
            $btnAddSource.hide();
            $sourcesContainer.hide().empty();

            /* if the origin is of type timeseries then prepare sources */
            if (data.origin != "timeseries.lua") return;

            const schemas = data.schemas;
            for (const [key, schema] of Object.entries(schemas)) {

                const source = timeseriesSourceBuilder.buildNewSource(
                    `#edit-ds-source-container`,
                    `source-${data.hash}-${schema.metric}`
                );

                source.setCardTitle(`${key} / ${schema.metric}`);
                source.fillSource({
                    schema: key,
                    metric: schema.metric,
                    tags: schema.tags
                });

                $sourcesContainer.append(source.$domElement);
            }

            $sourcesContainer.show();
            $btnAddSource.show();
        },
        onSubmitSuccess: function(response) {
            if (response.success) {
                $datasources_table.ajax.reload();
                timeseriesSourceBuilder.emptyCurrentSources();
                $('#edit-datasource-modal').modal('hide');
            }
        }
    });

    /* bind edit datasource event */
    $(`#datasources-list`).on('click', `a[href='#edit-datasource-modal']`, function (e) {
        rowData = $datasources_table.row($(this).parent().parent()).data();
        edit_datasource_modal.invokeModalInit();
    });

    /* bind add datasource event */
    $(`#add-datasource-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_datasources.lua`,
        csrf: ds_csrf,
        beforeSumbit: function () {
            return {
                action: 'add',
                JSON: JSON.stringify(prepareFormData(`#add-datasource-modal form`))
            };
        },
        onSubmitSuccess: function (response) {
            if (response.success) {
                $('#add-datasource-modal').modal('hide');
                $(`#add-ds-source-container`).fadeOut().empty();
                $(`#btn-add-source`).fadeOut();
                timeseriesSourceBuilder.emptyCurrentSources();
                $datasources_table.ajax.reload();
            }
        }
    }).invokeModalInit();

    let dsRowData = null;

    const remove_ds_modal = $(`#remove-datasource-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_datasources.lua`,
        dontDisableSubmit: true,
        csrf: ds_csrf,
        beforeSumbit: () => {
            return {
                action: 'remove',
                JSON: JSON.stringify({
                    ds_key: $(`#remove-datasource-modal form input[name='ds_key']`).val()
                })
            }
        },
        loadFormData: () => dsRowData.hash,
        onModalInit: function (data) {
            $(`#remove-datasource-modal form input[name='ds_key']`).val(data);
        },
        onSubmitSuccess: function (response) {
            $datasources_table.ajax.reload();
            $('#remove-datasource-modal').modal('hide');
        }
    });

    /* bind remove datasource event */
    $(`#datasources-list`).on('click', `a[href='#remove-datasource-modal']`, function (e) {
        dsRowData = $datasources_table.row($(this).parent().parent()).data();
        remove_ds_modal.invokeModalInit();
    });

    /* **************************************************************************************** */

    $(`.btn-add-source`).click(function (e) {

        e.preventDefault(); e.stopPropagation();

        const $sourcesContainer = $(this).parents('form').find(`.ds-source-container`);
        if (timeseriesSourceBuilder.canCreateSource()) {
            $sourcesContainer.find('.collapse').collapse('hide');
            $sourcesContainer.append(
                timeseriesSourceBuilder.buildNewSource(`#add-ds-source-container`).$domElement
            );
        }
    });

    $(`#add-datasource-modal select[name='origin'], #edit-datasource-modal select[name='origin']`).change(function (e) {

        const isTimeseries = $(this).val() == "timeseries.lua";
        const $sourcesContainer = $(this).parents('form').find(`.ds-source-container`);
        const $btnAddSource = $(this).parents().find(`.btn-add-source`);
        if (!isTimeseries) {
            $sourcesContainer.fadeOut().empty();
            $btnAddSource.fadeOut();
            return;
        }
        // be sure to create new elements
        timeseriesSourceBuilder.emptyCurrentSources();
        $sourcesContainer.append(timeseriesSourceBuilder.buildNewSource(`#add-ds-source-container`).$domElement);
        $sourcesContainer.fadeIn();
        $btnAddSource.fadeIn();
    });

});

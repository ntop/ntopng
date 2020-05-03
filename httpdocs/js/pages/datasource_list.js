$(document).ready(function () {

    class TimeserieSourceBuilder {
        counter = 0;
        buildNewSource(name = `source-${this.counter++}`) {

            const timeserieSourceTemplate = $(`template#ds-source`).html();
            const tagTemplate = $(`template#ds-source-tag`).html();
            const timeseriesSourceInstance = new TimeserieSource({
                name: name,
                tagTemplate: tagTemplate,
                timeseriesFamilies: timeseriesFamilies,
                $domElement: $(timeserieSourceTemplate),
                $tagElement: $(tagTemplate),
            });

            return timeseriesSourceInstance;
        }
    }

    class TimeserieSource {

        constructor(args) {

            const { $domElement, $tagElement, name, timeseriesFamilies } = args;
            this.$domElement = $domElement;
            this.$cardTitle = $domElement.find(`a[data-toggle='collapse']`);
            this.$btnRemoveSource = $domElement.find(`.btn-remove-source`);
            this.$familiesSelect = $domElement.find(`select.family`);
            this.$schemasSelect = $domElement.find(`select.schema`);
            this.$metricsSelect = $domElement.find(`select.metric`);
            this.$tagsContainer = $domElement.find('.tags-container');
            this.$tagElement = $tagElement;

            this.steps = [$domElement.find('.step-1'), $domElement.find('.step-2')];
            this.stepsCompleted = [false, false];
            this.timeseriesFamilies = timeseriesFamilies;

            this.setSourceId(name);
            this.setEventListeners();
        }

        get getDomElement() {
            return this.$domElement;
        }

        setEventListeners() {
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

        generateSelectOptions($select, values) {

            const generateOption = (val, label, disabled = false) => {
                const $option = $(`<option value ${disabled ? 'disabled hidden selected' : ''}>${label}</option>`);
                if (val) {
                    $option.attr('value', val);
                }
                $select.append($option);
            };

            /* clean all the options */
            $select.find('option').remove();

            generateOption(undefined, '', true);

            if (values.length > 0) {
                for (const val of values) generateOption(val, val);
                return;
            }

            for (const [key, value] of Object.entries(values)) generateOption(key, key);


        }

        onFamilySelect(event) {
            /* render only schema which belongs to the selected family */
            const schemas = this.timeseriesFamilies[this.$familiesSelect.val()];
            this.generateSelectOptions(this.$schemasSelect, schemas);
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
            this.generateSelectOptions(this.$metricsSelect, metrics);
            if (!this.preCreated) this.generateTags(tags);

            this.steps[1].fadeIn();
            this.stepsCompleted[1] = true;
        }

        onMetricSelect(event) {
            this.setCardTitle(`${this.$schemasSelect.val()} / ${this.$metricsSelect.val()}`);
        }

        onRemoveSourceClick(event) {
            event.preventDefault();
            this.$domElement.fadeOut(200, function () { $(this).remove(); });
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

    const $datasources_table = $(`#datasources-list`).DataTable({
        lengthChange: false,
        pagingType: 'full_numbers',
        stateSave: true,
        dom: 'lfBrtip',
        initComplete: function () {

        },
        language: {
            info: i18n.showing_x_to_y_rows,
            search: i18n.search,
            infoFiltered: "",
            paginate: {
                previous: '&lt;',
                next: '&gt;',
                first: '«',
                last: '»'
            }
        },
        buttons: {
            buttons: [
                {
                    text: '<i class="fas fa-plus"></i>',
                    className: 'btn-link',
                    action: function (e, dt, node, config) {
                        $('#add-datasource-modal').modal('show');
                    }
                }
            ],
            dom: {
                button: {
                    className: 'btn btn-link'
                },
                container: {
                    className: 'float-right'
                }
            }
        },
        ajax: {
            url: `${http_prefix}/lua/get_datasources.lua`,
            type: 'GET',
            dataSrc: ''
        },
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
                render: function () {
                    return (`
                        <a data-toggle='modal' href='#edit-datasource-modal' class="badge badge-info">Edit</a>
                        <a data-toggle='modal' href='#remove-datasource-modal' class="badge badge-danger">Delete</a>
                    `);
                }
            }
        ]
    });

    const prepareFormData = (form) => {

        const $form = $(form);
        const serialized = serializeFormArray($form.serializeArray());
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

    /* bind edit datasource event */
    $(`#datasources-list`).on('click', `a[href='#edit-datasource-modal']`, function (e) {

        const rowData = $datasources_table.row($(this).parent()).data();

        $('#edit-datasource-modal form').modalHandler({
            method: 'post',
            endpoint: `${http_prefix}/lua/edit_datasources.lua`,
            csrf: edit_csrf,
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
                $sourcesContainer.hide().empty();
                /* if the origin is of type timeseries then prepare sources */
                if (data.origin != "timeseries.lua") return;
                console.log(data);
                const schemas = data.schemas;
                for (const [key, schema] of Object.entries(schemas)) {
                    const source = timeseriesSourceBuilder.buildNewSource(`source-${data.hash}-${schema.metric}`);
                    source.setCardTitle(`${key} - ${schema.metric}`);
                    source.fillSource({
                        schema: key,
                        metric: schema.metric,
                        tags: schema.tags
                    });
                    $sourcesContainer.append(source.$domElement);
                }
                $sourcesContainer.show();
            },
            onSubmitSuccess: function(response) {
                if (response.success) {
                    $datasources_table.ajax.reload();
                    $('#edit-datasource-modal').modal('hide');
                }
            }
        });
    });

    /* bind add datasource event */
    $(`#add-datasource-modal form`).modalHandler({
        method: 'post',
        endpoint: `${http_prefix}/lua/edit_datasources.lua`,
        csrf: add_csrf,
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
                $datasources_table.ajax.reload();
            }
        }
    });

    /* bind remove datasource event */
    $(`#datasources-list`).on('click', `a[href='#remove-datasource-modal']`, function (e) {

        const rowData = $datasources_table.row($(this).parent()).data();

        $(`#remove-datasource-modal form`).modalHandler({
            method: 'post',
            endpoint: `${http_prefix}/lua/edit_datasources.lua`,
            csrf: remove_csrf,
            beforeSumbit: () => {
                return {
                    action: 'remove',
                    JSON: JSON.stringify({
                        ds_key: $(`#remove-datasource-modal form input[name='ds_key']`).val()
                    })
                }
            },
            loadFormData: () => rowData.hash,
            onModalInit: function (data) {
                $(`#remove-datasource-modal form input[name='ds_key']`).val(data);
            },
            onSubmitSuccess: function (response) {
                $datasources_table.ajax.reload();
                $('#remove-datasource-modal').modal('hide');
            }
        });
    });

    /* **************************************************************************************** */

    $(`.btn-add-source`).click(function (e) {
        e.preventDefault(); e.stopPropagation();
        const $sourcesContainer = $(this).parents('form').find(`.ds-source-container`);
        $sourcesContainer.append(timeseriesSourceBuilder.buildNewSource().$domElement);
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

        $sourcesContainer.append(timeseriesSourceBuilder.buildNewSource().$domElement);
        $sourcesContainer.fadeIn();
        $btnAddSource.fadeIn();
    });

});
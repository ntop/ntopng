<!-- (C) 2013-26 - ntop.org -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>{{ _i18n('llm.edit_policy') }}</template>

        <template v-slot:body>
            <div class="row g-3">
                <div class="col-md-8">
                    <label class="form-label fw-bold mb-1">{{ _i18n('name') }}</label>
                    <input type="text" class="form-control form-control-sm"
                           v-model="form.name" maxlength="60" />
                </div>
                <div class="col-md-2">
                    <label class="form-label fw-bold mb-1">{{ _i18n('llm.run_every') }}</label>
                    <SelectSearch
                        :options="periodicity_options"
                        :selected_option="selected_periodicity"
                        theme="bootstrap-5"
                        @select_option="(opt) => selected_periodicity = opt"
                    />
                </div>
                <div class="col-md-2">
                    <label class="form-label fw-bold mb-1">{{ _i18n('llm.alert_score') }}</label>
                    <SelectSearch
                        :options="score_options"
                        :selected_option="selected_score"
                        theme="bootstrap-5"
                        @select_option="(opt) => selected_score = opt"
                    />
                </div>
                <div class="col-12">
                    <label class="form-label fw-bold mb-1">{{ _i18n('description') }}</label>
                    <input type="text" class="form-control form-control-sm"
                           v-model="form.description" />
                </div>
                <div class="col-12">
                    <label class="form-label fw-bold mb-1">{{ _i18n('llm.alert_message') }}</label>
                    <input type="text" class="form-control form-control-sm"
                           v-model="form.alert_description_gui" maxlength="120"
                           placeholder="Shown in alert table when a violation fires" />
                </div>
                <div class="col-12">
                    <label class="form-label fw-bold mb-1">{{ _i18n('llm.sql_query') }}</label>
                    <textarea class="form-control form-control-sm font-monospace"
                              v-model="form.sql_query" rows="6" style="font-size:0.76rem"></textarea>
                </div>
                <div class="col-12">
                    <label class="form-label fw-bold mb-1">{{ _i18n('llm.explanation') }}</label>
                    <textarea class="form-control form-control-sm"
                              v-model="form.explanation" rows="2"></textarea>
                </div>
            </div>
        </template>

        <template v-slot:footer>
            <button type="button" class="btn btn-primary"
                    @click="handle_submit" :disabled="!is_valid">
                Save
            </button>
        </template>
    </modal>
</template>

<script setup>
import { ref, computed, nextTick } from "vue";
import { default as modal }        from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";

const _i18n = (t) => i18n(t);

const modal_id = ref(null);
const emit     = defineEmits(['edit']);

const periodicity_options = [
    { label: _i18n('llm.min'),    value: "min"    },
    { label: _i18n('llm.5min'),   value: "5min"   },
    { label: _i18n('llm.hourly'), value: "hourly" },
    { label: _i18n('llm.daily'),  value: "daily"  },
];

const score_options = [
    { label: "Info (1)",        value: 1   },
    { label: "Notice (10)",     value: 10  },
    { label: "Warning (50)",    value: 50  },
    { label: "Error (100)",     value: 100 },
    { label: "Severe (150)",    value: 150 },
    { label: "Critical (200)",  value: 200 },
    { label: "Emergency (250)", value: 250 },
];

const form = ref({
    id:                   null,
    name:                 "",
    description:          "",
    alert_description_gui: "",
    sql_query:            "",
    explanation:          "",
});
const selected_periodicity = ref(periodicity_options[2]);
const selected_score       = ref(score_options[2]); // default: Warning 50

const is_valid = computed(() => form.value.name.trim().length > 0 && form.value.sql_query.trim().length > 0);

const show_edit = async (policy) => {
    form.value = {
        id:                   policy.id,
        name:                 policy.name                  || "",
        description:          policy.description           || "",
        alert_description_gui: policy.alert_description_gui || "",
        sql_query:            policy.sql_query             || "",
        explanation:          policy.explanation           || "",
    };
    selected_periodicity.value =
        periodicity_options.find(o => o.value === policy.periodicity_string) ?? periodicity_options[2];
    selected_score.value =
        score_options.find(o => o.value === Number(policy.custom_score)) ?? score_options[2];
    await nextTick();
    modal_id.value.show();
};

const handle_submit = () => {
    if (!is_valid.value) return;
    emit('edit', {
        ...form.value,
        periodicity:  selected_periodicity.value.value,
        custom_score: selected_score.value.value,
    });
    modal_id.value.close();
};

const close = () => modal_id.value.close();

defineExpose({ show_edit, close });
</script>

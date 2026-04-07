<!-- (C) 2026 - ntop.org -->
<template>
    <modal ref="modal_id" :size="1">
        <template v-slot:title>
            <span v-if="is_edit">
                <i class="fas fa-tag me-2"></i>{{ _i18n('llm.edit_model_price') }}
            </span>
            <span v-else>
                <i class="fas fa-tag me-2"></i>{{ _i18n('llm.register_model_price') }}
            </span>
        </template>

        <template v-slot:body>
            <!-- Provider -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-4">
                    <label class="form-label fw-bold mb-0">{{ _i18n('llm.provider') }}</label>
                </div>
                <div class="col-md-8">
                    <select class="form-select" v-model="form.provider" :disabled="is_edit">
                        <option value="">— {{ _i18n('select') }} —</option>
                        <option value="llm_anthropic">{{ _i18n('prefs.llm_anthropic') }}</option>
                        <option value="llm_openai">{{ _i18n('prefs.llm_openai') }}</option>
                        <option value="llm_local">{{ _i18n('prefs.llm_local') }}</option>
                    </select>
                </div>
            </div>

            <!-- Model name -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-4">
                    <label class="form-label fw-bold mb-0">{{ _i18n('llm.model') }}</label>
                </div>
                <div class="col-md-8">
                    <template v-if="!is_edit">
                        <select class="form-select mb-2" v-model="selectedPresetModel"
                            @change="onPresetModelChange">
                            <option value="">— {{ _i18n('select') }} —</option>
                            <option v-for="m in filteredPresetModels" :key="m" :value="m">{{ m }}</option>
                            <option value="__custom__">{{ _i18n('llm.custom_model_name') }}</option>
                        </select>
                        <input v-if="selectedPresetModel === '__custom__'"
                            type="text"
                            class="form-control"
                            v-model="form.model"
                            placeholder="e.g. my-custom-model"
                        />
                    </template>
                    <input v-else
                        type="text"
                        class="form-control"
                        v-model="form.model"
                        disabled
                    />
                </div>
            </div>

            <!-- Input price -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-4">
                    <label class="form-label fw-bold mb-0">{{ _i18n('llm.input_price_per_million') }}</label>
                    <div class="form-text">{{ _i18n('llm.price_hint_input') }}</div>
                </div>
                <div class="col-md-8">
                    <div class="input-group">
                        <span class="input-group-text">$</span>
                        <input
                            type="number"
                            class="form-control"
                            v-model.number="form.input_price_usd"
                            min="0"
                            step="0.01"
                            placeholder="0.00"
                        />
                        <span class="input-group-text">/ 1M tokens</span>
                    </div>
                </div>
            </div>

            <!-- Output price -->
            <div class="row mb-3 align-items-center">
                <div class="col-md-4">
                    <label class="form-label fw-bold mb-0">{{ _i18n('llm.output_price_per_million') }}</label>
                    <div class="form-text">{{ _i18n('llm.price_hint_output') }}</div>
                </div>
                <div class="col-md-8">
                    <div class="input-group">
                        <span class="input-group-text">$</span>
                        <input
                            type="number"
                            class="form-control"
                            v-model.number="form.output_price_usd"
                            min="0"
                            step="0.01"
                            placeholder="0.00"
                        />
                        <span class="input-group-text">/ 1M tokens</span>
                    </div>
                </div>
            </div>

            <!-- Local provider note -->
            <div v-if="form.provider === 'llm_local'" class="alert alert-info py-2 mb-0">
                <i class="fas fa-info-circle me-1"></i>
                {{ _i18n('llm.local_provider_price_note') }}
            </div>
        </template>

        <template v-slot:footer>
            <button type="button" class="btn btn-primary" @click="handleSubmit" :disabled="!can_submit">
                {{ _i18n('save') }}
            </button>
        </template>
    </modal>
</template>

<script setup>
import { ref, computed, nextTick, watch } from "vue";
import { ntopng_utility, ntopng_url_manager } from "../services/context/ntopng_globals_services";

import { default as modal } from "./modal.vue";

const _i18n = (t) => i18n(t);

const modal_id    = ref(null);
const is_edit     = ref(false);
const originalForm = ref(null);

const form = ref({
    provider:         '',
    model:            '',
    input_price_usd:  0,
    output_price_usd: 0,
});

const selectedPresetModel = ref('');
// All models fetched from usage history: [{ provider, model }, ...]
const usageModels = ref([]);

const filteredPresetModels = computed(() =>
    usageModels.value
        .filter(m => m.provider === form.value.provider)
        .map(m => m.model)
);

// Reset preset selection when provider changes
watch(() => form.value.provider, () => {
    if (is_edit.value) return;
    selectedPresetModel.value = '';
    form.value.model = '';
});

function onPresetModelChange() {
    if (selectedPresetModel.value === '__custom__' || selectedPresetModel.value === '') {
        form.value.model = '';
    } else {
        form.value.model = selectedPresetModel.value;
    }
}

async function fetchUsageModels() {
    try {
        const rsp = (await ntopng_utility.http_request(`${http_prefix}/lua/pro/rest/v2/get/llm/usage_filters.lua`)) || {};
        usageModels.value = Array.isArray(rsp.models) ? rsp.models : [];
    } catch (e) {
        usageModels.value = [];
    }
}

const emit = defineEmits(['save']);

const is_form_valid = computed(() =>
    form.value.provider !== '' && form.value.model.trim() !== ''
);

const is_dirty = computed(() => {
    if (!is_edit.value || !originalForm.value) return true;
    return form.value.input_price_usd  !== originalForm.value.input_price_usd ||
           form.value.output_price_usd !== originalForm.value.output_price_usd;
});

const can_submit = computed(() => is_form_valid.value && is_dirty.value);

const show = async (row) => {
    if (row) {
        is_edit.value = true;
        form.value = {
            provider:         row.provider,
            model:            row.model,
            input_price_usd:  parseFloat(row.input_price_usd)  || 0,
            output_price_usd: parseFloat(row.output_price_usd) || 0,
        };
        originalForm.value = { ...form.value };
    } else {
        is_edit.value = false;
        originalForm.value = null;
        form.value = { provider: '', model: '', input_price_usd: 0, output_price_usd: 0 };
        selectedPresetModel.value = '';
        fetchUsageModels();
    }
    await nextTick();
    modal_id.value.show();
};

const close = () => {
    modal_id.value.close();
};

const handleSubmit = () => {
    if (!can_submit.value) return;
    emit('save', { ...form.value, _is_edit: is_edit.value });
    close();
};

defineExpose({ show, close });
</script>

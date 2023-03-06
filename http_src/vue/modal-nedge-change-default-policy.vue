<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    <div class="container-fluid">

      <!-- Default Policy -->
      <div class="row form-group mb-3">
	<div class="col col-md-12">
          <label class="form-label">{{_i18n("nedge.page_rules_config.default policy")}}</label>
	    <SelectSearch v-model:selected_option="selected_action"
			  :options="actions">
	    </SelectSearch>
	</div>
      </div>

    </div>
  </template>
  <template v-slot:footer>
    <button type="button" @click="apply" class="btn btn-primary">{{_i18n('apply')}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";

const emit = defineEmits(['apply'])

const modal_id = ref(null);

const _i18n = (t) => i18n(t);

const title = _i18n("nedge.page_rules_config.modal_change_default_policy.title");

let default_action_value = "accept";
const actions = [
    { label: _i18n("nedge.page_rules_config.accept"), value: "accept" },
    { label: _i18n("nedge.page_rules_config.deny"), value: "deny" },
];
const selected_action = ref({});

const showed = () => {};

const show = (policy) => {
    selected_action.value = actions.find((a) => a.value == policy);
    modal_id.value.show();
};

const close = () => {
    modal_id.value.close();
};


function apply() {
    emit('apply', selected_action.value.value);
    close();
}

defineExpose({ show, close });

</script>

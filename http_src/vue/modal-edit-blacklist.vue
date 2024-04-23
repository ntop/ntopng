<!-- (C) 2022 - ntop.org     -->
<template>
  <modal @showed="showed()" ref="modal_id">
    <template v-slot:title>{{ title_delete }}</template>
    <template v-slot:body>
      <!-- Modal -->
      <div class="row form-group mb-3 has-feedback">
        <div class="col col-md-12">
          <label class="form-label">{{ _i18n("name") }}</label>
          <input ref="list_name" class="form-control" type="text" disabled="disabled" readonly>
        </div>
      </div>

      <div class="row form-group mb-3 has-feedback">
        <div class="col col-md-12">
          <label class="form-label">{{ _i18n("flow_details.url") }}</label>
          <input ref="url" class="form-control" type="text" />
        </div>
      </div>

      <div class="row form-group mb-3">
        <div class="col col-md-12">
          <label class="form-label">{{ _i18n("category_lists.enabled") }}</label>
          <div class="form-check form-switch">
            <input class="form-check-input" type="checkbox" ref="enable_blacklist" id="enable_blacklist" @click="change_checkbox"/>
          </div>
        </div>
      </div>

      <div class="row form-group mb-3">
        <div class="col col-md-6">
          <label class="form-label">{{ _i18n("category") }}</label>
          <select name="category" class="form-select" readonly disabled="disabled">
            <option ref="category_name" selected></option>
          </select>
        </div>
        <div class="col col-md-6">
          <label class="form-label">{{ _i18n("category_lists.update_frequency") }}</label>
          <select ref="list_update" class="form-select">
            <option ref="daily_frequency" value="86400">{{ _i18n("alerts_thresholds_config.daily") }}</option>
            <option ref="hourly_frequency" value="3600">{{ _i18n("alerts_thresholds_config.hourly") }}</option>
            <option ref="manual_frequency" value="0">{{ _i18n("alerts_thresholds_config.manual") }}</option>
          </select>
        </div>
      </div>
    </template>
    <template v-slot:footer>
      <button type="button" @click="edit_blacklist_" class="btn btn-primary btn-block">{{
    _i18n('category_lists.edit_list') }}</button>
    </template>
  </modal>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as modal } from "./modal.vue";

let title_delete = ref(i18n('category_lists.edit_list'));
const modal_id = ref(null);
const list_name = ref(null);
const daily_frequency = ref(null);
const hourly_frequency = ref(null);
const manual_frequency = ref(null);
const url = ref(null);
const list_update = ref(null);
const enable_blacklist = ref(null);
const category_name = ref(null);
const emit = defineEmits(['edit_blacklist']);

const props = defineProps({});

const show = (blacklist) => {
  list_name.value.value = blacklist.name
  url.value.value = blacklist.url
  category_name.value.value = blacklist.category_id
  category_name.value.innerHTML = blacklist.category
  category_name.value.setAttribute('selected', 'selected')
  if (blacklist.status == "enabled") {
    enable_blacklist.value.value = true
    enable_blacklist.value.setAttribute('checked', 'checked')
  } else {
    enable_blacklist.value.value = false
    enable_blacklist.value.removeAttribute('checked')
  }

  if (blacklist.update_frequency == 86400) {
    daily_frequency.value.setAttribute('selected', 'selected')
  } else if (blacklist.update_frequency == 3600) {
    hourly_frequency.value.setAttribute('selected', 'selected')
  } else {
    manual_frequency.value.setAttribute('selected', 'selected')
  }

  modal_id.value.show();
};

const change_checkbox = function() {
  let checked = enable_blacklist.value.value
  if(checked == "true") {
    enable_blacklist.value.value = false
  } else {
    enable_blacklist.value.value = true
  }
}

const edit_blacklist_ = () => {
  let checked = enable_blacklist.value.value
  if (checked == "true") {
    checked = 'on'
  } else {
    checked = 'off'
  }

  const params = {
    list_name: list_name.value.value,
    url: url.value.value,
    category: category_name.value.value,
    list_enabled: checked,
    list_update: list_update.value[list_update.value.selectedIndex].value
  }

  emit('edit_blacklist', params);

  close();
};

const close = () => {
  modal_id.value.close();
};


defineExpose({ show, close });

onMounted(() => { });

const _i18n = (t) => i18n(t);

</script>

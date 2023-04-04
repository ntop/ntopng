<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{title}}</template>
  <template v-slot:body>
    <input class="form-control" type="text" v-model="application_id" spellcheck="false" hidden>

    <template v-if="is_edit_page == false">
    <div class="form-group ms-2 me-2 mt-3 row">
      <label class="col-form-label col-sm-4">
        <b>{{ _i18n("app_name") }}</b>
      </label>
      <div class="col-8">
        <input class="form-control" type="text" v-model="application_name"  @input="check_validation" spellcheck="false">
      </div>
    </div>
    </template>
    <template v-else>
    <div class="form-group ms-2 me-2 mt-3 row">
      <label class="col-form-label col-sm-4">
        <b>{{ _i18n("category") }}</b>
      </label>
      <div class="col-8">
        <SelectSearch v-model:selected_option="selected_category"
          :options="category_list">
        </SelectSearch> 
      </div>
    </div>
    </template>

    <div class="form-group ms-2 me-2 mt-3 row">
      <label class="col-form-label col-sm-4">
        <b>{{ _i18n("category_custom_rule") }}</b>
      </label>
      <div class="col-8">
        <textarea class="form-control"  @input="check_validation" :placeholder="comment" rows="6" v-model="custom_rules" spellcheck="false"></textarea>
      </div>
    </div>
  </template>
  <template v-slot:footer>
    <NoteList
      :note_list="note_list">
    </NoteList>
    <template v-if="is_edit_page == false">
      <button type="button" @click="add_" class="btn btn-primary"  :disabled="disable_add">{{_i18n('add')}}</button>
    </template>
    <template v-else>
      <button type="button" @click="add_" class="btn btn-primary"  :disabled="disable_add">{{_i18n('apply')}}</button>
    </template>
  </template>
</modal>
</template>

<script setup>
import { ref, onBeforeMount, onMounted } from "vue";
import { default as modal } from "./modal.vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as NoteList } from "./note-list.vue";

const modal_id = ref(null);
const emit = defineEmits(['add']);
const is_edit_page = ref(false)
const _i18n = (t) => i18n(t);
const disable_add = ref(true)
let title = i18n('add_application');
const comment = ref(i18n('details.custom_rules_placeholder'));
const selected_category = ref({});
const category_list = ref([]);
const custom_rules = ref('')
const application_name = ref('')
const application_id = ref(null)

const last_application = ref({})

const note_list = [
  _i18n("custom_categories.each_host_separate_line"),
  _i18n("custom_categories.host_domain_or_port"),
  _i18n("custom_categories.example_port_range", {example1: "udp:443", example2: "tcp:1230-1235"}),
  _i18n("custom_categories.domain_names_substrings", {s1: "ntop.org", s2: "mail.ntop.org", s3: "ntop.org.example.com"})
]

const showed = () => {};

const props = defineProps({
  page_csrf: String,
  ifid: String,
});

function reset_modal_form() {
  application_name.value = '';
  selected_category.value = category_list.value[0];
  custom_rules.value = '';
}

const check_validation = () => {
  if(check_application_name() == true && check_custom_rules() == true)
    disable_add.value = false
  else
    disable_add.value = true
}

const check_application_name = () => {
  return(/^[A-Za-z0-9]*$/.test(application_name.value));
}

const check_custom_rules = () => {
  let check = true

  let rules = custom_rules.value.split("\n");
  rules.forEach((rule) => {
    check = check && ((/^((tcp|udp):(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3}))$/.test(rule)) || 
                      (/^((tcp|udp):(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3})-(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3}))$/.test(rule)) ||
                      (/^((?!.* ).*)$/.test(rule)) ||
                      (/^((([0-9][0-9]?|[0-1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-5])\.){3}([0-9][0-9]?|[0-1][0-9][0-9]|[2][0-4][0-9]|[2][5][0-5])|[a-zA-Z0-9]*):(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3})$/.test(rule)));
  })
  return check
}

const populate_modal_form = function(row) {
  selected_category.value = {
    id: row.category_id,
    label: row.category,
  }
  custom_rules.value = row.custom_rules.replace(',','\n');
  last_application.value = row;
  application_name.value = row.application
}

const format_category_list = function(list) {
  let _category_list = []
  const ordered_list = list.sort(
    (cat1, cat2) => (cat1.name < cat2.name) ? -1 : (cat1.name > cat2.name) ? 1 : 0
  )
  ordered_list.forEach((category) => {
    let item = { id: category.cat_id, label: category.name };
    _category_list.push(item);
  }) 
  return _category_list
}

const show = (row) => {
  reset_modal_form();  
  is_edit_page.value = false;
  title = i18n('add_application');
  
  if(row != null) {
    application_id.value = row.application_id
    is_edit_page.value = true;
    title = i18n('edit_application')
    populate_modal_form(row);
  }
  modal_id.value.show();
};

const add_ = () => {
  emit('add', { 
    l7_proto_id: application_id.value,
    protocol_alias: application_name.value,
    category: selected_category.value.id,
    custom_rules: custom_rules.value,
    is_edit_page: is_edit_page.value,
  });
    
  close();
};


const edit_ = () => {
  add_(true);
}

const close = () => {
  modal_id.value.close();
};

const loadCategoryList = (list) => {
  category_list.value = format_category_list(list);
};

onBeforeMount(() => {})

defineExpose({ show, close, loadCategoryList });


</script>

<style scoped>
</style>

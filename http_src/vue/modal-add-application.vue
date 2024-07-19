<!-- (C) 2022 - ntop.org     -->
<template>
  <modal @showed="showed()" ref="modal_id">
    <template v-slot:title>{{ title }}</template>
    <template v-slot:body>
      <input class="form-control" type="text" v-model="application_id" spellcheck="false" hidden>

      <template v-if="is_edit_page == false">
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-4">
            <b>{{ _i18n("app_name") }}</b>
          </label>
          <div class="col-8">
            <input class="form-control" type="text" v-model="application_name" @input="check_validation"
              spellcheck="false">
          </div>
        </div>
      </template>
      <template v-else>
        <div class="form-group ms-2 me-2 mt-3 row">
          <label class="col-form-label col-sm-4">
            <b>{{ _i18n("category") }}</b>
          </label>
          <div class="col-8">
            <SelectSearch v-model:selected_option="selected_category" :options="category_list">
            </SelectSearch>
          </div>
        </div>
      </template>

      <div class="form-group ms-2 me-2 mt-3 row">
        <label class="col-form-label col-sm-4">
          <b>{{ _i18n("category_custom_rule") }}</b>
        </label>
        <div class="col-8">
          <textarea class="form-control" @input="check_validation" :placeholder="comment" rows="6" v-model="custom_rules"
            spellcheck="false"></textarea>
        </div>
      </div>
    </template>
    <template v-slot:footer>
      <NoteList :note_list="note_list">
      </NoteList>
      <template v-if="is_edit_page == false">
        <button type="button" @click="add_" class="btn btn-primary" :disabled="disable_add">{{ _i18n('add') }}</button>
      </template>
      <template v-else>
        <button type="button" @click="add_" class="btn btn-primary" :disabled="disable_add">{{ _i18n('apply') }}</button>
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
let title = ref(i18n('add_application'));
const comment = ref(i18n('details.custom_rules_placeholder'));
const selected_category = ref({});
const category_list = ref([]);
const custom_rules = ref('')
const application_name = ref('')
const application_id = ref(null)

const last_application = ref({})

const note_list = [
  _i18n("custom_categories.each_host_separate_line"),
  _i18n("custom_categories.allowed_rules"),
  _i18n("custom_categories.ip_address"),
  _i18n("custom_categories.ip_address_port"),
  _i18n("custom_categories.ipv6_address"),
  _i18n("custom_categories.ipv6_address_port"),
  _i18n("custom_categories.port"),
  _i18n("custom_categories.port_range"),
  _i18n("custom_categories.host_domain")
]

const showed = () => { };

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
  if (check_application_name() == true && check_custom_rules() == true)
    disable_add.value = false
  else
    disable_add.value = true
}

const check_application_name = () => {
  return (/^[A-Za-z0-9_-]*$/.test(application_name.value));
}

const check_custom_rules = () => {
  let check = true

  let rules = custom_rules.value.split("\n");
  rules.forEach((rule) => {
    check = check && (/* tcp:1100 */(/^((tcp|udp):(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3}))$/.test(rule)) ||
                      /* tcp:1000-1002*/(/^((tcp|udp):(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3})-(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3}))$/.test(rule)) ||
//                      (/^((?!.* ).*)$/.test(rule)) ||
                      /* ip:1.1.1.1 */(/^(ip):(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/.test(rule)) ||
                      /* ip:1.1.1.1:1010 */(/^(ip):(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?):(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3})$/.test(rule)) ||
                      /* ipv6:[1:1:1:1:1:1:1:1] */(/^(ipv6):(\[((([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4})|(([0-9a-fA-F]{1,4}:){1,7}:)|(([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4})|(([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2})|(([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3})|(([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4})|(([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5})|([0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6}))|(:((:[0-9a-fA-F]{1,4}){1,7}|:)))\])$/.test(rule)) ||
                      /* ipv6:[1:1:1:1:1:1:1:1]:1010 */(/^(ipv6):\[((([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4})|(([0-9a-fA-F]{1,4}:){1,7}:)|(([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4})|(([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2})|(([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3})|(([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4})|(([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5})|([0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6}))|(:((:[0-9a-fA-F]{1,4}){1,7}|:)))\]:(6553[0-5]|655[0-2][0-9]\d|65[0-4](\d){2}|6[0-4](\d){3}|[1-5](\d){4}|[1-9](\d){0,3})$/.test(rule)) ||
                      /* host:google */(/^((host):[a-zA-Z0-9]+)$/.test(rule)) ||
                      /* host:google.com */(/(host):[a-zA-Z0-9].[a-zA-Z]/g.test(rule)) ||
                      /* Empty string */rule === '');
  })

  return check
}

const populate_modal_form = (row) => {
  let edit_row_category = null;
  category_list.value.forEach((item) => {
    if(item.id == row.category_id) {
      edit_row_category = item;
    }
  });

  selected_category.value = edit_row_category;
  custom_rules.value = row.custom_rules?.replace(',', '\n');
}

const show = (row) => {
  reset_modal_form();
  is_edit_page.value = false;
  title.value = i18n('add_application');

  if (row != null) {
    application_id.value = row.application_id;
    application_name.value = row.application;
    is_edit_page.value = true;
    title.value = `${i18n('edit_application')}: ${application_name.value}`;
    populate_modal_form(row);
  }
  modal_id.value.show();
  check_validation();
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

const close = () => {
  modal_id.value.close();
};

const format_category_list = (list) => {
  let formatted_list = [];
  list.forEach((item) => {
    formatted_list.push({
      id: item.cat_id,
      label: item.name,
      app_list: item.app_list

    })
  })

  // sort formatted categories;
  formatted_list = formatted_list.sort((a, b) => {
		    if (a == null || a.label == null) { return -1; }
		    if (b == null || b.label == null) { return 1; }
		    return a.label.toString().localeCompare(b.label.toString());
  });

  return formatted_list;
}

const loadCategoryList = (list) => {
  category_list.value = format_category_list(list);
};

onBeforeMount(() => { })

defineExpose({ show, close, loadCategoryList });


</script>

<style scoped></style>

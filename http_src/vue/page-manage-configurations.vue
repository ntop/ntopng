<!--
  (C) 2020-26 - ntop.org
-->
<template>
  <div>
    <div class="card card-shadow">
      <div class="card-body">
        <div class="radio-list">
          <template v-for="item in sorted_items" :key="item.key">
            <div class="form-check">
              <input
                class="form-check-input"
                type="radio"
                :id="`${item.key}-radio`"
                name="configuration"
                :value="item.key"
                v-model="selected_key"
              />
              <label class="form-check-label" :for="`${item.key}-radio`">
                {{ item.label }}
              </label>
            </div>
            <hr v-if="item.key === 'all'" />
          </template>
        </div>
      </div>
      <div class="card-footer d-flex gap-2">
        <button type="button" class="btn btn-primary" @click="open_import_modal">
          <i class="fas fa-file-import"></i>
          <span>{{ import_button_label }}</span>
        </button>
        <button type="button" class="btn btn-primary" @click="on_export_click">
          <i class="fas fa-file-export"></i>
          <span>{{ export_button_label }}</span>
        </button>
        <button type="button" class="btn btn-danger" @click="open_reset_modal">
          <i class="fas fa-undo-alt"></i>
          {{ _i18n('factory_reset') }}
        </button>
      </div>
    </div>

    <div class="notes bg-light border mt-3">
      <b>{{ _i18n('notes') }}</b>
      <ul>
        <li><p class="mb-1">{{ _i18n('manage_configurations.snmp_config_moved') }}</p></li>
        <li><p class="mb-1">{{ _i18n('manage_configurations.pool_import_doc') }}</p></li>
      </ul>
    </div>

    <!-- Import / Restore Modal -->
    <modal ref="import_modal_ref" @showed="on_import_modal_shown">
      <template v-slot:title><span v-html="import_modal_title"></span></template>
      <template v-slot:body>
        <p>{{ _i18n('host_pools.config_import_message') }}</p>
        <input
          type="file"
          ref="file_input_ref"
          class="form-control"
          accept=".json,.csv"
          @change="on_file_selected"
        />
        <UploadProgressBar
          :visible="import_started"
          :active="importing"
          :progress="upload_progress"
        />
        <div v-if="import_error" class="alert alert-danger mt-2">{{ import_error }}</div>
      </template>
      <template v-slot:footer>
        <button type="button" class="btn btn-secondary" @click="close_import_modal">
          {{ _i18n('cancel') }}
        </button>
        <button
          type="button"
          class="btn btn-primary"
          :disabled="!import_file_content || importing"
          @click="do_import"
        >
          {{ import_button_label }}
        </button>
      </template>
    </modal>

    <!-- Factory Reset Confirm Modal -->
    <modal ref="reset_modal_ref">
      <template v-slot:title>
        <span v-html="reset_modal_title" />
      </template>
      <template v-slot:body>
        <div class="alert alert-danger">
          <span v-html="reset_modal_body" />
        </div>
      </template>
      <template v-slot:footer>
        <button type="button" class="btn btn-secondary" @click="close_reset_modal">
          {{ _i18n('cancel') }}
        </button>
        <button type="button" class="btn btn-danger" :disabled="resetting" @click="do_reset">
          {{ _i18n('factory_reset') }}
        </button>
      </template>
    </modal>
  </div>
</template>

<script setup>
import { ref, computed } from "vue";
import { default as modal } from "./modal.vue";
import { default as UploadProgressBar } from "./upload-progress-bar.vue";

const props = defineProps({ context: Object });

const _i18n = (key) => i18n(key);

// State
const selected_key        = ref(props.context.selected_item || "all");
const import_modal_ref    = ref(null);
const reset_modal_ref     = ref(null);
const file_input_ref      = ref(null);
const import_file_content = ref(null);
const import_file_name    = ref("");
const import_error        = ref("");
const importing           = ref(false);
const import_started      = ref(false);
const upload_progress     = ref(0);
const resetting           = ref(false);

const sorted_items = computed(() =>
  Object.values(props.context.configuration_items || {}).sort(
    (a, b) => a.order - b.order
  )
);

const selected_label = computed(() => {
  const item = sorted_items.value.find((i) => i.key === selected_key.value);
  const lbl = item ? item.label : "";
  const idx = lbl.indexOf("(");
  return idx >= 0 ? lbl.substring(0, idx).trim() : lbl;
});

const import_button_label = computed(() =>
  selected_key.value === "all" ? _i18n("restore") : _i18n("import")
);

const export_button_label = computed(() =>
  selected_key.value === "all" ? _i18n("backup") : _i18n("export.export")
);

const import_modal_title = computed(() => {
  const lbl =
    selected_key.value === "all"
      ? props.context.product || "ntopng"
      : selected_label.value;
  return _i18n("manage_configurations.import_modal.title").replace(
    /%\{import_element\}/g,
    lbl
  );
});

const reset_modal_title = computed(() => {
  const lbl =
    selected_key.value === "all" ? props.context.product || "ntopng" : selected_label.value;
  return _i18n("manage_configurations.factory_reset.title").replace(
    /%\{reset_element\}/g,
    lbl
  );
});

const reset_modal_body = computed(() => {
  const lbl =
    selected_key.value === "all" ? props.context.product || "ntopng" : selected_label.value;
  return _i18n("manage_configurations.factory_reset.body").replace(
    /%\{reset_element\}/g,
    lbl
  );
});

// Import
function open_import_modal() {
  import_file_content.value = null;
  import_file_name.value = "";
  import_error.value = "";
  import_started.value = false;
  upload_progress.value = 0;
  if (file_input_ref.value) file_input_ref.value.value = "";
  import_modal_ref.value.show();
}

function close_import_modal() {
  import_modal_ref.value.close();
}

function on_import_modal_shown() {
  import_file_content.value = null;
  import_file_name.value = "";
  import_error.value = "";
}

function on_file_selected(evt) {
  import_error.value = "";
  import_file_content.value = null;
  const file = evt.target.files[0];
  if (!file) return;
  import_file_name.value = file?.name ?? "";
  import_file_content.value = file;
}

async function do_import() {
  if (!import_file_content.value) return;
  importing.value = true;
  import_started.value = true;
  upload_progress.value = 0;
  import_error.value = "";
  const key = selected_key.value;

  try {
    const isCsv = import_file_name.value.toLowerCase().endsWith(".csv");

    const formData = new FormData();
    formData.append("JSON", import_file_content.value, import_file_content.value.name);

    const urlParams = new URLSearchParams({ csrf: props.context.csrf });
    if (isCsv) urlParams.set("is_csv", "1");

    const data = await new Promise((resolve, reject) => {
      const xhr = new XMLHttpRequest();

      xhr.upload.onprogress = (e) => {
        if (!e.lengthComputable) return;
        upload_progress.value = Math.round((e.loaded / e.total) * 100);
      };

      xhr.onload = () => {
        // Transfer completed, set progress to 100
        upload_progress.value = 100;
        importing.value = false;

        try { resolve(JSON.parse(xhr.responseText)); }
        catch { reject(new Error("Invalid JSON response")); }
      };

      xhr.onerror = () => reject(new Error("Network error"));
      xhr.open("POST", `${http_prefix}/lua/rest/v2/import/${key}/config.lua?${urlParams}`);
      xhr.send(formData);
    });

    if (data.rc < 0) {
      import_error.value = data.rc_str || _i18n("invalid_file");
      return;
    }

    ToastUtils.showToast({
      id: "import-configuration-alert",
      level: "success",
      title: _i18n("success"),
      body: _i18n("manage_configurations.messages.import_success"),
      delay: 2000,
    });

    close_import_modal();
  } catch (err) {
    import_error.value = _i18n("invalid_file");
    console.error("Import error:", err);
  } finally {
    importing.value = false;
  }
}

// Factory Reset
function open_reset_modal() {
  reset_modal_ref.value.show();
}

function close_reset_modal() {
  reset_modal_ref.value.close();
}

async function do_reset() {
  resetting.value = true;
  const key = selected_key.value;

  try {
    const resp = await fetch(`${http_prefix}/lua/rest/v2/reset/${key}/config.lua`);
    const data = await resp.json();

    if (data.rc >= 0) {
      const product = props.context.product || "ntopng";
      const body =
        key === "all"
          ? _i18n("manage_configurations.messages.reset_all_success").replace(
              /%\{product\}/g,
              product
            )
          : _i18n("manage_configurations.messages.reset_success");

      ToastUtils.showToast({
        id: "reset-configuration-alert",
        level: "success",
        title: _i18n("success"),
        body,
        delay: 2000,
      });
    }

    close_reset_modal();
  } catch (err) {
    console.error("Reset error:", err);
    close_reset_modal();
  } finally {
    resetting.value = false;
  }
}

// Export

async function on_export_click() {
  const url = new URL(
    `${http_prefix}/lua/rest/v2/export/${selected_key.value}/config.lua`,
    location.origin
  );
  url.searchParams.set("download", "1");
  window.open(url.toString());

}
</script>
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
        <a :download="export_filename" :href="export_href" class="btn btn-primary">
          <i class="fas fa-file-export"></i>
          <span>{{ export_button_label }}</span>
        </a>
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
      <template v-slot:title>{{ reset_modal_title }}</template>
      <template v-slot:body>
        <div class="alert alert-danger">{{ reset_modal_body }}</div>
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

const props = defineProps({ context: Object });

const _i18n = (key) => i18n(key);

// ── State ──────────────────────────────────────────────────────────────────────
const selected_key        = ref(props.context.selected_item || "all");
const import_modal_ref    = ref(null);
const reset_modal_ref     = ref(null);
const file_input_ref      = ref(null);
const import_file_content = ref(null);
const import_error        = ref("");
const importing           = ref(false);
const resetting           = ref(false);

// ── Computed ──────────────────────────────────────────────────────────────────
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

const export_filename = computed(() => `${selected_key.value}_config.json`);

const export_href = computed(() => {
  const url = new URL(
    `${http_prefix}/lua/rest/v2/export/${selected_key.value}/config.lua`,
    location.origin
  );
  url.searchParams.set("download", "1");
  return url.toString();
});

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

// ── Import ─────────────────────────────────────────────────────────────────────
function open_import_modal() {
  import_file_content.value = null;
  import_error.value = "";
  if (file_input_ref.value) file_input_ref.value.value = "";
  import_modal_ref.value.show();
}

function close_import_modal() {
  import_modal_ref.value.close();
}

function on_import_modal_shown() {
  import_file_content.value = null;
  import_error.value = "";
}

function on_file_selected(evt) {
  import_error.value = "";
  import_file_content.value = null;
  const file = evt.target.files[0];
  if (!file) return;
  const reader = new FileReader();
  reader.onload = (e) => { import_file_content.value = e.target.result; };
  reader.onerror = () => { import_error.value = _i18n("invalid_file"); };
  reader.readAsText(file);
}

async function do_import() {
  if (!import_file_content.value) return;
  importing.value = true;
  import_error.value = "";
  const key = selected_key.value;

  try {
    let json_str = import_file_content.value;

    // Strip nightly-backup payload to avoid huge uploads
    try {
      const conf = JSON.parse(json_str);
      if (conf?.modules?.all?.["ntopng.prefs.config_save_backup"]) {
        delete conf.modules.all["ntopng.prefs.config_save_backup"];
        json_str = JSON.stringify(conf);
      }
    } catch (_) { /* CSV pool import — leave content as-is */ }

    const body = new URLSearchParams({ JSON: json_str, csrf: props.context.csrf });
    const resp = await fetch(
      `${http_prefix}/lua/rest/v2/import/${key}/config.lua`,
      { method: "POST", body }
    );
    const data = await resp.json();

    if (data.rc < 0) {
      import_error.value = data.rc_str || _i18n("invalid_file");
      return;
    }

    close_import_modal();
  } catch (err) {
    import_error.value = _i18n("invalid_file");
    console.error("Import error:", err);
  } finally {
    importing.value = false;
  }
}

// ── Factory Reset ──────────────────────────────────────────────────────────────
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
</script>

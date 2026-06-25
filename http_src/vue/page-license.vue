<!--
  (C) 2020-26 - ntop.org
-->

<template>
  <div class="page-license position-relative">

    <Loading :isLoading="isLoading" />

    <div v-if="!isLoading && !license.system_id" class="alert alert-warning">
      {{ _i18n('license_page.no_system_id') }}
    </div>

    <div v-if="!isLoading && license.system_id">

      <!-- License status card -->
      <div class="license-card card mb-4">
        <div class="card-body p-0">
          <table class="license-table table table-sm table-striped mb-0">
            <tbody>

              <!-- Status -->
              <tr v-if="license.license_type">
                <th>{{ _i18n('license_page.status') }}</th>
                <td>
                  <span :class="['badge', license.has_valid_license ? 'bg-success' : 'bg-danger']">
                    {{ license.has_valid_license ? _i18n('license_page.valid') : _i18n('license_page.not_valid') }}
                  </span>
                </td>
              </tr>

              <!-- System ID -->
              <tr>
                <th>SystemId</th>
                <td>
                  <div class="d-flex align-items-center gap-2 flex-wrap">
                    <a :href="license.system_id_href" target="_blank" rel="noopener noreferrer" class="license-ext-link">
                      {{ license.system_id }}
                      <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                    <button
                      class="btn btn-sm btn-outline-secondary flex-shrink-0"
                      @click="copyToClipboard(license.system_id)"
                      :title="_i18n('copy')"
                    >
                      <i class="fas fa-copy"></i>
                    </button>
                  </div>
                  <div class="mt-1">
                    <small class="text-secondary" v-html="_i18n('about.licence_generation', { purchase_url: 'https://shop.ntop.org/', universities_url: 'https://www.ntop.org/support/faq/do-you-charge-universities-no-profit-and-research/' })"></small>
                  </div>
                </td>
              </tr>

              <!-- License key field -->
              <tr>
                <th>{{ _i18n('about.licence') }}</th>
                <td>
                  <!-- Admin + Windows + redis/empty license: show editable form -->
                  <div v-if="isAdmin && license.is_windows && (license.use_redis_license || !license.license_encoded)">
                    <form @submit.prevent="submitLicense">
                      <div class="mb-2">
                        <textarea
                          v-model="licenseInput"
                          class="form-control w-50 license-textarea"
                          rows="7"
                          :placeholder="_i18n('about.specify_licence')"
                        ></textarea>
                      </div>
                      <button type="submit" class="btn btn-primary btn-sm" :disabled="saving">
                        <span v-if="saving" class="spinner-border spinner-border-sm me-1" role="status"></span>
                        <i v-else class="fas fa-save me-1"></i>
                        {{ _i18n('about.save_licence') }}
                      </button>
                      <div v-if="saveResult" :class="['mt-2 small', saveResult.ok ? 'text-success' : 'text-danger']">
                        {{ saveResult.message }}
                      </div>
                    </form>
                  </div>
                  <!-- Admin + non-Windows or has file license: show read-only -->
                  <div v-else-if="isAdmin">
                    <textarea
                      v-if="license.license_encoded"
                      readonly
                      class="form-control w-50 license-textarea"
                      rows="7"
                    >{{ license.license_encoded }}</textarea>
                    <span v-else class="text-secondary">{{ _i18n('about.licence_save_path') }}</span>
                  </div>
                </td>
              </tr>

              <!-- Maintenance / expiry -->
              <tr v-if="license.license_ends_at != null && license.license_days_left != null">
                <th>{{ _i18n('about.maintenance') }}</th>
                <td>
                  <span v-if="license.license_days_left > 0"
                    v-html="_i18n('about.maintenance_left', { _until: formatEpoch(license.license_ends_at), days_left: license.license_days_left })"
                  ></span>
                  <span v-else v-html="_i18n('about.maintenance_expired_no_days_left')"></span>
                </td>
              </tr>

            </tbody>
          </table>
        </div>
      </div>

      <!-- EULA note -->
      <div class="license-note small text-secondary">
        {{ _i18n('license_page.agreement') }}:
        <a class="license-ext-link" :href="license.eula_url" target="_blank" rel="noopener noreferrer">
          EULA <i class="fas fa-external-link-alt fa-xs ms-1"></i>
        </a>
      </div>

    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as Loading } from "./loading.vue";

function _i18n(key, params) {
  let str = i18n(key);
  if (!str) return key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      str = str.replace(new RegExp(`%\\{${k}\\}`, "g"), v);
    }
  }
  return str;
}

const props = defineProps({
  context: Object,
});

const isAdmin = props.context?.is_admin ?? false;

const isLoading  = ref(true);
const license    = ref({});
const licenseInput = ref("");
const saving     = ref(false);
const saveResult = ref(null);

onMounted(async () => {
  await loadLicense();
});

async function loadLicense() {
  isLoading.value = true;
  try {
    const url  = `${http_prefix}/lua/rest/v2/get/ntopng/license.lua`;
    const data = await ntopng_utility.http_request(url);
    if (data) {
      license.value     = data;
      licenseInput.value = data.cached_license || "";
    }
  } finally {
    isLoading.value = false;
  }
}

async function submitLicense() {
  saving.value     = true;
  saveResult.value = null;
  try {
    const url = `${http_prefix}/lua/rest/v2/set/ntopng/license.lua`;
    await ntopng_utility.http_request(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ntopng_license: licenseInput.value.trim() }),
    });
    saveResult.value = { ok: true, message: i18n("saved") };
    await loadLicense();
  } catch (_) {
    saveResult.value = { ok: false, message: i18n("request_failed_message") };
  } finally {
    saving.value = false;
  }
}

function formatEpoch(epoch) {
  return new Date(epoch * 1000).toLocaleDateString();
}

async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch (_) {
    const el = document.createElement("textarea");
    el.value = text;
    el.style.cssText = "position:fixed;top:-9999px;left:-9999px;opacity:0";
    document.body.appendChild(el);
    el.select();
    try { document.execCommand("copy"); } finally { document.body.removeChild(el); }
  }
}
</script>

<style scoped>
.license-card {
  border-radius: 0.5rem;
  overflow: hidden;
  border-color: rgba(0, 0, 0, 0.1);
}

.license-card-header {
  font-weight: 600;
  font-size: 0.88rem;
  letter-spacing: 0.02em;
  border-left: 3px solid var(--ntop-orange);
  padding: 0.65rem 1rem;
}

.license-accent-icon {
  color: var(--ntop-orange);
  font-size: 0.9rem;
}

.license-table th {
  width: 20%;
  font-weight: 600;
  font-size: 0.82rem;
  vertical-align: middle;
  padding: 0.55rem 1rem;
  white-space: nowrap;
  color: var(--ntop-text-color);
}

.license-table td {
  font-size: 0.82rem;
  vertical-align: middle;
  padding: 0.55rem 1rem;
  color: var(--ntop-text-color);
}

.license-textarea {
  font-size: 0.78rem;
  font-family: monospace;
  resize: none;
}

.license-ext-link {
  color: var(--ntop-text-color);
  text-decoration: none;
  transition: color 0.15s ease;
}
.license-ext-link:hover {
  color: var(--ntop-orange);
}

.license-note {
  padding: 0.5rem 0;
}
</style>

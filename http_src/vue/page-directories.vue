<!--
  (C) 2013-26 - ntop.org
-->

<template>
  <div class="page-directories position-relative">

    <Loading :isLoading="isLoading" />

    <div v-if="!isLoading" class="dirs-card card">
      <div class="dirs-card-header card-header d-flex align-items-center gap-2">
        <i class="fas fa-folder-open dirs-accent-icon"></i>
        <span>{{ _i18n('about.directories') }}</span>
      </div>
      <div class="card-body p-0">
        <table class="dirs-table table table-bordered table-striped mb-0">
          <tbody>

            <!-- Directories group -->
            <tr>
              <th rowspan="2" class="dirs-group-header">{{ _i18n('about.directories') }}</th>
              <td>{{ _i18n('about.data_directory') }}</td>
              <td class="font-monospace">{{ dirs.working_dir }}</td>
            </tr>
            <tr>
              <td>{{ _i18n('about.scripts_directory') }}</td>
              <td class="font-monospace">{{ dirs.script_dir }}</td>
            </tr>

            <!-- Callback directories group -->
            <tr>
              <th rowspan="4" class="dirs-group-header">{{ _i18n('about.callback_directories') }}</th>
              <td>{{ _i18n('about.flow_checks_directory') }}</td>
              <td class="font-monospace">{{ (dirs.flow_checks_dirs || []).join(' ') }}</td>
            </tr>
            <tr>
              <td>{{ _i18n('about.host_checks_directory') }}</td>
              <td class="font-monospace">{{ (dirs.host_checks_dirs || []).join(' ') }}</td>
            </tr>
            <tr>
              <td>{{ _i18n('about.network_callbacks_directory') }}</td>
              <td class="font-monospace">{{ (dirs.network_checks_dirs || []).join(' ') }}</td>
            </tr>
            <tr>
              <td>{{ _i18n('about.interface_callbacks_directory') }}</td>
              <td class="font-monospace">{{ (dirs.interface_checks_dirs || []).join(' ') }}</td>
            </tr>

            <!-- Alert definition directories group -->
            <tr>
              <th rowspan="1" class="dirs-group-header">{{ _i18n('about.defs_directories') }}</th>
              <td>{{ _i18n('show_alerts.alerts') }}</td>
              <td class="font-monospace dirs-multiline">{{ (dirs.alert_defs_dirs || []).join('\n') }}</td>
            </tr>

          </tbody>
        </table>
      </div>
    </div>

  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as Loading } from "./loading.vue";

const _i18n = (t) => i18n(t);

const props = defineProps({
  context: Object,
});

const isLoading = ref(true);
const dirs      = ref({});

onMounted(async () => {
  await loadDirectories();
});

async function loadDirectories() {
  isLoading.value = true;
  try {
    const url  = `${http_prefix}/lua/rest/v2/get/ntopng/directories.lua`;
    const data = await ntopng_utility.http_request(url);
    if (data) {
      dirs.value = data;
    }
  } finally {
    isLoading.value = false;
  }
}
</script>

<style scoped>
.dirs-card {
  border-radius: 0.5rem;
  overflow: hidden;
  border-color: rgba(0, 0, 0, 0.1);
}

.dirs-card-header {
  font-weight: 600;
  font-size: 0.88rem;
  letter-spacing: 0.02em;
  border-left: 3px solid var(--ntop-orange);
  padding: 0.65rem 1rem;
}

.dirs-accent-icon {
  color: var(--ntop-orange);
  font-size: 0.9rem;
}

.dirs-table th,
.dirs-table td {
  font-size: 0.82rem;
  vertical-align: middle;
  padding: 0.55rem 1rem;
  color: var(--ntop-text-color);
}

.dirs-group-header {
  font-weight: 700;
  white-space: nowrap;
  width: 18%;
}

.dirs-multiline {
  white-space: pre-line;
}
</style>

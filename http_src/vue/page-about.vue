<!--
  (C) 2024 - ntop.org
-->

<template>
  <div class="page-about position-relative">

    <Loading :isLoading="isLoading" />

    <!-- Hero Banner -->
    <div v-if="!isLoading" class="about-hero mb-4 rounded-3 overflow-hidden">
      <div class="p-4">
        <div class="d-flex align-items-start gap-3 flex-wrap">
          <div class="flex-grow-1">
            <div class="d-flex align-items-center gap-2 flex-wrap mb-1">
              <h2 class="about-product-name mb-0">{{ info.product }}</h2>
              <span v-if="info.release" class="about-release-badge">{{ info.release }}</span>
            </div>
            <div class="d-flex align-items-center gap-3 flex-wrap">
              <span class="about-version">
                v{{ info.version }}
                <span v-if="info.revision" class="text-secondary"> rev.{{ info.revision }}</span>
                <span class="text-secondary"> ({{ info.os }})</span>
              </span>
              <a
                v-if="info.git_commit"
                :href="`https://github.com/ntop/ntopng/commit/${info.git_commit}`"
                target="_blank"
                rel="noopener noreferrer"
                class="about-git-link small"
              >
                <i class="fab fa-github me-1"></i>{{ info.git_commit.substring(0, 10) }}
              </a>
            </div>
            <div class="about-copyright mt-2 small" v-html="info.copyright"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Two-column body -->
    <div v-if="!isLoading" class="row g-4">

      <!-- Left — System Information -->
      <div class="col-12 col-lg-6">
        <div class="about-card card h-100">
          <div class="about-card-header card-header d-flex align-items-center gap-2">
            <i class="fas fa-server about-accent-icon"></i>
            <span>{{ _i18n('about.system_info') }}</span>
          </div>
          <div class="card-body p-0 position-relative">
            <table class="about-table table table-sm table-striped mb-0">
              <tbody>
                <!-- System ID — pro only -->
                <tr v-if="info.system_id">
                  <th>{{ _i18n('about.system_id') }}</th>
                  <td>
                    <div class="d-flex align-items-center gap-2 ">
                      <span class="about-sys-id text-break">{{ info.system_id }}</span>
                      <button
                        class="btn btn-sm btn-outline-secondary flex-shrink-0"
                        @click="copyToClipboard(info.system_id)"
                        :title="_i18n('copy')"
                      >
                        <i class="fas fa-copy"></i>
                      </button>
                      <a
                        :href="`${base_url}/lua/license.lua`"
                        class="btn btn-sm btn-outline-secondary flex-shrink-0"
                      >
                        <i class="fas fa-cog"></i>
                      </a>
                    </div>
                  </td>
                </tr>

                <!-- Platform -->
                <tr>
                  <th>{{ _i18n('about.platform') }}</th>
                  <td class="">
                    {{ info.platform }} — {{ info.bits }} bit
                    <span v-if="info.jemalloc" class="badge bg-secondary ms-1 small">jemalloc</span>
                  </td>
                </tr>

                <!-- Hardware model (optional) -->
                <tr v-if="info.hw_model">
                  <th>{{ _i18n('about.hw_model') }}</th>
                  <td>{{ info.hw_model }}</td>
                </tr>

                <!-- Startup line -->
                <tr>
                  <th>{{ _i18n('about.startup_line') }}</th>
                  <td class=" small text-break about-cmd">
                    {{ info.product }} {{ info.command_line }}
                  </td>
                </tr>

                <!-- Timezone -->
                <tr>
                  <th>{{ _i18n('about.timezone') }}</th>
                  <td>{{ info.zoneinfo }}</td>
                </tr>

                <!-- Hash sizes -->
                <tr>
                  <th>{{ _i18n('about.hosts_hash_size') }}</th>
                  <td class="">{{ info.max_num_hosts }}</td>
                </tr>
                <tr>
                  <th>{{ _i18n('about.flows_hash_size') }}</th>
                  <td class="">{{ info.max_num_flows }}</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Right — Component Versions -->
      <div class="col-12 col-lg-6">
        <div class="about-card card h-100">
          <div class="about-card-header card-header d-flex align-items-center gap-2">
            <i class="fas fa-puzzle-piece about-accent-icon"></i>
            <span>{{ _i18n('about.component_versions') }}</span>
          </div>
          <div class="card-body p-0">
            <table class="about-table table table-sm table-striped mb-0">
              <tbody>

                <!-- nDPI -->
                <tr v-if="info.ndpi">
                  <th>
                    <a class="about-ext-link" href="http://www.ntop.org/products/ndpi/" target="_blank" rel="noopener noreferrer">
                      nDPI <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">
                    <a
                      class="about-ext-link"
                      :href="info.ndpi.commit ? `https://github.com/ntop/nDPI/commit/${info.ndpi.commit}` : 'https://github.com/ntop/nDPI/'"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      {{ info.ndpi.version }}<span v-if="info.ndpi.date"> ({{ info.ndpi.date }})</span>
                    </a>
                  </td>
                </tr>

                <!-- Redis -->
                <tr v-if="info.version_redis">
                  <th>
                    <a class="about-ext-link" href="http://www.redis.io" target="_blank" rel="noopener noreferrer">
                      Redis <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">{{ info.version_redis }}</td>
                </tr>

                <!-- InfluxDB (async loaded) -->
                <tr v-if="info.ts_driver === 'influxdb'">
                  <th>
                    <a class="about-ext-link" href="http://www.influxdata.com" target="_blank" rel="noopener noreferrer">
                      InfluxDB <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">
                    <span v-if="influxLoading" class="d-flex align-items-center gap-2 text-secondary">
                      <span class="spinner-border spinner-border-sm" role="status"></span>
                      <span class="small">{{ _i18n('loading') }}</span>
                    </span>
                    <span v-else-if="influxVersion">{{ influxVersion }}</span>
                    <span v-else class="text-secondary">—</span>
                  </td>
                </tr>

                <!-- cURL -->
                <tr v-if="info.version_curl">
                  <th>
                    <a class="about-ext-link" href="https://curl.haxx.se" target="_blank" rel="noopener noreferrer">
                      cURL <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">{{ info.version_curl }}</td>
                </tr>

                <!-- Mongoose -->
                <tr v-if="info.version_httpd">
                  <th>
                    <a class="about-ext-link" href="https://github.com/valenok/mongoose" target="_blank" rel="noopener noreferrer">
                      Mongoose <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">{{ info.version_httpd }}</td>
                </tr>

                <!-- Lua -->
                <tr v-if="info.version_lua">
                  <th>
                    <a class="about-ext-link" href="http://www.lua.org" target="_blank" rel="noopener noreferrer">
                      Lua <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">{{ info.version_lua }}</td>
                </tr>

                <!-- RRDtool -->
                <tr v-if="info.version_rrd">
                  <th>
                    <a class="about-ext-link" href="http://www.rrdtool.org/" target="_blank" rel="noopener noreferrer">
                      RRDtool <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">{{ info.version_rrd }}</td>
                </tr>

                <!-- ØMQ -->
                <tr v-if="info.version_zmq">
                  <th>
                    <a class="about-ext-link" href="http://www.zeromq.org" target="_blank" rel="noopener noreferrer">
                      ØMQ <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">{{ info.version_zmq }}</td>
                </tr>

                <!-- GeoLite -->
                <tr v-if="info.version_geoip">
                  <th>
                    <a class="about-ext-link" href="http://www.maxmind.com" target="_blank" rel="noopener noreferrer">
                      GeoLite <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">
                    {{ info.version_geoip }}
                    <div class="about-maxmind-note small mt-1" v-html="_i18n('about.maxmind', {maxmind_url: 'http://www.maxmind.com/'})"></div>
                  </td>
                </tr>

                <!-- nIndex -->
                <tr v-if="info.version_nindex">
                  <th>ntop nIndex</th>
                  <td class="">{{ info.version_nindex }}</td>
                </tr>

                <!-- Bootstrap -->
                <tr>
                  <th>
                    <a class="about-ext-link" href="https://getbootstrap.com" target="_blank" rel="noopener noreferrer">
                      <i class="fab fa-bootstrap me-1"></i>Bootstrap <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">5.0</td>
                </tr>

                <!-- Font Awesome -->
                <tr>
                  <th>
                    <a class="about-ext-link" href="https://github.com/FortAwesome/Font-Awesome" target="_blank" rel="noopener noreferrer">
                      <i class="fab fa-font-awesome me-1"></i>Font Awesome <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">5.11.2</td>
                </tr>

                <!-- d3.js -->
                <tr>
                  <th>
                    <a class="about-ext-link" href="http://d3js.org" target="_blank" rel="noopener noreferrer">
                      d3.js <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                    </a>
                  </th>
                  <td class="">2.9.1 / 3.0</td>
                </tr>

              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as Loading } from "./loading.vue";

const _i18n = (t) => i18n(t);
const base_url = http_prefix;

const props = defineProps({
  context: Object,
});

const isLoading    = ref(true);
const info         = ref({});
const influxLoading = ref(false);
const influxVersion = ref(null);

onMounted(async () => {
  await loadAboutInfo();
});

async function loadAboutInfo() {
  isLoading.value = true;
  try {
    const url  = `${http_prefix}/lua/rest/v2/get/ntopng/about.lua`;
    const data = await ntopng_utility.http_request(url);
    if (data) {
      info.value = data;
      if (data.ts_driver === "influxdb") {
        loadInfluxdbInfo(); // fire-and-forget; don't block render
      }
    }
  } finally {
    isLoading.value = false;
  }
}

async function loadInfluxdbInfo() {
  influxLoading.value = true;
  try {
    const url  = `${http_prefix}/lua/rest/v2/get/system/health/influxdb.lua`;
    const data = await ntopng_utility.http_request(url);
    if (data && data.version) {
      influxVersion.value = data.version;
    }
  } finally {
    influxLoading.value = false;
  }
}

async function copyToClipboard(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch (_) {
    /* clipboard API unavailable in older browsers — silently ignore */
    // Fallback for HTTPS
    const el = document.createElement("textarea");
    el.value = text;
    el.style.cssText = "position:fixed;top:-9999px;left:-9999px;opacity:0";
    document.body.appendChild(el);
    el.select();
    try {
      document.execCommand("copy");
    } finally {
      document.body.removeChild(el);
    }
  }

}
</script>

<style scoped>
/* ── Hero banner ──────────────────────────────────────────── */
.about-hero {
  background: linear-gradient(135deg, var(--ntop-blue-dark) 0%, var(--ntop-blue) 100%);
  color: #fff;
  border: none;
}

.about-product-name {
  font-size: 1.6rem;
  font-weight: 700;
  color: #fff;
  letter-spacing: -0.01em;
}

.about-release-badge {
  display: inline-block;
  background: var(--ntop-orange);
  color: #fff;
  font-size: 0.68rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  padding: 0.2em 0.65em;
  border-radius: 999px;
  line-height: 1.6;
}

.about-version {
  color: rgba(255, 255, 255, 0.82);
  font-size: 0.88rem;
}

.about-git-link {
  color: rgba(255, 255, 255, 0.55) !important;
  text-decoration: none;
  transition: color 0.15s ease;
}
.about-git-link:hover { color: rgba(255, 255, 255, 0.9) !important; }

.about-copyright {
  color: rgba(255, 255, 255, 0.5);
}

/* ── Section cards ────────────────────────────────────────── */
.about-card {
  border-radius: 0.5rem;
  overflow: hidden;
  border-color: rgba(0, 0, 0, 0.1);
}

.about-card-header {
  font-weight: 600;
  font-size: 0.88rem;
  letter-spacing: 0.02em;
  border-left: 3px solid var(--ntop-orange);
  padding: 0.65rem 1rem;
}

.about-accent-icon {
  color: var(--ntop-orange);
  font-size: 0.9rem;
}

/* ── Info table ───────────────────────────────────────────── */
.about-table th {
  width: 42%;
  font-weight: 600;
  font-size: 0.82rem;
  vertical-align: middle;
  padding: 0.55rem 1rem;
  white-space: nowrap;
  color: var(--ntop-text-color);
}

.about-table td {
  font-size: 0.82rem;
  vertical-align: middle;
  padding: 0.55rem 1rem;
  word-break: break-word;
  color: var(--ntop-text-color);
}

.about-cmd {
  opacity: 0.8;
}

.about-sys-id {
  font-size: 0.78rem;
}

/* ── External links ───────────────────────────────────────── */
.about-ext-link {
  color: var(--ntop-text-color);
  text-decoration: none;
  transition: color 0.15s ease;
}
.about-ext-link:hover {
  color: var(--ntop-orange);
  text-decoration: none;
}

/* ── MaxMind attribution note ─────────────────────────────── */
.about-maxmind-note {
  opacity: 0.7;
  line-height: 1.4;
}
</style>

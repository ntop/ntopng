<!--
  (C) 2013-26 - ntop.org
  Flow Details — Vue3 rewrite of scripts/lua/flow_details.lua (overview tab)
-->
<template>
  <div class="flow-page">

    <!-- Flow Not Found or Purged -->
    <div v-if="flow_purged" class="alert alert-warning d-flex align-items-center gap-2 mb-3">
      <i class="fas fa-exclamation-triangle"></i>
      {{ _i18n('flow_details.now_purged') }}
    </div>
    <div v-if="!flow" class="alert alert-danger d-flex align-items-center gap-2">
      <i class="fas fa-exclamation-triangle"></i>
      {{ _i18n('flow_details.flow_cannot_be_found_message') }}
    </div>

    <template v-if="flow">

      <!-- HERO BANNER-->
      <div class="flow-hero mb-4 rounded-3 overflow-hidden">
        <div class="p-4">

          <!-- Endpoint row -->
          <div class="d-flex align-items-center flex-wrap gap-3 mb-3">

            <!-- Client -->
            <div class="flow-endpoint-block">
              <a :href="`${http_prefix}/lua/host_details.lua?host=${flow['cli.ip']}`"
                 class="flow-hero-host text-decoration-none">
                {{ flow['cli.ip'] }}
              </a>
              <span class="flow-hero-port">:{{ flow['cli.port'] }}</span>
            </div>

            <!-- Protocol badges + arrow -->
            <div class="d-flex flex-column align-items-center gap-1">
              <div class="d-flex gap-1 flex-wrap justify-content-center">
                <span class="flow-proto-badge" :class="l4BadgeClass">{{ flow['proto.l4'] }}</span>
                <a v-if="flow['proto.ndpi_id'] !== -1"
                   :href="`${http_prefix}/lua/flows_stats.lua?application=${flow['proto.ndpi_id']}`"
                   class="flow-proto-badge flow-proto-app text-decoration-none">
                  {{ flow['proto.ndpi'] }}
                </a>
                <span v-else class="flow-proto-badge flow-proto-app">{{ flow['proto.ndpi'] }}</span>
                <span v-if="tlsVersionName"
                      class="flow-proto-badge"
                      :class="isOldTls ? 'flow-proto-warn' : 'flow-proto-secondary'">
                  {{ tlsVersionName }}
                  <i v-if="isOldTls" class="fas fa-exclamation-triangle ms-1"></i>
                </span>
              </div>
              <i class="fas fa-long-arrow-alt-right flow-arrow-icon"></i>
            </div>

            <!-- Server -->
            <div class="flow-endpoint-block">
              <a :href="`${http_prefix}/lua/host_details.lua?host=${flow['srv.ip']}`"
                 class="flow-hero-host text-decoration-none">
                {{ flow['srv.ip'] }}
              </a>
              <span class="flow-hero-port">:{{ flow['srv.port'] }}</span>
            </div>

            <!-- Right side: verdict + score + drop button -->
            <div class="ms-auto d-flex align-items-center gap-2 flex-wrap">
              <span v-if="!flow['verdict.pass']" class="flow-verdict-badge flow-verdict-blocked">
                <i class="fas fa-ban me-1"></i>{{ _i18n('blocked') }}
              </span>
              <span class="flow-score-pill" :class="scorePillClass">
                <i class="fas fa-shield-alt me-1"></i>
                {{ _i18n('score') }}: <b>{{ flow.score?.flow_score ?? 0 }}</b>
                <span v-if="(flow.score?.flow_score ?? 0) > 0" class="ms-1">— {{ scoreSeverityLabel }}</span>
              </span>
              <form v-if="ctx.is_inline && flow['verdict.pass'] && ctx.is_admin"
                    method="post" class="d-inline">
                <input type="hidden" name="drop_flow_policy" value="true">
                <input type="hidden" name="csrf" :value="ctx.csrf">
                <button type="submit" class="btn btn-sm btn-light text-danger border">
                  <i class="fas fa-ban me-1"></i>{{ _i18n('flow_details.drop_flow_traffic_btn') }}
                </button>
              </form>
            </div>
          </div>

          <!-- Status badges row -->
          <div class="d-flex flex-wrap gap-2 mb-3">
            <span v-if="flow.vlan > 0" class="flow-status-badge">VLAN {{ flow.vlan }}</span>
            <span v-if="flow.periodic_flow" class="flow-status-badge">
              <i class="fas fa-sync-alt me-1"></i>{{ _i18n('periodic_flow') }}
            </span>
            <span v-if="flow.flow_swapped" class="flow-status-badge">
              <i class="fa-solid fa-repeat me-1"></i>{{ _i18n('swapped_flow') }}
            </span>
            <span v-if="flow['flow.idle']" class="flow-status-badge">
              <i class="fas fa-clock me-1"></i>idle
            </span>
            <span v-if="flowSource" class="flow-status-badge">{{ flowSource }}</span>
            <span v-if="flow['proto.ndpi_cat']" class="flow-status-badge">
              <a :href="`${http_prefix}/lua/flows_stats.lua?category=${flow['proto.ndpi_cat']}`"
                 class="text-decoration-none" style="color: inherit;">
                {{ flow['proto.ndpi_cat'] }}
              </a>
            </span>
          </div>

          <!-- Key metrics row -->
          <div class="flow-hero-metrics d-flex flex-wrap gap-4">
            <span>
              <span class="flow-metric-label">{{ _i18n('details.total_traffic') }}</span>
              <span class="flow-metric-value">{{ bytesVol(liveBytes) }}</span>
            </span>
            <span>
              <span class="flow-metric-label">{{ _i18n('throughput') }}</span>
              <span class="flow-metric-value">{{ liveData.throughput || '—' }}</span>
            </span>
            <span>
              <span class="flow-metric-label">{{ _i18n('details.duration') }}</span>
              <span class="flow-metric-value">{{ liveData.seen_duration || durationStr }}</span>
            </span>
            <span>
              <span class="flow-metric-label">{{ _i18n('packets') }}</span>
              <span class="flow-metric-value">{{ fmtNum(totalPackets) }}</span>
            </span>
            <span>
              <span class="flow-metric-label">{{ _i18n('details.first_last_seen') }}</span>
              <span class="flow-metric-value">
                {{ liveData.seen_first || fmtEpoch(flow['seen.first']) }}
              </span>
            </span>
          </div>

        </div>
      </div>

      <!-- ROW 1 — Flow Identity  |  Traffic -->
      <div class="row g-4 mb-4">

        <!-- Flow Identity -->
        <div class="col-12 col-lg-6">
          <div class="flow-card card h-100">
            <div class="flow-card-header card-header d-flex align-items-center gap-2">
              <i class="fas fa-fingerprint flow-accent-icon"></i>
              <span>Flow Identity</span>
            </div>
            <div class="card-body p-0">
              <table class="flow-table table table-sm table-striped mb-0">
                <tbody>

                  <tr>
                    <th>{{ _i18n('protocol') }} / {{ _i18n('application') }}</th>
                    <td>
                      {{ flow['proto.l4'] }}
                      <span class="text-muted mx-1">/</span>
                      <a v-if="flow['proto.ndpi_id'] !== -1"
                         :href="`${http_prefix}/lua/flows_stats.lua?application=${flow['proto.ndpi_id']}`">
                        {{ flow['proto.ndpi'] }}
                      </a>
                      <span v-else>{{ flow['proto.ndpi'] }}</span>
                      <span v-if="flow['proto.ndpi_breed']" class="text-muted small ms-1">
                        ({{ flow['proto.ndpi_breed'] }})
                      </span>
                    </td>
                  </tr>

                  <tr v-if="flow['proto.ndpi_confidence'] && flow['proto.ndpi_confidence'] !== 'Unknown'">
                    <th>{{ _i18n('ndpi_confidence') }}</th>
                    <td>
                      <span class="badge" :class="confidenceBadgeClass">
                        {{ flow['proto.ndpi_confidence'] }}
                      </span>
                    </td>
                  </tr>

                  <tr v-if="ctx.has_vlan && flow.vlan > 0">
                    <th>{{ _i18n('details.vlan_id') }}</th>
                    <td>{{ flow.vlan }}</td>
                  </tr>

                  <tr v-if="flow.vrfId != null">
                    <th>
                      <a href="https://en.wikipedia.org/wiki/Virtual_routing_and_forwarding"
                         target="_blank" class="flow-ext-link">VRF ID</a>
                    </th>
                    <td>{{ flow.vrfId }}</td>
                  </tr>

                  <tr v-if="!flow['verdict.pass'] && flow['verdict.reason']">
                    <th class="text-danger">{{ _i18n('flow_details.drop_reason') }}</th>
                    <td class="text-danger">{{ flow['verdict.reason'] }}</td>
                  </tr>

                  <tr v-if="flow.observation_point_id">
                    <th>{{ _i18n('flow_details.observation_point') }}</th>
                    <td>{{ flow.observation_point_id }}</td>
                  </tr>

                  <tr v-if="flow.tcp_fingerprint">
                    <th>{{ _i18n('details.tcp_fingerprint') }}</th>
                    <td>
                      <div class="d-flex align-items-center gap-2">
                        <code class="flow-code text-break">{{ flow.tcp_fingerprint }}</code>
                        <button class="btn btn-sm btn-outline-secondary flex-shrink-0"
                                @click="copyText(flow.tcp_fingerprint)" title="Copy">
                          <i class="fas fa-copy"></i>
                        </button>
                      </div>
                    </td>
                  </tr>

                  <tr v-if="flow.ndpi_fingerprint">
                    <th>{{ _i18n('details.ndpi_fingerprint') }}</th>
                    <td>
                      <div class="d-flex align-items-center gap-2">
                        <code class="flow-code text-break">{{ flow.ndpi_fingerprint }}</code>
                        <button class="btn btn-sm btn-outline-secondary flex-shrink-0"
                                @click="copyText(flow.ndpi_fingerprint)" title="Copy">
                          <i class="fas fa-copy"></i>
                        </button>
                      </div>
                    </td>
                  </tr>

                  <tr v-if="flow['protos.tls.ja4.client_hash']">
                    <th>
                      <a href="https://github.com/FoxIO-LLC/ja4" target="_blank" class="flow-ext-link">
                        JA4 <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                      </a>
                    </th>
                    <td>
                      <div class="d-flex align-items-center gap-2">
                        <span v-if="flow['protos.tls.ja4.client_malicious']"
                              class="text-danger"
                              :title="_i18n('alerts_dashboard.malicious_signature_detected')">
                          <i class="fas fa-ban"></i>
                        </span>
                        <code class="flow-code text-break">{{ flow['protos.tls.ja4.client_hash'] }}</code>
                        <button class="btn btn-sm btn-outline-secondary flex-shrink-0"
                                @click="copyText(flow['protos.tls.ja4.client_hash'])" title="Copy">
                          <i class="fas fa-copy"></i>
                        </button>
                      </div>
                    </td>
                  </tr>

                  <tr v-if="flow.community_id">
                    <th>Community ID</th>
                    <td>
                      <div class="d-flex align-items-center gap-2">
                        <code class="flow-code text-break">{{ flow.community_id }}</code>
                        <button class="btn btn-sm btn-outline-secondary flex-shrink-0"
                                @click="copyText(flow.community_id)" title="Copy">
                          <i class="fas fa-copy"></i>
                        </button>
                      </div>
                    </td>
                  </tr>

                  <tr v-if="flow['entropy.cli2srv'] != null">
                    <th>{{ _i18n('flow_details.entropy') }}</th>
                    <td>
                      <span class="me-2">→ {{ parseFloat(flow['entropy.cli2srv']).toFixed(2) }}</span>
                      <span>← {{ parseFloat(flow['entropy.srv2cli']).toFixed(2) }}</span>
                    </td>
                  </tr>

                  <tr v-if="flow['dhcp.fingerprint']">
                    <th>DHCP Fingerprint</th>
                    <td><code class="flow-code">{{ flow['dhcp.fingerprint'] }}</code></td>
                  </tr>

                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Traffic -->
        <div class="col-12 col-lg-6">
          <div class="flow-card card h-100">
            <div class="flow-card-header card-header d-flex align-items-center gap-2">
              <i class="fas fa-exchange-alt flow-accent-icon"></i>
              <span>Traffic</span>
              <span v-if="liveData.avg_throughput" class="ms-auto small text-muted">
                ø {{ liveData.avg_throughput }}
              </span>
            </div>
            <div class="card-body">

              <!-- Direction bar -->
              <div class="mb-3">
                <div class="d-flex justify-content-between small mb-1" style="color: var(--ntop-muted-text-color);">
                  <span>
                    <i class="fas fa-arrow-right me-1 flow-cli-color"></i>
                    {{ flow['cli.ip'] }}:{{ flow['cli.port'] }}
                  </span>
                  <span class="text-end">
                    {{ flow['srv.ip'] }}:{{ flow['srv.port'] }}
                    <i class="fas fa-arrow-left ms-1 flow-srv-color"></i>
                  </span>
                </div>
                <div class="progress flow-dir-bar">
                  <div class="progress-bar flow-bar-cli"
                       :style="{ width: cli2srvPct + '%' }"></div>
                  <div class="progress-bar flow-bar-srv"
                       :style="{ width: (100 - cli2srvPct) + '%' }"></div>
                </div>
              </div>

              <!-- Traffic table -->
              <table class="flow-table table table-sm table-striped mb-0">
                <tbody>

                  <tr>
                    <th>Client → Server</th>
                    <td>
                      {{ bytesVol(liveData['cli2srv.bytes'] ?? flow['cli2srv.bytes']) }}
                      <span class="text-muted small ms-1">
                        ({{ fmtNum(liveData['cli2srv.packets'] ?? flow['cli2srv.packets']) }} pkts)
                      </span>
                      <span v-if="liveData.trend_cli2srv === 'up'" class="text-success ms-1">
                        <i class="fas fa-arrow-up fa-xs"></i>
                      </span>
                    </td>
                  </tr>

                  <tr>
                    <th>Server → Client</th>
                    <td>
                      {{ bytesVol(liveData['srv2cli.bytes'] ?? flow['srv2cli.bytes']) }}
                      <span class="text-muted small ms-1">
                        ({{ fmtNum(liveData['srv2cli.packets'] ?? flow['srv2cli.packets']) }} pkts)
                      </span>
                      <span v-if="liveData.trend_srv2cli === 'up'" class="text-success ms-1">
                        <i class="fas fa-arrow-up fa-xs"></i>
                      </span>
                    </td>
                  </tr>

                  <tr v-if="(liveData.goodput_bytes ?? flow['goodput_bytes']) > 0">
                    <th>
                      <a href="https://en.wikipedia.org/wiki/Goodput" target="_blank"
                         class="flow-ext-link">
                        {{ _i18n('details.goodput') }}
                        <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                      </a>
                    </th>
                    <td>
                      {{ bytesVol(liveData.goodput_bytes ?? flow['goodput_bytes']) }}
                      <span class="badge ms-1" :class="goodputBadgeClass">{{ goodputPct }}%</span>
                    </td>
                  </tr>

                  <tr v-if="flow.num_flow_processed_pkts">
                    <th>{{ _i18n('details.num_processed_pkts') }}</th>
                    <td>
                      {{ fmtNum(flow.num_flow_processed_pkts) }}
                      <span v-if="flow.num_flow_marker_pkts" class="text-muted small ms-1">
                        [Marker: {{ fmtNum(flow.num_flow_marker_pkts) }}]
                      </span>
                    </td>
                  </tr>

                  <!-- TCP health (only for TCP) -->
                  <template v-if="isTcp">
                    <tr v-if="tcpRetr > 0">
                      <th>Retransmissions</th>
                      <td>
                        <span class="text-danger">{{ fmtNum(liveData.c2sretr ?? flow['cli2srv.retransmissions'] ?? 0) }}</span>
                        <span class="text-muted mx-1">/</span>
                        <span class="text-danger">{{ fmtNum(liveData.s2cretr ?? flow['srv2cli.retransmissions'] ?? 0) }}</span>
                        <span class="text-muted small ms-1">(cli/srv)</span>
                      </td>
                    </tr>
                    <tr v-if="tcpOOO > 0">
                      <th>Out-of-Order</th>
                      <td>
                        <span class="text-warning">{{ fmtNum(liveData.c2sOOO ?? flow['cli2srv.out_of_order'] ?? 0) }}</span>
                        <span class="text-muted mx-1">/</span>
                        <span class="text-warning">{{ fmtNum(liveData.s2cOOO ?? flow['srv2cli.out_of_order'] ?? 0) }}</span>
                        <span class="text-muted small ms-1">(cli/srv)</span>
                      </td>
                    </tr>
                    <tr v-if="tcpLost > 0">
                      <th>{{ _i18n('details.tcp_lost') }}</th>
                      <td>
                        <span class="text-danger">{{ fmtNum(liveData.c2slost ?? flow['cli2srv.lost'] ?? 0) }}</span>
                        <span class="text-muted mx-1">/</span>
                        <span class="text-danger">{{ fmtNum(liveData.s2clost ?? flow['srv2cli.lost'] ?? 0) }}</span>
                        <span class="text-muted small ms-1">(cli/srv)</span>
                      </td>
                    </tr>
                    <tr v-if="tcpMaxThpt > 0">
                      <th>
                        <a href="https://en.wikipedia.org/wiki/TCP_tuning" target="_blank"
                           class="flow-ext-link">
                          Max TCP Throughput
                          <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                        </a>
                      </th>
                      <td>
                        {{ fmtBits(flow['tcp.max_thpt.cli2srv']) }}
                        <span class="text-muted mx-1">/</span>
                        {{ fmtBits(flow['tcp.max_thpt.srv2cli']) }}
                        <span class="text-muted small ms-1">(cli/srv)</span>
                      </td>
                    </tr>
                    <tr v-if="(flow['cli2srv.fragments'] + flow['srv2cli.fragments']) > 0">
                      <th>{{ _i18n('details.fragments') }}</th>
                      <td>
                        {{ fmtNum(flow['cli2srv.fragments']) }}
                        <span class="text-muted mx-1">/</span>
                        {{ fmtNum(flow['srv2cli.fragments']) }}
                        <span class="text-muted small ms-1">(cli/srv)</span>
                      </td>
                    </tr>
                  </template>

                  <!-- ICMP -->
                  <tr v-if="isIcmp && flow['icmp.type'] != null">
                    <th>ICMP Type / Code</th>
                    <td>{{ flow['icmp.type'] }} / {{ flow['icmp.code'] }}</td>
                  </tr>

                </tbody>
              </table>
            </div>
          </div>
        </div>

      </div><!-- /row 1 -->

      <!-- ROW 2 — Application Data /  Security -->
      <div class="row g-4 mb-4">

        <!-- Application Data (show only if any data is present) -->
        <div v-if="hasAnyAppData" class="col-12 col-lg-6">
          <div class="flow-card card h-100">
            <div class="flow-card-header card-header d-flex align-items-center gap-2">
              <i class="fas fa-layer-group flow-accent-icon"></i>
              <span>Application Data</span>
            </div>
            <div class="card-body p-0">
              <table class="flow-table table table-sm table-striped mb-0">
                <tbody>

                  <!-- TLS -->
                  <template v-if="hasTls">
                    <tr>
                      <th colspan="2" class="flow-section-divider">
                        <i class="fas fa-lock me-1 flow-accent-icon"></i> TLS / SSL
                        <span v-if="tlsVersionName" class="badge ms-2"
                              :class="isOldTls ? 'bg-warning text-dark' : 'bg-success'">
                          {{ tlsVersionName }}
                        </span>
                        <span v-if="isOldTls" class="text-warning ms-2 small">
                          <i class="fas fa-exclamation-triangle me-1"></i>
                          {{ _i18n('flow_details.tls_old_protocol_version') }}
                        </span>
                      </th>
                    </tr>
                    <tr v-if="flow['protos.tls.client_requested_server_name']">
                      <th>{{ _i18n('flow_details.tls_certificate') }}</th>
                      <td>
                        <a :href="`https://${flow['protos.tls.client_requested_server_name']}`"
                           target="_blank" class="flow-ext-link">
                          {{ flow['protos.tls.client_requested_server_name'] }}
                        </a>
                      </td>
                    </tr>
                    <tr v-if="flow['protos.tls.server_names']">
                      <th>{{ _i18n('flow_details.tls_server_names') }}</th>
                      <td class="small">{{ flow['protos.tls.server_names'] }}</td>
                    </tr>
                    <tr v-if="flow['protos.tls.notBefore'] || flow['protos.tls.notAfter']">
                      <th>Validity</th>
                      <td>
                        <span v-if="isTlsExpiredOrFuture" class="text-warning me-1">
                          <i class="fas fa-exclamation-triangle"></i>
                        </span>
                        {{ fmtEpoch(flow['protos.tls.notBefore']) }} — {{ fmtEpoch(flow['protos.tls.notAfter']) }}
                      </td>
                    </tr>
                    <tr v-if="flow['protos.tls.issuerDN']">
                      <th>Issuer DN</th>
                      <td><code class="flow-code text-break">{{ flow['protos.tls.issuerDN'] }}</code></td>
                    </tr>
                    <tr v-if="flow['protos.tls.subjectDN']">
                      <th>Subject DN</th>
                      <td><code class="flow-code text-break">{{ flow['protos.tls.subjectDN'] }}</code></td>
                    </tr>
                    <tr v-if="flow['protos.tls.client_alpn']">
                      <th>
                        <a href="https://en.wikipedia.org/wiki/Application-Layer_Protocol_Negotiation"
                           target="_blank" class="flow-ext-link">
                          TLS ALPN <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                        </a>
                      </th>
                      <td>{{ flow['protos.tls.client_alpn'] }}</td>
                    </tr>
                    <tr v-if="flow['protos.tls.client_tls_supported_versions']">
                      <th>Supported Versions</th>
                      <td>{{ flow['protos.tls.client_tls_supported_versions'] }}</td>
                    </tr>
                  </template>

                  <!-- HTTP -->
                  <template v-if="hasHttp">
                    <tr>
                      <th colspan="2" class="flow-section-divider">
                        <i class="fas fa-globe me-1 flow-accent-icon"></i> HTTP
                      </th>
                    </tr>
                    <tr v-if="flow['protos.http.last_method']">
                      <th>Method</th>
                      <td>
                        <span class="badge" :class="httpMethodBadge(flow['protos.http.last_method'])">
                          {{ flow['protos.http.last_method'] }}
                        </span>
                      </td>
                    </tr>
                    <tr v-if="flow['protos.http.last_url']">
                      <th>URL</th>
                      <td>
                        <a :href="flow['protos.http.last_url']" target="_blank"
                           class="flow-ext-link text-break small">
                          {{ flow['protos.http.last_url'] }}
                        </a>
                      </td>
                    </tr>
                    <tr v-if="flow['host_server_name']">
                      <th>Server Name</th>
                      <td>{{ flow['host_server_name'] }}</td>
                    </tr>
                    <tr v-if="flow['protos.http.last_user_agent']">
                      <th>User-Agent</th>
                      <td><code class="flow-code text-break">{{ flow['protos.http.last_user_agent'] }}</code></td>
                    </tr>
                    <tr v-if="flow['protos.http.last_server']">
                      <th>Server</th>
                      <td>{{ flow['protos.http.last_server'] }}</td>
                    </tr>
                    <tr v-if="flow['protos.http.last_return_code'] && flow['protos.http.last_return_code'] !== 0">
                      <th>Status Code</th>
                      <td>
                        <span class="badge" :class="httpCodeBadge(flow['protos.http.last_return_code'])">
                          {{ flow['protos.http.last_return_code'] }}
                        </span>
                      </td>
                    </tr>
                  </template>

                  <!-- DNS -->
                  <template v-if="hasDns">
                    <tr>
                      <th colspan="2" class="flow-section-divider">
                        <i class="fas fa-server me-1 flow-accent-icon"></i> DNS
                      </th>
                    </tr>
                    <tr v-if="flow['protos.dns.last_query']">
                      <th>Query</th>
                      <td><code class="flow-code">{{ flow['protos.dns.last_query'] }}</code></td>
                    </tr>
                    <tr v-if="flow['protos.dns.last_query_type']">
                      <th>Type</th>
                      <td>{{ flow['protos.dns.last_query_type'] }}</td>
                    </tr>
                    <tr v-if="flow['protos.dns.last_return_code']">
                      <th>Response</th>
                      <td>{{ flow['protos.dns.last_return_code'] }}</td>
                    </tr>
                  </template>

                  <!-- SSH -->
                  <template v-if="hasSsh">
                    <tr>
                      <th colspan="2" class="flow-section-divider">
                        <i class="fas fa-terminal me-1 flow-accent-icon"></i> SSH
                      </th>
                    </tr>
                    <tr v-if="flow['protos.ssh.hassh.client_hash']">
                      <th>HASSH Client</th>
                      <td>
                        <div class="d-flex align-items-center gap-2">
                          <code class="flow-code text-break">{{ flow['protos.ssh.hassh.client_hash'] }}</code>
                          <button class="btn btn-sm btn-outline-secondary flex-shrink-0"
                                  @click="copyText(flow['protos.ssh.hassh.client_hash'])">
                            <i class="fas fa-copy"></i>
                          </button>
                        </div>
                      </td>
                    </tr>
                    <tr v-if="flow['protos.ssh.hassh.server_hash']">
                      <th>HASSH Server</th>
                      <td>
                        <div class="d-flex align-items-center gap-2">
                          <code class="flow-code text-break">{{ flow['protos.ssh.hassh.server_hash'] }}</code>
                          <button class="btn btn-sm btn-outline-secondary flex-shrink-0"
                                  @click="copyText(flow['protos.ssh.hassh.server_hash'])">
                            <i class="fas fa-copy"></i>
                          </button>
                        </div>
                      </td>
                    </tr>
                    <tr v-if="flow['protos.ssh.client_signature']">
                      <th>Client Sig.</th>
                      <td><code class="flow-code small">{{ flow['protos.ssh.client_signature'] }}</code></td>
                    </tr>
                    <tr v-if="flow['protos.ssh.server_signature']">
                      <th>Server Sig.</th>
                      <td><code class="flow-code small">{{ flow['protos.ssh.server_signature'] }}</code></td>
                    </tr>
                  </template>

                  <!-- SMTP -->
                  <template v-if="flow['protos.smtp.mail_from'] || flow['protos.smtp.mail_to']">
                    <tr>
                      <th colspan="2" class="flow-section-divider">
                        <i class="fas fa-envelope me-1 flow-accent-icon"></i> SMTP
                      </th>
                    </tr>
                    <tr v-if="flow['protos.smtp.mail_from']">
                      <th>Mail From</th>
                      <td>{{ flow['protos.smtp.mail_from'] }}</td>
                    </tr>
                    <tr v-if="flow['protos.smtp.mail_to']">
                      <th>Mail To</th>
                      <td>{{ flow['protos.smtp.mail_to'] }}</td>
                    </tr>
                  </template>

                  <!-- BitTorrent -->
                  <tr v-if="flow.bittorrent_hash">
                    <th>
                      <i class="fas fa-magnet me-1 flow-accent-icon"></i> BitTorrent
                    </th>
                    <td>
                      <a :href="`https://www.google.com/search?q=${flow.bittorrent_hash}`"
                         target="_blank" class="flow-ext-link">
                        {{ flow.bittorrent_hash }}
                      </a>
                    </td>
                  </tr>

                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Security -->
        <div :class="hasAnyAppData ? 'col-12 col-lg-6' : 'col-12'">
          <div class="flow-card card h-100">
            <div class="flow-card-header card-header d-flex align-items-center gap-2">
              <i class="fas fa-shield-alt flow-accent-icon"></i>
              <span>{{ _i18n('security') }}</span>
              <span v-if="alerts.length > 0" class="badge rounded-pill bg-danger ms-1">
                {{ alerts.length }}
              </span>
              <span v-else-if="!hasScore" class="badge rounded-pill bg-success ms-1">Clean</span>
            </div>
            <div class="card-body p-0">

              <!-- Clean state -->
              <div v-if="!hasScore && alerts.length === 0" class="text-center py-4">
                <i class="fas fa-check-circle fa-2x text-success mb-2 d-block"></i>
                <div class="small text-muted">No security issues detected</div>
              </div>

              <table v-else class="flow-table table table-sm table-striped mb-0">
                <tbody>

                  <!-- Score -->
                  <template v-if="hasScore">
                    <tr>
                      <th>{{ _i18n('flow_details.flow_score') }}</th>
                      <td>
                        <span class="fw-bold" :class="scoreValueClass">
                          {{ flow.score.flow_score }}
                        </span>
                        <span class="text-muted small ms-2">— {{ scoreSeverityLabel }}</span>
                      </td>
                    </tr>
                    <tr>
                      <th>{{ _i18n('flow_details.flow_score_breakdown') }}</th>
                      <td>
                        <div class="progress flow-score-bar mb-1">
                          <div class="progress-bar bg-warning text-dark"
                               :style="{ width: scoreNetworkPct + '%' }"
                               style="font-size: 0.7rem;">
                            {{ scoreNetworkPct > 15 ? 'Network' : '' }}
                          </div>
                          <div class="progress-bar bg-success"
                               :style="{ width: (100 - scoreNetworkPct) + '%' }"
                               style="font-size: 0.7rem;">
                            {{ (100 - scoreNetworkPct) > 15 ? 'Security' : '' }}
                          </div>
                        </div>
                        <div class="d-flex gap-3 small">
                          <span><span class="badge bg-warning text-dark me-1">{{ scoreNetworkPct }}%</span>{{ _i18n('flow_details.score_category_network') }}</span>
                          <span><span class="badge bg-success me-1">{{ 100 - scoreNetworkPct }}%</span>{{ _i18n('flow_details.score_category_security') }}</span>
                        </div>
                      </td>
                    </tr>
                  </template>

                  <!-- Alert rows -->
                  <template v-if="alerts.length > 0">
                    <tr>
                      <th colspan="2" class="flow-section-divider">
                        <i class="fas fa-exclamation-triangle me-1 flow-accent-icon"></i>
                        {{ _i18n('flow_details.flow_issues') }}
                      </th>
                    </tr>
                    <tr v-for="al in alerts" :key="al.alert_id ?? al.risk_str">
                      <td colspan="2" class="py-2 px-3">
                        <div class="d-flex align-items-start gap-2 flex-wrap">
                          <span class="badge flex-shrink-0"
                                :class="al.src === 'nDPI' ? 'bg-info text-dark' : 'bg-secondary'">
                            {{ al.src }}
                          </span>
                          <span v-if="al.is_predominant" class="badge bg-danger flex-shrink-0">
                            <i class="fas fa-star me-1"></i>{{ _i18n('flow_details.predominant') }}
                          </span>
                          <span class="small flex-grow-1">{{ al.message }}</span>
                          <span v-if="al.score > 0" class="badge flex-shrink-0"
                                :class="scoreToBadge(al.score)">
                            {{ al.score }}
                          </span>
                          <a v-if="al.alert_id"
                             :href="`${http_prefix}/lua/alert_stats.lua?alert_id=${al.alert_id}&status=historical-flows`"
                             class="btn btn-sm btn-outline-secondary flex-shrink-0"
                             title="Historical alerts">
                            <i class="fas fa-history fa-xs"></i>
                          </a>
                        </div>
                        <div v-if="al.risk_label || al.mitre_id"
                             class="d-flex gap-2 flex-wrap mt-1 ps-1">
                          <span v-if="al.risk_label" class="small text-muted">
                            {{ al.risk_label }}
                          </span>
                          <span v-if="al.mitre_id" class="badge bg-dark font-monospace">
                            {{ al.mitre_id }}
                          </span>
                        </div>
                      </td>
                    </tr>
                  </template>

                </tbody>
              </table>
            </div>
          </div>
        </div>

      </div><!-- /row 2 -->

      <!-- Performance  |  Infrastructure (only rendered when there is data to show) -->
      <div v-if="hasAnyPerfData || hasAnyInfraData" class="row g-4 mb-4">

        <!-- Performance -->
        <div v-if="hasAnyPerfData" :class="hasAnyInfraData ? 'col-12 col-lg-6' : 'col-12'">
          <div class="flow-card card h-100">
            <div class="flow-card-header card-header d-flex align-items-center gap-2">
              <i class="fas fa-tachometer-alt flow-accent-icon"></i>
              <span>Performance</span>
            </div>
            <div class="card-body p-0">
              <table class="flow-table table table-sm table-striped mb-0">
                <tbody>

                  <!-- RTT -->
                  <template v-if="hasRtt">
                    <tr>
                      <th>{{ _i18n('flow_details.rtt_breakdown') }}</th>
                      <td>
                        <div class="progress flow-rtt-bar mb-1">
                          <div class="progress-bar flow-bar-cli"
                               :style="{ width: rttClientPct + '%' }"
                               style="font-size: 0.7rem;">
                            {{ rttClient }}ms
                          </div>
                          <div class="progress-bar flow-bar-srv"
                               :style="{ width: (100 - rttClientPct) + '%' }"
                               style="font-size: 0.7rem;">
                            {{ rttServer }}ms
                          </div>
                        </div>
                        <span class="small text-muted">
                          client {{ rttClient }}ms / server {{ rttServer }}ms
                        </span>
                      </td>
                    </tr>
                    <tr v-if="rttDistanceKm > 0">
                      <th>
                        <a href="https://en.wikipedia.org/wiki/Velocity_factor"
                           target="_blank" class="flow-ext-link">
                          {{ _i18n('flow_details.rtt_distance') }}
                          <i class="fas fa-external-link-alt fa-xs ms-1"></i>
                        </a>
                      </th>
                      <td>{{ fmtNum(rttDistanceKm) }} km / {{ fmtNum(rttDistanceMi) }} mi</td>
                    </tr>
                  </template>

                  <tr v-if="flow['tcp.appl_latency'] > 0">
                    <th>{{ _i18n('flow_details.application_latency') }}</th>
                    <td class="fw-semibold">{{ flow['tcp.appl_latency'] }} ms</td>
                  </tr>

                  <tr v-if="ctx.is_enterprise_l && flow.qoe?.score?.cli_to_srv != null">
                    <th>{{ _i18n('flow_details.qoe_long') }}</th>
                    <td>
                      {{ flow.qoe.score.cli_to_srv }}
                      <span class="text-muted mx-1">/</span>
                      {{ flow.qoe.score.srv_to_cli }}
                      <span class="text-muted small ms-1">(cli/srv)</span>
                    </td>
                  </tr>

                  <template v-if="hasInterArrival">
                    <tr>
                      <th colspan="2" class="flow-section-divider">
                        <i class="fas fa-stopwatch me-1 flow-accent-icon"></i>
                        {{ _i18n('flow_details.packet_inter_arrival_time') }}
                        <span v-if="flow['flow.idle']" class="badge bg-secondary ms-2 small">idle</span>
                      </th>
                    </tr>
                    <tr>
                      <th>Client → Server</th>
                      <td class="small">
                        min {{ flow['interarrival.cli2srv']?.min }}ms /
                        avg {{ flow['interarrival.cli2srv']?.avg }}ms /
                        max {{ flow['interarrival.cli2srv']?.max }}ms
                      </td>
                    </tr>
                    <tr v-if="flow['srv2cli.packets'] >= 2">
                      <th>Server → Client</th>
                      <td class="small">
                        min {{ flow['interarrival.srv2cli']?.min }}ms /
                        avg {{ flow['interarrival.srv2cli']?.avg }}ms /
                        max {{ flow['interarrival.srv2cli']?.max }}ms
                      </td>
                    </tr>
                  </template>

                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- Infrastructure -->
        <div v-if="hasAnyInfraData" :class="hasAnyPerfData ? 'col-12 col-lg-6' : 'col-12'">
          <div class="flow-card card h-100">
            <div class="flow-card-header card-header d-flex align-items-center gap-2">
              <i class="fas fa-server flow-accent-icon"></i>
              <span>Infrastructure</span>
            </div>
            <div class="card-body p-0">
              <table class="flow-table table table-sm table-striped mb-0">
                <tbody>

                  <!-- ASN -->
                  <template v-if="hasAsn">
                    <tr v-if="flow['cli.asn'] > 0">
                      <th>Client AS</th>
                      <td>
                        <a :href="`${http_prefix}/lua/hosts_stats.lua?asn=${flow['cli.asn']}`"
                           class="flow-ext-link">
                          AS{{ flow['cli.asn'] }}
                        </a>
                      </td>
                    </tr>
                    <tr v-if="flow['srv.asn'] > 0">
                      <th>Server AS</th>
                      <td>
                        <a :href="`${http_prefix}/lua/hosts_stats.lua?asn=${flow['srv.asn']}`"
                           class="flow-ext-link">
                          AS{{ flow['srv.asn'] }}
                        </a>
                      </td>
                    </tr>
                    <tr v-if="flow['cli.prev_asn'] > 0">
                      <th>Prev AS</th>
                      <td>
                        <a :href="`${http_prefix}/lua/hosts_stats.lua?asn=${flow['cli.prev_asn']}`"
                           class="flow-ext-link">AS{{ flow['cli.prev_asn'] }}</a>
                      </td>
                    </tr>
                    <tr v-if="flow['srv.next_asn'] > 0">
                      <th>Next AS</th>
                      <td>
                        <a :href="`${http_prefix}/lua/hosts_stats.lua?asn=${flow['srv.next_asn']}`"
                           class="flow-ext-link">AS{{ flow['srv.next_asn'] }}</a>
                      </td>
                    </tr>
                    <tr v-if="flow.wlan?.ssid">
                      <th>WLAN SSID</th>
                      <td>{{ flow.wlan.ssid }}</td>
                    </tr>
                  </template>

                  <!-- Container / K8s -->
                  <template v-if="hasContainerInfo">
                    <template v-for="side in ['client_container', 'server_container']" :key="side">
                      <template v-if="flow[side]">
                        <tr>
                          <th colspan="2" class="flow-section-divider">
                            <i class="fab fa-docker me-1 flow-accent-icon"></i>
                            {{ side === 'client_container' ? 'Client' : 'Server' }} Container
                          </th>
                        </tr>
                        <tr v-if="flow[side].id">
                          <th>Container ID</th>
                          <td>
                            <a :href="`${http_prefix}/lua/flows_stats.lua?container=${flow[side].id}`"
                               class="flow-ext-link">
                              {{ flow[side].id.substring(0, 12) }}
                            </a>
                          </td>
                        </tr>
                        <tr v-if="flow[side]['k8s.pod']">
                          <th>K8s Pod</th>
                          <td>
                            <a :href="`${http_prefix}/lua/containers_stats.lua?pod=${flow[side]['k8s.pod']}`"
                               class="flow-ext-link">
                              {{ flow[side]['k8s.pod'] }}
                            </a>
                          </td>
                        </tr>
                        <tr v-if="flow[side]['k8s.ns']">
                          <th>K8s Namespace</th>
                          <td>{{ flow[side]['k8s.ns'] }}</td>
                        </tr>
                        <tr v-if="flow[side]['docker.name']">
                          <th>Docker Name</th>
                          <td>{{ flow[side]['docker.name'] }}</td>
                        </tr>
                      </template>
                    </template>
                  </template>

                  <!-- Process Info -->
                  <template v-if="hasProcessInfo">
                    <tr>
                      <th colspan="2" class="flow-section-divider">
                        <i class="fas fa-cogs me-1 flow-accent-icon"></i>
                        {{ _i18n('flow_details.process_information') }}
                      </th>
                    </tr>
                    <template v-for="side in ['client_process', 'server_process']" :key="side">
                      <template v-if="flow[side]?.pid > 0">
                        <tr>
                          <th>{{ side === 'client_process' ? 'Client' : 'Server' }} Process</th>
                          <td>
                            {{ flow[side].name }}
                            <span class="text-muted small ms-1">[PID {{ flow[side].pid }}]</span>
                            <span v-if="flow[side].user_name" class="text-muted small ms-2">
                              {{ flow[side].user_name }}
                            </span>
                          </td>
                        </tr>
                        <tr v-if="flow[side].father_name">
                          <th>Parent</th>
                          <td>
                            {{ flow[side].father_name }}
                            <span class="text-muted small ms-1">[PID {{ flow[side].father_pid }}]</span>
                          </td>
                        </tr>
                      </template>
                    </template>
                  </template>

                </tbody>
              </table>
            </div>
          </div>
        </div>

      </div><!-- /row 3 -->

    </template><!-- /v-if flow -->
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount } from "vue";

const props = defineProps({ context: Object });
const _i18n = (t) => i18n(t);
const ctx   = props.context;
const flow  = ctx.flow || null;

/* Live data, polled from /lua/flow_stats.lua */
const liveData    = ref({});
const flow_purged = ref(false);
let   poll_timer  = null;

/* Helpers */
const bytesVol = (n) => (n != null && !isNaN(n)) ? NtopUtils.bytesToVolume(n) : '0 B';
const fmtNum   = (n) => (n != null) ? NtopUtils.addCommas(n) : '0';
const fmtBits  = (n) => (n > 0) ? NtopUtils.bitsToSize(8 * n) : '—';
const fmtEpoch = (ts) => ts ? new Date(ts * 1000).toLocaleString() : '—';

const copyText = (text) => {
  try { navigator.clipboard.writeText(text); } catch (_) {}
};

/* Basic protocol flags */
const isTcp  = computed(() => flow?.['proto.l4'] === 'TCP');
const isIcmp = computed(() => flow?.['proto.l4'] === 'ICMP' || flow?.['proto.l4'] === 'ICMPv6');

/* Duration  */
const durationStr = computed(() => {
  if (!flow) return '—';
  const s = (flow['seen.last'] - flow['seen.first']) || 0;
  if (s < 60)   return s + 's';
  if (s < 3600) return `${Math.floor(s / 60)}m ${s % 60}s`;
  return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
});

/* Hero metrics */
const liveBytes     = computed(() => liveData.value.bytes ?? flow?.['bytes']);
const totalPackets  = computed(() => {
  const c = liveData.value['cli2srv.packets'] ?? (flow?.['cli2srv.packets'] || 0);
  const s = liveData.value['srv2cli.packets'] ?? (flow?.['srv2cli.packets'] || 0);
  return c + s;
});

/* Protocol / badge helpers */
const l4BadgeClass = computed(() => {
  const p = flow?.['proto.l4'];
  if (p === 'TCP')  return 'flow-proto-tcp';
  if (p === 'UDP')  return 'flow-proto-udp';
  if (p === 'ICMP' || p === 'ICMPv6') return 'flow-proto-icmp';
  return 'flow-proto-secondary';
});
const confidenceBadgeClass = computed(() => {
  const c = flow?.['proto.ndpi_confidence'];
  return (!c || c === 'Unknown') ? 'bg-warning text-dark' : 'bg-success';
});
const flowSource = computed(() => {
  if (flow?.flow_source === 1) return 'NetFlow/IPFIX';
  if (flow?.flow_source === 2) return 'sFlow/nfLite';
  return null;
});

/* TLS */
const tlsVersionName = computed(() => {
  const v = flow?.['protos.tls_version'];
  if (!v || v === 0) return null;
  return { 769: 'TLS 1.0', 770: 'TLS 1.1', 771: 'TLS 1.2', 772: 'TLS 1.3' }[v]
    || ('TLS 0x' + v.toString(16));
});
const isOldTls = computed(() => (flow?.['protos.tls_version'] ?? 772) < 771);
const isTlsExpiredOrFuture = computed(() => {
  const now = Math.floor(Date.now() / 1000);
  return (flow?.['protos.tls.notBefore'] > now) || (flow?.['protos.tls.notAfter'] < now);
});

/* Traffic direction bar */
const cli2srvPct = computed(() => {
  const total = (liveData.value.bytes ?? flow?.['bytes']) || 1;
  const c2s   = (liveData.value['cli2srv.bytes'] ?? flow?.['cli2srv.bytes']) || 0;
  return Math.max(5, Math.min(95, Math.round((c2s * 100) / total)));
});
const goodputPct = computed(() => {
  const bytes   = liveData.value.bytes ?? (flow?.['bytes'] || 0);
  const goodput = liveData.value.goodput_bytes ?? (flow?.['goodput_bytes'] || 0);
  return bytes ? Math.round((goodput * 100) / bytes) : 0;
});
const goodputBadgeClass = computed(() => {
  const p = goodputPct.value;
  return p < 50 ? 'bg-danger' : p < 60 ? 'bg-warning text-dark' : 'bg-success';
});

/* TCP helpers */
const tcpRetr   = computed(() => (liveData.value.c2sretr ?? flow?.['cli2srv.retransmissions'] ?? 0) + (liveData.value.s2cretr ?? flow?.['srv2cli.retransmissions'] ?? 0));
const tcpOOO    = computed(() => (liveData.value.c2sOOO ?? flow?.['cli2srv.out_of_order'] ?? 0) + (liveData.value.s2cOOO ?? flow?.['srv2cli.out_of_order'] ?? 0));
const tcpLost   = computed(() => (liveData.value.c2slost ?? flow?.['cli2srv.lost'] ?? 0) + (liveData.value.s2clost ?? flow?.['srv2cli.lost'] ?? 0));
const tcpMaxThpt = computed(() => flow?.['tcp.max_thpt.cli2srv'] ?? 0);

/* Score */
const hasScore = computed(() => (flow?.score?.flow_score ?? 0) > 0);
const scoreSeverityLabel = computed(() => {
  const s = flow?.score?.flow_score ?? 0;
  if (s >= 100) return 'Critical';
  if (s >= 50)  return 'High';
  if (s >= 25)  return 'Medium';
  if (s > 0)    return 'Low';
  return 'OK';
});
const scoreValueClass = computed(() => {
  const s = flow?.score?.flow_score ?? 0;
  if (s >= 50) return 'text-danger';
  if (s >= 25) return 'text-warning';
  if (s > 0)   return 'text-info';
  return 'text-success';
});
const scorePillClass = computed(() => {
  const s = flow?.score?.flow_score ?? 0;
  if (s >= 50) return 'flow-score-high';
  if (s >= 25) return 'flow-score-medium';
  if (s > 0)   return 'flow-score-low';
  return 'flow-score-ok';
});
const scoreNetworkPct = computed(() => {
  const net = flow?.score?.host_categories_total?.['0'] ?? 0;
  const sec = flow?.score?.host_categories_total?.['1'] ?? 0;
  const tot = net + sec;
  return tot ? Math.round((net * 100) / tot) : 50;
});
const scoreToBadge = (score) =>
  score >= 50 ? 'bg-danger' : score >= 25 ? 'bg-warning text-dark' : 'bg-info text-dark';

/* Alerts list */
const alerts = computed(() => {
  if (!flow) return [];
  const list    = [];
  const scores  = flow.score?.alert_score || {};
  const riskInfo = (() => { try { return JSON.parse(flow.riskInfo || '{}'); } catch { return {}; } })();

  for (const [id] of Object.entries(flow.alerts_map || {})) {
    list.push({
      alert_id:      id,
      is_predominant: id == flow.predominant_alert,
      message:       `Alert ${id}`,
      src:           'ntopng',
      score:         scores[String(id)] ?? 0,
      risk_label:    riskInfo[String(id)] ? String(riskInfo[String(id)]).substring(0, 80) : null,
      mitre_id:      null,
    });
  }
  for (const [risk_str] of Object.entries(flow.unhandled_flow_risk || {})) {
    list.push({ alert_id: null, is_predominant: false, message: risk_str, src: 'nDPI', score: 0, risk_label: null, mitre_id: null });
  }
  return list.sort((a, b) => (b.score ?? 0) - (a.score ?? 0));
});

/* Protocol */
const hasTls  = computed(() => !!(flow?.['protos.tls.client_requested_server_name'] || flow?.['protos.tls_version'] || flow?.['protos.tls.issuerDN']));
const hasHttp = computed(() => !!(flow?.['protos.http.last_url']));
const hasDns  = computed(() => !!(flow?.['protos.dns.last_query']));
const hasSsh  = computed(() => !!(flow?.['protos.ssh.hassh.client_hash'] || flow?.['protos.ssh.hassh.server_hash']));
const hasAnyAppData = computed(() => hasTls.value || hasHttp.value || hasDns.value || hasSsh.value
  || !!(flow?.['protos.smtp.mail_from']) || !!(flow?.bittorrent_hash));

/* Performance */
const hasRtt = computed(() => ((flow?.['tcp.nw_latency.3wh_client_rtt'] ?? 0) + (flow?.['tcp.nw_latency.3wh_server_rtt'] ?? 0)) > 0);
const rttClient    = computed(() => parseFloat((flow?.['tcp.nw_latency.3wh_client_rtt'] ?? 0).toFixed(3)));
const rttServer    = computed(() => parseFloat((flow?.['tcp.nw_latency.3wh_server_rtt'] ?? 0).toFixed(3)));
const rttClientPct = computed(() => { const t = rttClient.value + rttServer.value; return t > 0 ? Math.round((rttClient.value * 100) / t) : 50; });
const rttDistanceKm = computed(() => { const d = ((rttClient.value + rttServer.value) / 1000) * 299792 * 0.67; return Math.round(d); });
const rttDistanceMi = computed(() => { const d = ((rttClient.value + rttServer.value) / 1000) * 186000 * 0.67; return Math.round(d); });
const hasInterArrival = computed(() => (flow?.['interarrival.cli2srv']?.max ?? 0) > 0 && (flow?.['cli2srv.packets'] ?? 0) > 1);
const hasAnyPerfData  = computed(() => hasRtt.value || (flow?.['tcp.appl_latency'] > 0) || hasInterArrival.value || (ctx.is_enterprise_l && flow?.qoe));

/* Infrastructure */
const hasAsn          = computed(() => (flow?.['cli.asn'] ?? 0) > 0 || (flow?.['srv.asn'] ?? 0) > 0);
const hasContainerInfo = computed(() => !!(flow?.client_container || flow?.server_container));
const hasProcessInfo   = computed(() => (flow?.client_process?.pid ?? 0) > 0 || (flow?.server_process?.pid ?? 0) > 0);
const hasAnyInfraData  = computed(() => hasAsn.value || hasContainerInfo.value || hasProcessInfo.value);

/* HTTP helpers */
const httpMethodBadge = (m) => ({ GET: 'bg-success', POST: 'bg-primary', PUT: 'bg-warning text-dark', DELETE: 'bg-danger', PATCH: 'bg-info text-dark' }[m] || 'bg-secondary');
const httpCodeBadge   = (c) => !c ? 'bg-secondary' : c < 300 ? 'bg-success' : c < 400 ? 'bg-info text-dark' : 'bg-warning text-dark';

/* Live polling */
const pollFlowStats = async () => {
  if (flow_purged.value) return;
  try {
    const p = new URLSearchParams({ ifid: ctx.ifid, flow_key: ctx.flow_key, flow_hash_id: ctx.flow_hash_id });
    const text = await fetch(`${http_prefix}/lua/flow_stats.lua?${p}`).then(r => r.text());
    if (!text || text.trim() === '{}') {
      flow_purged.value = true;
      clearInterval(poll_timer);
      return;
    }
    const data = JSON.parse(text);
    const prev = liveData.value;
    data.trend_cli2srv = (prev['cli2srv.packets'] != null && data['cli2srv.packets'] > prev['cli2srv.packets']) ? 'up' : 'flat';
    data.trend_srv2cli = (prev['srv2cli.packets'] != null && data['srv2cli.packets'] > prev['srv2cli.packets']) ? 'up' : 'flat';
    liveData.value = data;
  } catch (_) {}
};

onMounted(() => {
  if (flow) {
    pollFlowStats();
    poll_timer = setInterval(pollFlowStats, 3000);
  }
});

onBeforeUnmount(() => { if (poll_timer) clearInterval(poll_timer); });
</script>

<style scoped>

/* Hero banner */
.flow-hero {
  background: linear-gradient(135deg, var(--ntop-blue-dark) 0%, var(--ntop-blue) 100%);
  color: #fff;
  border: none;
}

.flow-hero-host {
  font-size: 1.25rem;
  font-weight: 700;
  color: #fff;
  letter-spacing: -0.01em;
}
.flow-hero-host:hover { color: rgba(255,255,255,0.85); }

.flow-hero-port {
  font-size: 0.9rem;
  color: rgba(255, 255, 255, 0.65);
}

.flow-arrow-icon {
  font-size: 1.3rem;
  color: var(--ntop-orange);
}

/* Protocol badges in hero */
.flow-proto-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.15em 0.6em;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: #fff;
}
.flow-proto-tcp       { background: #198754; }
.flow-proto-udp       { background: #0dcaf0; color: #000; }
.flow-proto-icmp      { background: #ffc107; color: #000; }
.flow-proto-app       { background: var(--ntop-orange); }
.flow-proto-warn      { background: #ffc107; color: #000; }
.flow-proto-secondary { background: rgba(255,255,255,0.25); }

/* Verdict badge */
.flow-verdict-badge {
  display: inline-flex;
  align-items: center;
  padding: 0.3em 0.75em;
  border-radius: 999px;
  font-size: 0.78rem;
  font-weight: 600;
}
.flow-verdict-blocked { background: #dc3545; color: #fff; }

/* Score pill */
.flow-score-pill {
  display: inline-flex;
  align-items: center;
  padding: 0.3em 0.75em;
  border-radius: 999px;
  font-size: 0.78rem;
  border: 1px solid rgba(255,255,255,0.3);
  color: #fff;
}
.flow-score-ok     { background: rgba(25, 135, 84, 0.7); }
.flow-score-low    { background: rgba(13, 202, 240, 0.7); }
.flow-score-medium { background: rgba(255, 193, 7, 0.8); color: #000; }
.flow-score-high   { background: rgba(220, 53, 69, 0.8); }

/* Status badges */
.flow-status-badge {
  display: inline-block;
  padding: 0.2em 0.65em;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 600;
  background: rgba(255, 255, 255, 0.15);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.25);
}

/* Hero metrics row */
.flow-hero-metrics {
  border-top: 1px solid rgba(255,255,255,0.15);
  padding-top: 0.75rem;
  margin-top: 0.25rem;
}
.flow-metric-label {
  font-size: 0.7rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: rgba(255,255,255,0.55);
  margin-right: 0.3rem;
}
.flow-metric-value {
  font-size: 0.88rem;
  font-weight: 600;
  color: rgba(255,255,255,0.9);
}

/* Section cards */
.flow-card {
  border-radius: 0.5rem;
  overflow: hidden;
  border-color: rgba(0, 0, 0, 0.1);
}
.flow-card-header {
  font-weight: 600;
  font-size: 0.88rem;
  letter-spacing: 0.02em;
  border-left: 3px solid var(--ntop-orange);
  padding: 0.65rem 1rem;
}
.flow-accent-icon {
  color: var(--ntop-orange);
  font-size: 0.9rem;
}

/* Info table */
.flow-table th {
  width: 42%;
  font-weight: 600;
  font-size: 0.82rem;
  vertical-align: middle;
  padding: 0.55rem 1rem;
  white-space: nowrap;
  color: var(--ntop-text-color);
}
.flow-table td {
  font-size: 0.82rem;
  vertical-align: middle;
  padding: 0.55rem 1rem;
  word-break: break-word;
  color: var(--ntop-text-color);
}
.flow-section-divider {
  font-size: 0.78rem !important;
  letter-spacing: 0.03em;
  background: rgba(0,0,0,0.03) !important;
  width: auto !important;
  white-space: normal !important;
  padding: 0.4rem 1rem !important;
}

/* Code */
.flow-code {
  font-size: 0.75rem;
  color: var(--ntop-text-color);
  opacity: 0.85;
}

/* Direction bar */
.flow-dir-bar {
  height: 12px;
  border-radius: 4px;
  overflow: hidden;
}
.flow-rtt-bar {
  height: 18px;
  border-radius: 4px;
  overflow: hidden;
}
.flow-score-bar {
  height: 18px;
  border-radius: 4px;
}
.flow-bar-cli { background: var(--ntop-orange); }
.flow-bar-srv { background: var(--ntop-blue-light, #6ea8fe); }
.flow-cli-color { color: var(--ntop-orange); }
.flow-srv-color { color: var(--ntop-blue-light, #6ea8fe); }

/* External links */
.flow-ext-link {
  color: var(--ntop-text-color);
  text-decoration: none;
  transition: color 0.15s ease;
}
.flow-ext-link:hover { color: var(--ntop-orange); text-decoration: none; }

/* Score value colours */
.text-danger   { color: #dc3545 !important; }
.text-warning  { color: #ffc107 !important; }
.text-info     { color: #0dcaf0 !important; }
.text-success  { color: #198754 !important; }
</style>

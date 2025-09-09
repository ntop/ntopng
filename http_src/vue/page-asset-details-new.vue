<template>
    <div class="vh-100 d-flex flex-column">
        <div class="flex-grow-1 p-3">
            <!-- Loading State -->
            <div v-if="loading" class="d-flex justify-content-center py-5">
                <div class="spinner-border" role="status">
                    <span class="visually-hidden">Loading...</span>
                </div>
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="alert alert-danger" role="alert">
                <h4 class="alert-heading">Error Loading Asset Details</h4>
                <p>{{ error }}</p>
            </div>

            <!-- No Data State -->
            <div v-else-if="!deviceData" class="alert alert-warning" role="alert">
                <h4 class="alert-heading">No Asset Found</h4>
                <p>No asset information found for the provided serial key.</p>
            </div>

            <!-- Main Content -->
            <div v-else class="h-100 d-flex flex-column">
                <!-- Modern Header with Enhanced Information -->
                <div class="mb-3 flex-shrink-0">
                    <div class="card shadow-sm border rounded-4" :class="{ 'dimmed': highlightMode }">
                        <div class="card-body p-4 p-lg-5">
                            <div class="row align-items-start">
                                <!-- Left Section - Device Info -->
                                <div class="col-lg-8">
                                    <!-- Device Identity -->
                                    <div class="row g-4 mb-4">
                                        <div class="col-md-4">
                                            <div class="d-flex align-items-center gap-3">
                                                <div class="p-2 bg-primary bg-opacity-10 rounded-3">
                                                    <i class="fas fa-server"></i>
                                                </div>
                                                <div>
                                                    <p class="fw-semibold mb-1">Device Name</p>

                                                    <a class="mb-0"
                                                        :href="`${deviceData.host_url}`">
                                                        {{ deviceData.host_name }}
                                                    </a>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="col-md-4">
                                            <div class="d-flex align-items-center gap-3">
                                                <div class="d-flex align-items-center gap-2">
                                                    <div class="position-relative">
                                                        <div class="rounded-circle"
                                                            :class="deviceData.is_online ? 'bg-success pulse-animation' : 'bg-secondary'"
                                                            style="width: 16px; height: 16px;">
                                                        </div>
                                                    </div>
                                                    <div>
                                                        <p class="fw-semibold mb-1">Status</p>
                                                        <p class="fw-semibold mb-0"
                                                            :class="deviceData.is_online ? 'text-success' : 'text-secondary'">
                                                            {{ deviceData.is_online ? 'Online' : 'Offline' }}
                                                        </p>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="col-md-4">
                                            <div class="d-flex align-items-center gap-3">
                                                <div class="p-2 bg-warning bg-opacity-10 rounded-3">
                                                    <i class="fas fa-bolt text-warning"></i>
                                                </div>
                                                <div>
                                                    <p class="fw-semibold mb-1">Device Type</p>
                                                    <div class="fw-semibold">
                                                        <span v-if="deviceData.device_icon"
                                                            v-html="deviceData.device_icon"></span>
                                                        {{ deviceData.device_type_name || 'Unknown' }}
                                                        <span v-if="deviceData.os_icon"
                                                            v-html="deviceData.os_icon"></span>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                <!-- Right Section - Services Info -->
                                <div class="col-lg-4">
                                    <!-- Quick Stats -->
                                    <div class="d-flex gap-2">
                                        <div class="text-bg-primary border rounded-3 px-3 py-2 text-center flex-fill">
                                            <p class="mb-1">Services</p>
                                            <p class="h5 fw-bold mb-0">{{ deviceData.server_services?.length || 0 }}</p>
                                        </div>
                                        <div class="hover-highlight rounded-3 px-3 py-2 text-center flex-fill transition-all"
                                            :class="[
                                                highlightMode === 'tcp' ? 'tcp-highlighted' : 'bg-success bg-opacity-10 border border-success',
                                                highlightMode && highlightMode !== 'tcp' ? 'dimmed' : ''
                                            ]" @mouseenter="highlightMode = 'tcp'" @mouseleave="highlightMode = null"
                                            style="cursor: pointer;">
                                            <p class="mb-1">TCP Ports</p>
                                            <p class="h5 fw-bold mb-0">{{ deviceData.tcp_ports?.length || 0 }}</p>
                                        </div>
                                        <div class="hover-highlight rounded-3 px-3 py-2 text-center flex-fill transition-all"
                                            :class="[
                                                highlightMode === 'udp' ? 'udp-highlighted' : 'bg-warning bg-opacity-10 border border-warning',
                                                highlightMode && highlightMode !== 'udp' ? 'dimmed' : ''
                                            ]" @mouseenter="highlightMode = 'udp'" @mouseleave="highlightMode = null"
                                            style="cursor: pointer;">
                                            <p class="mb-1">UDP Ports</p>
                                            <p class="h5 fw-bold mb-0">{{ deviceData.udp_ports?.length || 0 }}</p>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Main Grid -->
                <div class="row g-4">

                    <!-- Device Information Card -->
                    <div class="col-lg-4">
                        <div class="card shadow-sm border rounded-3 h-100" :class="{ 'dimmed': highlightMode }">
                            <div class="card-body p-4">
                                <div class="d-flex align-items-center gap-3 mb-4">
                                    <div class="p-2 bg-primary bg-opacity-10 rounded-3">
                                        <i class="fas fa-desktop"></i>
                                    </div>
                                    <h2 class="h5 fw-semibold mb-0">Device Information</h2>
                                </div>

                                <div class="vstack gap-4">
                                    <div v-if="deviceData.device_type_name" class="info-item">
                                        <label class="fw-semibold mb-1 d-block">Device Type</label>
                                        <p class="mb-0">{{ deviceData.device_type_name }}</p>
                                    </div>

                                    <div v-if="deviceData.mac_address" class="info-item">
                                        <label class="fw-semibold mb-1 d-block">MAC Address</label>
                                        <div class="d-flex align-items-center gap-2">
                                            <p class="px-2 py-1 rounded mb-0">
                                                <a v-if="deviceData.symbolic_mac"
                                                    :href="`${mac_details_url}${deviceData.symbolic_mac}`">
                                                    {{ deviceData.symbolic_mac }}
                                                </a>
                                            </p>

                                        </div>
                                    </div>

                                    <div v-if="deviceData.model" class="info-item">
                                        <label class="fw-semibold mb-1 d-block">Model</label>
                                        <p class="mb-0">{{ deviceData.model }}</p>
                                    </div>

                                    <div class="info-item">
                                        <label class="fw-semibold mb-1 d-block">First Seen</label>
                                        <p class="mb-0">{{ deviceData.first_seen_formatted }}</p>
                                    </div>

                                    <div class="info-item">
                                        <label class="fw-semibold mb-1 d-block">Last Seen</label>
                                        <p class="mb-0">
                                            <span v-if="deviceData.last_seen_formatted === 'Online'"
                                                class="badge bg-success">
                                                Online
                                            </span>
                                            <span v-else>
                                                {{ deviceData.last_seen_formatted }}
                                            </span>
                                        </p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Network Information Card -->
                    <div class="col-lg-4">
                        <div class="card shadow-sm border rounded-3 h-100" :class="{ 'dimmed': highlightMode }">
                            <div class="card-body p-4">
                                <div class="d-flex align-items-center gap-3 mb-4">
                                    <div class="p-2 bg-success bg-opacity-10 rounded-3">
                                        <i class="fas fa-network-wired text-success"></i>
                                    </div>
                                    <h2 class="h5 fw-semibold mb-0">Network Information</h2>
                                </div>

                                <div class="vstack gap-4">
                                    <div v-if="deviceData.ip_address" class="info-item">
                                        <label class="fw-semibold mb-1 d-block">IP Address</label>
                                        <div class="d-flex align-items-center gap-2">
                                            <code class="px-2 py-1 rounded">
                                                {{ deviceData.ip_address }}
                                                <span v-if="deviceData.vlan && deviceData.vlan !== '0'">@{{ deviceData.vlan }}</span>
                                            </code>
                                        </div>
                                    </div>

                                    <div v-if="deviceData.network_name" class="info-item">
                                        <label class="fw-semibold mb-1 d-block">Network</label>
                                        <div class="d-flex align-items-center gap-2">
                                            <a class="mb-0"
                                                :href="`${network_details_url}${deviceData.network}`">
                                                {{ deviceData.network_name }}
                                            </a>

                                        </div>

                                    </div>

                                    <div v-if="deviceData.snmp_location_description" class="info-item">
                                        <label class="fw-semibold mb-1 d-block">SNMP Location</label>
                                        <p class="mb-0" v-html="deviceData.snmp_location_description"></p>
                                    </div>

                                    <div v-if="deviceData.switch_ip" class="info-item">
                                        <label class="fw-semibold mb-1 d-block">Switch IP</label>
                                        <p class="mb-0"
                                            v-html="deviceData.switch_ip_url || deviceData.switch_ip_name || deviceData.switch_ip">
                                        </p>
                                    </div>

                                    <div v-if="deviceData.switch_port" class="info-item">
                                        <label class="fw-semibold mb-1 d-block">Switch Port</label>
                                        <p class="mb-0"
                                            v-html="deviceData.switch_port_formatted || deviceData.switch_port"></p>
                                    </div>

                                    <div v-if="deviceData.additional_names && deviceData.additional_names.length > 0"
                                        class="info-item">
                                        <label class="fw-semibold mb-1 d-block">Additional Names</label>
                                        <div v-for="(host, index) in deviceData.additional_names" :key="index"
                                            class="d-flex align-items-center justify-content-between px-3 py-2 rounded-3 mt-2">
                                            <span>{{ host.name }}</span>
                                            <span class="badge bg-primary rounded-pill">{{ host.source }}</span>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <!-- Services & Status Card -->
                    <div class="col-lg-4">
                        <div class="card shadow-sm border rounded-3 h-100"
                            :class="{ 'dimmed': highlightMode && highlightMode !== 'tcp' && highlightMode !== 'udp' }">
                            <div class="card-body p-4">
                                <div class="d-flex align-items-center gap-3 mb-4">
                                    <div class="p-2 bg-info bg-opacity-10 rounded-3">
                                        <i class="fas fa-chart-line text-info"></i>
                                    </div>
                                    <h2 class="h5 fw-semibold mb-0">Services & Status</h2>
                                </div>

                                <div class="vstack gap-4">
                                    <!-- Running Services -->
                                    <div v-if="deviceData.server_services && deviceData.server_services.length > 0"
                                        class="info-item">
                                        <label class="fw-semibold mb-2 d-block">Running Services</label>
                                        <div class="d-flex flex-wrap gap-2">
                                            <span v-for="(service, index) in deviceData.server_services" :key="index"
                                                class="badge bg-success">
                                                {{ service.label || service.type }}
                                            </span>
                                        </div>
                                    </div>

                                    <!-- DHCP Fingerprint -->
                                    <div v-if="deviceData.has_dhcp_fingerprint" class="info-item">
                                        <div class="d-flex align-items-center gap-2">
                                            <i class="fas fa-bolt text-warning"></i>
                                            <span class="badge bg-warning">
                                                DHCP Fingerprint
                                            </span>
                                        </div>
                                    </div>

                                    <!-- SNMP -->
                                    <div v-if="deviceData.has_snmp" class="info-item">
                                        <div class="d-flex align-items-center gap-2">
                                            <i class="fas fa-network-wired text-info"></i>
                                            <span
                                                class="badge bg-info bg-opacity-10 text-info border border-info rounded-pill px-3 py-1">
                                                SNMP Enabled
                                            </span>
                                        </div>
                                    </div>

                                    <!-- Open Ports -->
                                    <div v-if="(deviceData.tcp_ports && deviceData.tcp_ports.length > 0) || (deviceData.udp_ports && deviceData.udp_ports.length > 0)"
                                        class="info-item">
                                        <label class="fw-semibold mb-3 d-block">Open Ports</label>

                                        <div class="vstack gap-3">
                                            <!-- TCP Ports -->
                                            <div v-if="deviceData.tcp_ports && deviceData.tcp_ports.length > 0" :class="{
                                                'tcp-ports-highlighted': highlightMode === 'tcp',
                                                'dimmed': highlightMode && highlightMode !== 'tcp'
                                            }">
                                                <p class="fw-semibold mb-2">TCP Ports</p>
                                                <div class="row g-2">
                                                    <div v-for="(port, index) in deviceData.tcp_ports.slice(0, 6)"
                                                        :key="index" class="col-6">
                                                        <div class="port-item rounded-3 p-2 transition-all"
                                                            :class="highlightMode === 'tcp' ? 'bg-success text-white border-0' : 'bg-primary bg-opacity-10 border border-primary'">
                                                            <div
                                                                class="d-flex align-items-center justify-content-between">
                                                                <a v-if="port.flows_url" :href="port.flows_url"
                                                                    class="fw-bold text-decoration-none"
                                                                    :class="highlightMode === 'tcp' ? 'text-white' : 'text-primary'">
                                                                    {{ port.port }}
                                                                </a>
                                                                <span v-else class="fw-bold"
                                                                    :class="highlightMode === 'tcp' ? 'text-white' : 'text-primary'">
                                                                    {{ port.port }}
                                                                </span>
                                                                <span :title="port.name"
                                                                    :class="highlightMode === 'tcp' ? 'text-white' : 'text-primary'">
                                                                    {{ port.name }}
                                                                </span>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>

                                            <!-- UDP Ports -->
                                            <div v-if="deviceData.udp_ports && deviceData.udp_ports.length > 0" :class="{
                                                'udp-ports-highlighted': highlightMode === 'udp',
                                                'dimmed': highlightMode && highlightMode !== 'udp'
                                            }">
                                                <p class="fw-semibold mb-2">UDP Ports</p>
                                                <div class="row g-2">
                                                    <div v-for="(port, index) in deviceData.udp_ports.slice(0, 6)"
                                                        :key="index" class="col-6">
                                                        <div class="port-item rounded-3 p-2 transition-all"
                                                            :class="highlightMode === 'udp' ? 'bg-warning text-white' : 'bg-warning bg-opacity-10 border border-warning text-warning'">
                                                            <div
                                                                class="d-flex align-items-center justify-content-between">
                                                                <a v-if="port.flows_url" :href="port.flows_url"
                                                                    class="fw-bold text-decoration-none"
                                                                    :class="highlightMode === 'udp' ? 'text-white' : 'text-warning'">
                                                                    {{ port.port }}
                                                                </a>
                                                                <span v-else class="fw-bold"
                                                                    :class="highlightMode === 'udp' ? 'text-white' : 'text-warning'">
                                                                    {{ port.port }}
                                                                </span>
                                                                <span :title="port.name"
                                                                    :class="highlightMode === 'udp' ? 'text-white' : 'text-warning'">
                                                                    {{ port.name }}
                                                                </span>
                                                            </div>
                                                        </div>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Additional JSON Fields (if any) -->
                <div v-if="deviceData.json_fields && deviceData.json_fields.length > 0" class="row g-4 mt-2">
                    <div class="col-12">
                        <div class="card shadow-sm border rounded-3" :class="{ 'dimmed': highlightMode }">
                            <div class="card-body p-4">
                                <div class="d-flex align-items-center gap-3 mb-4">
                                    <div class="p-2 bg-secondary bg-opacity-10 rounded-3">
                                        <i class="fas fa-cog text-secondary"></i>
                                    </div>
                                    <h2 class="h5 fw-semibold mb-0">Additional Information</h2>
                                </div>

                                <div class="row g-3">
                                    <div v-for="(field, index) in deviceData.json_fields" :key="index"
                                        class="col-md-6 info-item">
                                        <label class="fw-semibold mb-1 d-block">{{ field.label }}</label>
                                        <p class="mb-0">{{ field.value }}</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { ntopng_url_manager } from "../services/context/ntopng_globals_services.js";
import FormatterUtils from "../utilities/formatter-utils.js";
// Props
const props = defineProps({
    ifid: Number,
    csrf: String
});

// Reactive data
const loading = ref(true);
const error = ref(null);
const deviceData = ref(null);
const highlightMode = ref(null);
const mac_details_url = `${http_prefix}/lua/mac_details.lua?host=`
const network_details_url = `${http_prefix}/lua/hosts_stats.lua?network=`

// Data fetching
const fetchData = async () => {
    loading.value = true;
    error.value = null;

    try {
        const url = "/lua/pro/rest/v2/get/host/asset_details_new.lua";
        const extra_params = ntopng_url_manager.get_url_object();
        const url_params = ntopng_url_manager.obj_to_url_params(extra_params);

        const response = await ntopng_utility.http_request(`${http_prefix}${url}?${url_params}`);

        if (response) {
            // Take the first host from the array (assuming single host lookup)
            deviceData.value = response[0];
            console.log(deviceData.value)
            // Update navbar title if needed
            if (typeof $ !== 'undefined') {
                $('#navbar_title').html("<i class='fas fa-laptop'></i> Asset Details: " + deviceData.value.host_name);
            }
        } else {
            error.value = response?.rsp?.message || "No asset data found";
        }

    } catch (err) {
        console.error('Error fetching device data:', err);
        error.value = `Failed to fetch asset data: ${err.message}`;
    } finally {
        loading.value = false;
    }
};

// Lifecycle
onMounted(fetchData);
</script>

<style scoped>
/* Transition effects */
.transition-all {
    transition: all 0.3s ease;
}

/* Dimming effect */
.dimmed {
    opacity: 0.3;
    transition: opacity 0.3s ease;
}

/* TCP highlighting */
.tcp-highlighted {
    background-color: #198754 !important;
    border-color: #198754 !important;
    box-shadow: 0 0 20px rgba(25, 135, 84, 0.5);
    transform: scale(1.05);
}

/* TCP ports section highlighting */
.tcp-ports-highlighted {
    background: linear-gradient(135deg, rgba(25, 135, 84, 0.9), rgba(25, 135, 84, 0.7));
    padding: 1rem;
    border-radius: 0.5rem;
    box-shadow: 0 0 25px rgba(25, 135, 84, 0.4);
    border: 2px solid rgba(25, 135, 84, 0.6);
}

.tcp-ports-highlighted .port-item {
    background-color: #198754 !important;
    border-color: #198754 !important;
    color: white !important;
    box-shadow: 0 0 10px rgba(25, 135, 84, 0.3);
    transform: scale(1.02);
}

.port-highlighted {
    box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2) !important;
    transform: translateY(-2px) !important;
}

/* UDP highlighting */
.udp-highlighted {
    background-color: #ffc107 !important;
    border-color: #ffc107 !important;
    box-shadow: 0 0 20px rgba(255, 193, 7, 0.5);
    transform: scale(1.05);
}

/* UDP ports section highlighting */
.udp-ports-highlighted {
    background: linear-gradient(135deg, rgba(255, 193, 7, 0.9), rgba(255, 193, 7, 0.7));
    padding: 1rem;
    border-radius: 0.5rem;
    box-shadow: 0 0 25px rgba(255, 193, 7, 0.4);
    border: 2px solid rgba(255, 193, 7, 0.6);
}

.udp-ports-highlighted .port-item {
    background-color: #ffc107 !important;
    border-color: #ffc107 !important;
    color: white !important;
    box-shadow: 0 0 10px rgba(255, 193, 7, 0.3);
    transform: scale(1.02);
}

/* Pulsing animation for online status */
.pulse-animation {
    animation: pulse 2s infinite;
}

@keyframes pulse {
    0% {
        box-shadow: 0 0 0 0 rgba(25, 135, 84, 0.7);
    }

    70% {
        box-shadow: 0 0 0 10px rgba(25, 135, 84, 0);
    }

    100% {
        box-shadow: 0 0 0 0 rgba(25, 135, 84, 0);
    }
}

/* Custom card styling */
.card {
    transition: transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out;
}

/* Info item styling for consistent label alignment */
.info-item {
    display: flex;
    flex-direction: column;
}

.info-item label {
    margin-bottom: 0.25rem;
}

/* Hover effects for port stat boxes */
.hover-highlight {
    cursor: pointer;
    transition: all 0.3s ease;
}

.hover-highlight:hover {
    transform: translateY(-2px);
}

/* Port item styling */
.port-item {
    transition: all 0.3s ease;
}
</style>
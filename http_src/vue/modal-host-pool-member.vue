<!-- Host Pool Member Modal -->
<template>
    <modal ref="modal_id">
        <template v-slot:title>
            {{ isEditMode ? _i18n("host_pools.edit_host_pool_member") : _i18n("host_pools.add_host_pool_member") }}
        </template>
        <template v-slot:body>
            <!-- Member Type Selection -->
            <div class="mb-3">
                <label class="form-label fw-bold">{{ _i18n("host_pools.member_type") }}</label>
                <div class="btn-group w-100" role="group">
                    <input type="radio" class="btn-check" id="ip-radio" value="ip" v-model="memberType" @change="onMemberTypeChange">
                    <label class="btn btn-outline-primary" for="ip-radio">{{ _i18n("host_pools.ipv4") }}/{{ _i18n("host_pools.ipv6") }}</label>
                    
                    <input type="radio" class="btn-check" id="network-radio" value="network" v-model="memberType" @change="onMemberTypeChange">
                    <label class="btn btn-outline-primary" for="network-radio">{{ _i18n("network") }}</label>
                    
                    <input type="radio" class="btn-check" id="mac-radio" value="mac" v-model="memberType" @change="onMemberTypeChange">
                    <label class="btn btn-outline-primary" for="mac-radio">{{ _i18n("host_pools.mac_filter") }}</label>
                </div>
            </div>

            <!-- IP Address Fields -->
            <div v-show="memberType === 'ip'" class="ip-fields">
                <div class="mb-3">
                    <label for="ip_address" class="form-label fw-bold">{{ _i18n("ip_address") }}</label>
                    <input 
                        id="ip_address" 
                        type="text" 
                        class="form-control" 
                        :class="{ 'is-invalid': ipAddressError }"
                        v-model="ipAddress" 
                        :placeholder="_i18n('enter_ip_address')" 
                        @input="validateIpAddress"
                        @keyup.enter="handleSubmit"
                    />
                    <div v-if="ipAddressError" class="invalid-feedback">
                        {{ ipAddressError }}
                    </div>
                </div>
                <div class="mb-3">
                    <label for="ip_vlan" class="form-label fw-bold">{{ _i18n("vlan") }}</label>
                    <input 
                        id="ip_vlan" 
                        type="text" 
                        class="form-control" 
                        :class="{ 'is-invalid': ipVlanError }"
                        v-model.number="ipVlan" 
                        placeholder="0"
                        min="0"
                        max="4094"
                        @input="validateIpVlan"
                        @keyup.enter="handleSubmit"
                    />
                    <div v-if="ipVlanError" class="invalid-feedback">
                        {{ ipVlanError }}
                    </div>
                </div>
            </div>

            <!-- Network Fields -->
            <div v-show="memberType === 'network'" class="network-fields">
                <div class="mb-3">
                    <label for="network_address" class="form-label fw-bold">{{ _i18n("network") }}</label>
                    <input 
                        id="network_address" 
                        type="text" 
                        class="form-control" 
                        :class="{ 'is-invalid': networkAddressError }"
                        v-model="networkAddress" 
                        :placeholder="_i18n('enter_network_address')" 
                        @input="validateNetworkAddress"
                        @keyup.enter="handleSubmit"
                    />
                    <div v-if="networkAddressError" class="invalid-feedback">
                        {{ networkAddressError }}
                    </div>
                </div>
                <div class="mb-3">
                    <label for="cidr" class="form-label fw-bold">{{ _i18n("cidr") }}</label>
                    <input 
                        id="cidr" 
                        type="number" 
                        class="form-control" 
                        :class="{ 'is-invalid': cidrError }"
                        v-model.number="cidr" 
                        :placeholder="_i18n('enter_cidr')"
                        min="1"
                        :max="isIPv6Network ? 128 : 32"
                        @input="validateCidr"
                        @keyup.enter="handleSubmit"
                    />
                    <div v-if="cidrError" class="invalid-feedback">
                        {{ cidrError }}
                    </div>
                </div>
                <div class="mb-3">
                    <label for="network_vlan" class="form-label fw-bold">{{ _i18n("vlan") }}</label>
                    <input 
                        id="network_vlan" 
                        type="number" 
                        class="form-control" 
                        :class="{ 'is-invalid': networkVlanError }"
                        v-model.number="networkVlan" 
                        placeholder="0"
                        min="0"
                        max="4094"
                        @input="validateIpVlan"
                        @keyup.enter="handleSubmit"
                    />
                    <div v-if="networkVlanError" class="invalid-feedback">
                        {{ networkVlanError }}
                    </div>
                </div>
            </div>

            <!-- MAC Address Fields -->
            <div v-show="memberType === 'mac'" class="mac-fields">
                <div class="mb-3">
                    <label for="mac_address" class="form-label fw-bold">{{ _i18n("mac_address") }}</label>
                    <input 
                        id="mac_address" 
                        type="text" 
                        class="form-control" 
                        :class="{ 'is-invalid': macAddressError }"
                        v-model="macAddress" 
                        :placeholder="_i18n('enter_mac_address')" 
                        @input="validateMacAddress"
                        @keyup.enter="handleSubmit"
                    />
                    <div v-if="macAddressError" class="invalid-feedback">
                        {{ macAddressError }}
                    </div>
                </div>
            </div>

            <!-- Error feedback -->
            <div v-if="generalError" class="alert alert-danger">
                {{ generalError }}
            </div>
        </template>
        
        <template v-slot:footer>
            <div class="d-flex justify-content-end w-100">
                <button type="button" @click="handleSubmit" class="btn btn-primary" :disabled="!isFormValid">
                    {{ isEditMode ? _i18n("save") : _i18n("add") }}
                </button>
            </div>
        </template>
    </modal>
</template>

<script setup>
import { ref, computed, nextTick } from "vue";
import { default as modal } from "./modal.vue";

const _i18n = (t) => i18n(t);

const modal_id = ref(null);

// Define emits for add and edit operations
const emit = defineEmits(["add", "edit"]);

// Member type and form fields
const memberType = ref("ip");
const ipAddress = ref("");
const ipVlan = ref(0);
const networkAddress = ref("");
const cidr = ref(24);
const networkVlan = ref(0);
const macAddress = ref("");

// Error states
const ipAddressError = ref("");
const ipVlanError = ref("");
const networkAddressError = ref("");
const cidrError = ref("");
const networkVlanError = ref("");
const macAddressError = ref("");
const generalError = ref("");

// Track edit mode and current item
const isEditMode = ref(false);
const currentItem = ref(null);

const props = defineProps({
    context: Object,
});

// Regex patterns for validation
const IPV4_REGEX = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
const IPV6_REGEX = /^(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|^::1$|^::$/;
const MAC_REGEX = /^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/;

// Computed properties
const isIPv6Network = computed(() => {
    return networkAddress.value && isValidIPv6(networkAddress.value);
});

const isFormValid = computed(() => {
    if (memberType.value === "ip") {
        return ipAddress.value && !ipAddressError.value && !ipVlanError.value;
    } else if (memberType.value === "network") {
        return networkAddress.value && cidr.value && !networkAddressError.value && !cidrError.value && !networkVlanError.value;
    } else if (memberType.value === "mac") {
        return macAddress.value && !macAddressError.value;
    }
    return false;
});

// Validation functions
const isValidIPv4 = (ip) => IPV4_REGEX.test(ip);
const isValidIPv6 = (ip) => IPV6_REGEX.test(ip);
const isValidMAC = (mac) => MAC_REGEX.test(mac);

const validateIpAddress = () => {
    const trimmed = ipAddress.value.trim();
    if (!trimmed) {
        ipAddressError.value = _i18n("host_pools.invalid_member");
    } else if (!isValidIPv4(trimmed) && !isValidIPv6(trimmed)) {
        ipAddressError.value = _i18n("host_pools.invalid_member");
    } else {
        ipAddressError.value = "";
    }
};

const validateIpVlan = () => {
    const value = ipVlan.value;
    const isInteger = /^\d+$/.test(value);
    const hasLeadingZero = value.length > 1 && value[0] === "0";
    const num = Number(value);

    if (!isInteger || hasLeadingZero || num < 0 || num > 4094) {
        ipVlanError.value = _i18n("host_pools.invalid_vlan");
    } else {
        ipVlanError.value = "";
    }
};


const validateNetworkAddress = () => {
    const trimmed = networkAddress.value.trim();
    if (!trimmed) {
        networkAddressError.value = _i18n("host_pools.network_address_required");
    } else if (!isValidIPv4(trimmed) && !isValidIPv6(trimmed)) {
        networkAddressError.value = _i18n("host_pools.invalid_network_address");
    } else {
        networkAddressError.value = "";
    }
};

const validateCidr = () => {
    const maxCidr = isIPv6Network.value ? 128 : 32;
    if (!cidr.value || cidr.value < 1 || cidr.value > maxCidr) {
        cidrError.value = _i18n("host_pools.invalid_cidr_range", { max: maxCidr });
    } else {
        cidrError.value = "";
    }
};

const validateMacAddress = () => {
    const trimmed = macAddress.value.trim();
    if (!trimmed) {
        macAddressError.value = _i18n("host_pools.mac_required");
    } else if (!isValidMAC(trimmed)) {
        macAddressError.value = _i18n("host_pools.invalid_mac");
    } else {
        macAddressError.value = "";
    }
};

// Clear all errors
const clearErrors = () => {
    ipAddressError.value = "";
    ipVlanError.value = "";
    networkAddressError.value = "";
    cidrError.value = "";
    networkVlanError.value = "";
    macAddressError.value = "";
    generalError.value = "";
};

// Handle member type change
const onMemberTypeChange = () => {
    clearErrors();
};

// Reset form
const resetForm = () => {
    memberType.value = "ip";
    ipAddress.value = "";
    ipVlan.value = 0;
    networkAddress.value = "";
    cidr.value = 24;
    networkVlan.value = 0;
    macAddress.value = "";
    clearErrors();
    isEditMode.value = false;
    currentItem.value = null;
};

// Handle form submission
const handleSubmit = () => {
    // Validate current fields
    if (memberType.value === "ip") {
        validateIpAddress();
        validateIpVlan();
    } else if (memberType.value === "network") {
        validateNetworkAddress();
        validateCidr();
        validateIpVlan();
    } else if (memberType.value === "mac") {
        validateMacAddress();
    }

    if (!isFormValid.value) {
        return;
    }

    // Prepare member data based on type
    let member;
    if (memberType.value === "mac") {
        member = macAddress.value.trim();
    } else if (memberType.value === "ip") {
        const ip = ipAddress.value.trim();
        const vlan = ipVlan.value || 0;
        const cidrValue = isValidIPv6(ip) ? 128 : 32;
        member = `${ip}/${cidrValue}@${vlan}`;
    } else { // network
        const network = networkAddress.value.trim();
        const cidrValue = cidr.value;
        const vlan = networkVlan.value || 0;
        member = `${network}/${cidrValue}@${vlan}`;
    }

    const formData = {
        member_type: memberType.value,
        member: member,
        pool: props.context?.selectedPool?.id
    };

    if (isEditMode.value) {
        emit('edit', {
            ...formData,
            old_member: currentItem.value.member,
            item: currentItem.value
        });
    } else {
        emit('add', formData);
    }

    close();
};

// Show modal for adding new item
const show = () => {
    resetForm();
    modal_id.value.show();
};

// Show modal for editing existing item
const showEdit = async (item) => {
    resetForm();
    
    isEditMode.value = true;
    currentItem.value = item;
    
    // Parse the item data based on type
    if (item.type === "mac") {
        memberType.value = "mac";
        macAddress.value = item.name;
    } else if (item.type === "ip") {
        memberType.value = "ip";
        ipAddress.value = item.name;
        ipVlan.value = item.vlan || 0;
    } else { // network
        memberType.value = "network";
        const parts = item.name.split('/');
        if (parts.length === 2) {
            networkAddress.value = parts[0];
            cidr.value = parseInt(parts[1]);
        }
        networkVlan.value = item.vlan || 0;
    }

    await nextTick();
    
    if (!modal_id.value) {
        console.error('Modal reference is null after nextTick');
        return;
    }

    modal_id.value.show();
};

const close = () => {
    modal_id.value.close();
};

// Handle general error display
const showError = (error) => {
    generalError.value = error;
};

// Expose methods
defineExpose({ show, showEdit, close, showError });
</script>
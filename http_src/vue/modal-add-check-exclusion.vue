<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{ _i18n("check_exclusion.add_exclusion") }}</template>
  <template v-slot:body>    
    <template v-if="alert_exclusions_page == 'hosts'"> <!-- modal hosts -->
      <div class="mb-3 row">
	<label class="col-form-label col-sm-4" >
	  <b>{{ _i18n("check_exclusion.member_type") }}</b>
	</label>
	<div class="col-sm-6">
	  <div class="btn-group btn-group-toggle" data-bs-toggle="buttons">
	    <label :class="{'active': exclude_type == 'ip'}" class="btn btn-secondary">
	      <input  class="btn-check" type="radio" name="member_type" value="ip" @click="set_exclude_type('ip')"> {{ _i18n("check_exclusion.ip_address") }}
	    </label>
	    <label :class="{'active': exclude_type == 'network'}" class="btn btn-secondary">
	      <input @click="set_exclude_type('network')" class="btn-check"  type="radio" name="member_type" value="network"> {{ _i18n("check_exclusion.network") }}
	    </label>
	  </div>
	</div>
      </div>
      <hr>
      
      <div class="host-alert-fields">
	<div class="mb-3 row">
    	  <label class="col-form-label col-sm-4" >
    	    <b>{{ _i18n("check_exclusion.host_alert_type") }}</b>
    	  </label>
          <div class="col-sm-6">
            <select name="value" class="form-select alert-select" v-model="host_selected">
              <option value="">{{ _i18n("check_exclusion.none") }}</option>
              <option value="0">{{ _i18n("check_exclusion.exclude_all_alerts") }}</option>
              <option disabled>{{ _i18n("check_exclusion.spacing_bar") }}</option>
	      <template v-for="item in host_alert_types">
		<option v-if="item != null" :value="item.alert_id">{{ item.label }}</option>
	      </template>
            </select>
          </div>
	</div>
      </div>
      
      <div class="flow-alert-fields">
	<div class="mb-3 row">
          <label class="col-form-label col-sm-4" >
            <b>{{ _i18n("check_exclusion.flow_alert_type") }}</b>
          </label>
          <div class="col-sm-6">
            <select id="flow-alert-select" name="value" class="form-select alert-select" v-model="flow_selected">
              <option value="">{{ _i18n("check_exclusion.none") }}</option>
              <option value="0">{{ _i18n("check_exclusion.exclude_all_alerts") }}</option>
              <option disabled>{{ _i18n("check_exclusion.spacing_bar") }}</option>
	      <template v-for="item in flow_alert_types">
		<option  v-if="item != null" :value="item.alert_id">{{ item.label }}</option>
	      </template>
            </select>
          </div>
	</div>
      </div>
      
      <div v-if="exclude_type == 'ip'" class="ip-fields">
	<div class="mb-3 row">
          <label class="col-form-label col-sm-4" >
            <b>{{ _i18n("check_exclusion.ip_address") }}</b>
          </label>
          <div class="col-sm-6">
            <input :pattern="pattern_ip" placeholder="192.168.1.1" required type="text" name="ip_address" class="form-control" v-model="input_ip" />
          </div>
	</div>
      </div>
      
      <div v-if="exclude_type == 'network'" class="network-fields">
	<div class="mb-3 row">
          <label class="col-form-label col-sm-4" >
            <b>{{ _i18n("check_exclusion.network") }}</b>
          </label>
          <div class="col-sm-4 pr-0">
            <input required style="width: calc(100% - 10px);" name="network" class="form-control d-inline" placeholder="172.16.0.0" :pattern="pattern_ip" v-model="input_network"/>
    	  </div>
    	  <div class="col-sm-2 ps-4 pe-0">
    	    <span class="me-2">/</span>
    	    <input placeholder='24' required class="form-control d-inline w-75" min="1" max="127" type="number" name="cidr" v-model="netmask">
    	  </div>
	</div>
      </div>

      <div class="mb-3 row">
        <label class="col-form-label col-sm-4" >
          <b>{{ _i18n('vlan') }}</b>
        </label>
        <div class="col-sm-6">
          <input placeholder="0" min="0" type="number" v-model="input_vlan" class="form-control"/>
        </div>
      </div>      
    </template> <!-- mdoal hosts -->
    
    <template v-if="alert_exclusions_page != 'hosts'"> <!-- modal domain_names-->
      <div>
	<div class="mb-3 row">
          <label class="col-form-label col-sm-4" >
            <b v-if="alert_exclusions_page == 'domain_names'">{{ _i18n("check_exclusion.domain") }}</b>
            <b v-if="alert_exclusions_page == 'tls_certificate'">{{ _i18n("check_exclusion.tls_certificate") }}</b>
          </label>
          <div class="col-sm-6">
            <input v-if="alert_exclusions_page == 'domain_names'" placeholder="" :pattern="pattern_text" required type="text" name="ip_address" class="form-control" v-model="input_text" />
            <input v-if="alert_exclusions_page == 'tls_certificate'" placeholder="CN=813845657003339838, O=Code42, OU=TEST, ST=MN, C=U" :pattern="pattern_certificate" required type="text" name="ip_address" class="form-control" v-model="input_text" />
          </div>
	</div>
      </div>      
    </template> <!-- modal domain_names-->

  </template>
  <template v-slot:footer>
    <button type="button" :disabled="check_disable_apply()" @click="add" class="btn btn-primary">{{_i18n('add')}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const exclude_type = ref("ip");
const input_ip = ref("");
const input_network = ref("");
const input_vlan = ref(0);
const input_text = ref("");
const host_selected = ref("");
const flow_selected = ref("");
const netmask = ref("");

const emit = defineEmits(['add'])
//s.split(",").every((a) => {return /.+=.+/.test(a)})
function get_data_pattern(value_type) {
    if (value_type == "text") {
	return NtopUtils.REGEXES.domain_name_not_strict;
    } else if (value_type == "ip") {
	let r_ipv4 = NtopUtils.REGEXES.ipv4;
	let r_ipv4_vlan = r_ipv4.replace("$", "@[0-9]{0,5}$");
	let r_ipv6 = NtopUtils.REGEXES.ipv6;
	let r_ipv6_vlan = r_ipv6.replaceAll("$", "@[0-9]{0,5}$");
	return `(${r_ipv4})|(${r_ipv4_vlan})|(${r_ipv6})|(${r_ipv6_vlan})`;
    } else if (value_type == "hostname") {
	return `${NtopUtils.REGEXES.singleword}|[a-zA-Z0-9._\-]{3,250}@[0-9]{0,5}$`;
    } else if (value_type == "certificate") {
	return NtopUtils.REGEXES.tls_certificate;
    }
    return NtopUtils.REGEXES[value_type];
}

const props = defineProps({
    alert_exclusions_page: String,
    host_alert_types: Array,
    flow_alert_types: Array,    
});

let pattern_ip = get_data_pattern("ip");
let pattern_text = get_data_pattern("text");
let pattern_certificate = get_data_pattern("certificate");

const set_exclude_type = (type) => {
    exclude_type.value = type;
}

const check_disable_apply = () => {
    let regex = null;
    let disable_apply = true;
    if (props.alert_exclusions_page == 'hosts') {
	regex = new RegExp(pattern_ip);
	if (exclude_type.value == "ip") {
	    disable_apply = (input_ip.value == null || input_ip.value == "") || (regex.test(input_ip.value) == false) || (host_selected.value == "" && flow_selected.value == "");
	} else {
	    disable_apply = (input_network.value == null || input_network.value == "")
		|| (regex.test(input_network.value) == false)
		|| (host_selected.value == "" && flow_selected.value == "")
		|| (netmask.value == null || netmask.value == "" || parseInt(netmask.value) < 1 || parseInt(netmask.value) > 127);
	}
    } else if (props.alert_exclusions_page == 'domain_names') {
	regex = new RegExp(pattern_text);
	disable_apply = (input_text.value == null || input_text.value == "") || (regex.test(input_text.value) == false);
	
    } else if (props.alert_exclusions_page == 'tls_certificate') {
	regex = new RegExp(pattern_certificate);
	disable_apply = (input_text.value == null || input_text.value == "") || (regex.test(input_text.value) == false);
    }
    return disable_apply;
};

const showed = () => {};

const show = () => {
    exclude_type.value = "ip";
    input_ip.value = "";
    input_network.value = "";
    input_vlan.value = 0;
    host_selected.value = "";
    flow_selected.value = "";
    netmask.value = "";
    input_text.value = "";
    modal_id.value.show();
};

const close = () => {
    modal_id.value.close();
};

const add = () => {
    let params;
    let alert_addr = input_ip.value;
    if (props.alert_exclusions_page == "hosts") {
	if (exclude_type.value == "network") {
	    alert_addr = `${input_network.value}/${netmask.value}`;
	}
        if (input_vlan.value != null && input_vlan.value != 0) {
	    alert_addr = `${alert_addr}@${input_vlan.value}`;
        }
	params = { alert_addr, host_alert_key: host_selected.value, flow_alert_key: flow_selected.value };
    } else if (props.alert_exclusions_page == "domain_names") {
	params = { alert_domain: input_text.value };
    } else if (props.alert_exclusions_page == "tls_certificate") {
	params = { alert_certificate: input_text.value };
    }
    emit('add', params);
    close();
};

defineExpose({ show, close });

onMounted(() => {
});

const _i18n = (t) => i18n(t);

</script>

<style scoped>
input:invalid {
  border-color: #ff0000;
}  
</style>

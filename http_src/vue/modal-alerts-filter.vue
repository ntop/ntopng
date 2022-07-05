<!-- (C) 2022 - ntop.org     -->
<template>
<modal @showed="showed()" ref="modal_id">
  <template v-slot:title>{{ _i18n('current_filter') }}: <span v-html="alert_name"></span></template>
  <template v-slot:body>
    <div class="form-group mb-3 ">
      <div>
	<label>{{ _i18n('current_filter') }} "<b v-html="alert_name"></b>". <span class="alert_label">{{ _i18n('current_filter_for') }}:</span> </label>
	<div class="form-check">
      	  <input class="form-check-input" type="radio" value="any" v-model="radio_selected">
      	  <label class="form-check-label">
      	    <span> {{ _i18n('show_alerts.filter_disable_check') }} </span>
      	  </label>
	</div>
	<template v-if="page == 'host'">
	  <div class="form-check">
      	    <input class="form-check-input" type="radio" value="host" v-model="radio_selected">
      	    <label class="form-check-label">
      	      <span>{{ host_addr.label }}</span>
      	    </label>
	  </div>	
	</template>
	<template v-if="page == 'flow'">
	  <div class="form-check">
      	    <input class="form-check-input" type="radio" value="client_host" v-model="radio_selected">
      	    <label class="form-check-label">
      	      <span>{{ _i18n('client') }}: {{flow_addr.cli_label}}</span>
      	    </label>
	  </div>
	  <div class="form-check">
      	    <input class="form-check-input" type="radio" value="server_host" v-model="radio_selected">
      	    <label class="form-check-label">
      	      <span>{{ _i18n('server') }}: {{ flow_addr.srv_label }}</span>
      	    </label>
	  </div>
	</template>
      </div>
      <div v-if="domain != null || tls_certificate != null" class="exclude-domain-certificate">
	<label><span class="alert_label">{{ _i18n('check_exclusion.exclude_all_checks_for') }}:</span> </label>	
	<div v-if="domain != null" class="form-check">
      	  <input class="form-check-input" type="radio" value="domain" v-model="radio_selected">
      	  <label class="form-check-label whitespace">
      	    <span>{{_i18n("check_exclusion.domain")}}:</span>
      	  </label>
      	  <input type="text" :pattern="pattern_domain" :disabled="radio_selected != 'domain'" required v-model="domain" class="form-check-label custom-width">
	</div>
	<div v-if="tls_certificate != null" class="form-check">
      	  <input class="form-check-input" type="radio" value="certificate" v-model="radio_selected">
      	  <label class="form-check-label whitespace">
      	    <span>{{_i18n("check_exclusion.tls_certificate")}}:</span>
      	  </label>
      	  <input type="text" :disabled="radio_selected != 'certificate'" v-model="tls_certificate" :pattern="pattern_certificate" required class="form-check-label custom-width">
	</div>
      </div>
    </div>
    <template v-if="radio_selected != 'domain' && radio_selected != 'certificate'">
      <div v-show="disable_alerts" class="message alert alert-danger">
	{{ _i18n("show_alerts.confirm_delete_filtered_alerts") }}
      </div>
      <hr class="separator">
      <div class="form-group mb-3 ">
	<div class="custom-control custom-switch">
	  <input type="checkbox" class="custom-control-input whitespace"  v-model="disable_alerts">
	  
	  <label class="custom-control-label">{{_i18n("delete_disabled_alerts")}}</label>
	</div>
      </div>
    </template>
    <div  class="alert alert-warning border" role="alert">
      {{_i18n("show_alerts.confirm_filter_alert")}}
    </div>
  </template><!-- modal-body -->
  
  <template v-slot:footer>
    <button type="button" @click="exclude" :disabled="check_disable_apply()" class="btn btn-warning">{{_i18n("filter")}}</button>
  </template>
</modal>
</template>

<script setup>
import { ref, onMounted, computed, watch } from "vue";
import { default as modal } from "./modal.vue";

const modal_id = ref(null);
const radio_selected = ref("any");
const disable_alerts = ref(true);
const domain = ref(null);
const tls_certificate = ref(null);

const emit = defineEmits(['exclude'])

const showed = () => {};

const props = defineProps({
    alert: Object,
    page: String,
});

watch(() => props.alert, (current_value, old_value) => {
    if (current_value == null) { return; }
    radio_selected.value = "any";
    disable_alerts.value = true;
    domain.value = current_value.info?.value == "" ? null : current_value.info?.value;
    tls_certificate.value = current_value.info?.issuerdn == "" ? null : current_value.info?.issuerdn;
});
// const click_delete_disable_alerts = () => {
// };

const check_disable_apply = () => {
    if (radio_selected.value == "domain") {
	let regex_domain = new RegExp(pattern_domain);
	return domain.value == null || regex_domain.test(domain.value) == false;
    } else if (radio_selected.value == "certificate") {
	let regex_certificate = new RegExp(pattern_certificate);
	return tls_certificate.value == null || regex_certificate.test(tls_certificate.value) == false;
    }
    return false;
}

const alert_name = computed(() => props.alert?.alert_name);

const host_addr = computed(() => {
    let res = { value: "", label: "" };
    if (props.page != "host" || props.alert == null) { return res; }
    let alert = props.alert;
    res.value = alert.ip.value;
    if (alert.vlan != null && alert.vlan.value != null && alert.vlan.value != 0) {
	res.value = res.value + '@' + alert.vlan.value;
    }
    res.label = (alert.ip.label) ? `${alert.ip.label} (${alert.ip.value})` : alert.ip.value;
    return res;
});

const flow_addr = computed(() => {
    let res = { cli_value: "", cli_label: "", srv_value: "", srv_label: "" };
    if (props.page != "flow" || props.alert == null) { return res; }
    let alert = props.alert;
    res.cli_value = alert.flow.cli_ip.value;
    res.srv_value = alert.flow.srv_ip.value;
    if(alert.flow.vlan != null && alert.flow.vlan.value != null && alert.flow.vlan.value != 0) {
        res.cli_value = res.cli_value + '@' + alert.flow.vlan.value
        res.srv_value = res.srv_value + '@' + alert.flow.vlan.value
    }
    
    res.cli_label = (alert.flow.cli_ip.label) ? `${alert.flow.cli_ip.label} (${res.cli_value})` : res.cli_value;
    res.srv_label = (alert.flow.srv_ip.label) ? `${alert.flow.srv_ip.label} (${res.srv_value})` : res.srv_value;
    return res;
});

const show = () => {
    modal_id.value.show();
};

function get_type() {
    if (radio_selected.value == "domain" || radio_selected.value == "certificate") {
	return radio_selected.value;
    }
    return "host";
}

let pattern_domain = NtopUtils.REGEXES.domain_name_not_strict;
let pattern_certificate = NtopUtils.REGEXES.tls_certificate;

const exclude = () => {
    let page = props.page;
    let type = get_type();
    let params = {
    	delete_alerts: disable_alerts.value,
	type,	
    };
    let addr = null;
    if (type == "host") {	
	if (radio_selected.value == "host") {
	    addr = host_addr.value.value;
	} else if (radio_selected.value == "server_host") {
	    addr = flow_addr.value.srv_value;
	} else if (radio_selected.value == "client_host") {
	    addr = flow_addr.value.cli_value;
	}
	params.alert_addr = addr;
	if (page == "flow") {
	    params.flow_alert_key = props.alert.alert_id.value;
	} else if (page == "host") {
	    params.host_alert_key = props.alert.alert_id.value;
	}
    } else if (type == "domain") {
	params.delete_alerts = false;
	params.alert_domain = domain.value;
    } else if (type == "certificate") {
	params.delete_alerts = false;
	params.alert_certificate = tls_certificate.value;
    }
    close();
    emit('exclude', params);
};

const close = () => {
    modal_id.value.close();
};


defineExpose({ show, close });

onMounted(() => {
});

const _i18n = (t) => i18n(t);

</script>

<style scoped>
.whitespace {
  margin-right: 0.2rem;
}
.custom-width {
  display: block;
  min-width: 100%;
}
input:invalid {
  border-color: #ff0000;
}
.exclude-domain-certificate {
  margin-top: 0.4rem;
}
</style>

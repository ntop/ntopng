<template>
<modal :id="id_modal" @apply="apply" ref="modal">
  <template v-slot:title>{{i18n('traffic_recording.pcap_extract')}}</template>
  <template v-slot:body>
    
    <div class="alert" :class="{ 'alert-info': data_available != 2, 'alert-warning': data_available == 2 }" v-html="description"></div>
    <form v-if="data_available == 1" style="height:95%;">
      <div class="tab-content" style="height:100%;">
        <div class="row">
          <div class="form-group mb-3 col-md-3 has-feedback">
	    <button class="btn btn-sm btn-secondary" type="button" @click="show_hide_menu">{{i18n('advanced')}}<i :class="{ 'fas fa-caret-down': show_menu, 'fas fa-caret-up': !show_menu}"></i></button>
          </div>
	  
	  <div class="form-group mb-3 col-md-9 text-right asd">
	    <label class="radio-inline" style="margin-left: 1rem;"><input type="radio" name="extract_now" v-model="extract_now"  value="true" checked=""> {{i18n('traffic_recording.extract_now')}} </label>
	    <label class="radio-inline"><input type="radio" name="extract_now" v-model="extract_now" value="false"> {{i18n('traffic_recording.queue_as_job')}} </label>
	  </div>
        </div>
	
        <div v-show="show_menu" class="row" id="pcapDownloadModal_advanced" style="">
          <div class="form-group mb-3 col-md-12 has-feedback">
	    <br>
            <label class="form-label">{{i18n('traffic_recording.filter_bpf')}} <a class="ntopng-external-link" href="https://www.ntop.org/guides/n2disk/filters.html"><i class="fas fa-external-link-alt"></i></a></label>
            <div class="input-group">
	      <span class="input-group-addon"><span class="glyphicon glyphicon-filter"></span></span>
	      <input name="bpf_filter" v-model="bpf_filter" class="form-control input-sm" data-bpf="bpf" autocomplete="off" spellcheck="false">
	      <span v-show="invalid_bpf" style="margin: 0px;padding:0;display:block;" class="invalid-feedback ">{{i18n('invalid_value')}}</span>
            </div>
	    <br>
	    <label class="form-label">{{i18n('traffic_recording.filter_examples')}}:</label>
	    <br>
	    <ul>
	      <li>Host: <i>host 192.168.1.2</i></li>
	      <li>HTTP: <i>tcp and port 80</i></li>
	      <li>Traffic between hosts: <i>ip host 192.168.1.1 and 192.168.1.2</i></li>
	      <li>Traffic from an host to another: <i>ip src 192.168.1.1 and dst 192.168.1.2</i></li>
	    </ul>
          </div>
        </div>
      </div>
    </form>
  </template>
  
  <template v-slot:footer>
    <button v-show="data_available != 2" type="button" @click="apply" class="btn btn-primary">{{i18n('apply')}}</button>
    <button v-show="data_available == 2" type="button" @click="close" class="btn btn-primary">{{i18n('ok')}}</button>
  </template>  
</modal>  
</template>

<script type="text/javascript">
import { defineComponent } from 'vue';
import { default as Modal } from "./modal.vue"
export default defineComponent({
    components: {
	'modal': Modal,
    },
    props: {
	id: String,
    },
    updated() {
    },
    data() {
	return {
	    description: "",
	    invalid_bpf: false,
	    bpf_filter: "",
	    extract_now: true,
	    show_menu: true,
	    data_available: 0, // 0 == loading, 1 == available, 2 == no data
	    i18n: (t) => i18n(t),
	    epoch_interval: null,
	    id_modal: `${this.$props.id}_modal`,
	};
    },
    emits: ["apply"],
    created() {
    },
    /** This method is the first method called after html template creation. */
    mounted() {
    },
    methods: {
	pad2_number: function(number) {
	    return String(number).padStart(2, '0');
	},
	format_date: function(d) {
	    // let day = this.pad2_number(d.getDate());
	    // let month = this.pad2_number(d.getMonth());
	    // let hours = this.pad2_number(d.getHours());
	    // let minutes = this.pad2_number(d.getMinutes());
	    // let s = `${day}/${month}/${d.getFullYear()} ${hours}:${minutes}`;
	    let d_ms = d.valueOf();
	    return ntopng_utility.from_utc_to_server_date_format(d_ms);
	},
	apply: async function() {
	    if (this.bpf_filter != null && this.bpf_filter != "") {
		let url_request = `${http_prefix}/lua/pro/rest/v2/check/filter.lua?query=${this.bpf_filter}`;
		let res = await ntopng_utility.http_request(url_request, null, false, true);
		this.invalid_bpf = !res.response;
		if (this.invalid_bpf == true) {
		    return;
		}		
	    }
	    let url_request_obj = {
		ifid: ntopng_url_manager.get_url_entry("ifid"),
		epoch_begin: this.epoch_interval.epoch_begin,
		epoch_end: this.epoch_interval.epoch_end,
		bpf_filter: this.bpf_filter,
	    };
	    let url_request_params = ntopng_url_manager.obj_to_url_params(url_request_obj);
	    if (this.extract_now == true) {
		
		let url_request = `${http_prefix}/lua/rest/v2/get/pcap/live_extraction.lua?${url_request_params}`;
		window.open(url_request, '_self', false);
	    } else {
		let url_request = `${http_prefix}/lua/traffic_extraction.lua?${url_request_params}`;
		let resp = await ntopng_utility.http_request(url_request, null, false, true);
		let job_id = resp.id;
		//let job_id = 2;
		let alert_text_html = i18n('traffic_recording.extraction_scheduled');
		let page_name = i18n('traffic_recording.traffic_extraction_jobs');
		let ifid = ntopng_url_manager.get_url_entry("ifid");
		let href = `<a href="/lua/if_stats.lua?ifid=${ifid}&page=traffic_recording&tab=jobs&job_id=${job_id}">${page_name}</a>`; 
		alert_text_html = alert_text_html.replace('%{page}', href);
		alert_text_html = `${alert_text_html} ${job_id}`;
		ntopng_events_manager.emit_custom_event(ntopng_custom_events.SHOW_GLOBAL_ALERT_INFO, { text_html: alert_text_html, type: "alert-success" });
	    }
	    this.close();
	},
	close: function() {
	    this.$refs["modal"].close();
	    setTimeout(() => {
		this.data_available = 0;
	    }, 1000);
	},
	show: async function(bpf_filter, epoch_interval) {	    
	    if (epoch_interval == null) {
		let status = ntopng_status_manager.get_status();
		if (status.epoch_begin == null || status.epoch_end == null) {
		    console.error("modal-traffic-extraction: epoch_begin and epoch_end undefined in url");
		    return;
		}
		epoch_interval = { epoch_begin: status.epoch_begin, epoch_end: status.epoch_end };
	    }
	    this.epoch_interval = epoch_interval;
	    let url_params = ntopng_url_manager.obj_to_url_params(epoch_interval);
	    let url_request = `${http_prefix}/lua/check_recording_data.lua?${url_params}`;
	    let res = await ntopng_utility.http_request(url_request, null, null, true);
	    if (res.available == false) {
		this.data_available = 2;
		this.description = i18n('traffic_recording.no_recorded_data');
		this.$refs["modal"].show();
		return;
	    }
	    this.data_available = 1;
	    let extra_info = "";
	    if (res.info != null) {
		extra_info = res.info;
	    };
	    if (bpf_filter == null) {
		let url_params = ntopng_url_manager.get_url_params();
		let url_request = `${http_prefix}/lua/pro/rest/v2/get/db/filter/bpf.lua?${url_params}`;
		let res = await ntopng_utility.http_request(url_request);
		if (res == null || res.bpf == null) {
		    console.error(`modal-traffic-extraction: ${url_request} return null value`);
		    return;
		}
		bpf_filter = res.bpf;
	    }
	    this.set_descriptions(epoch_interval.epoch_begin, epoch_interval.epoch_end, extra_info);
	    
	    // let url_params = ntopng_url_manager.get_url_params();
	    // let url_request = `${http_prefix}/lua/pro/rest/v2/get/db/filter/bpf.lua?${url_params}`;
	    // let res = await ntopng_utility.http_request(url_request);
	    // this.bpf_filter = res.bpf;
	    this.bpf_filter = bpf_filter;
	    this.$refs["modal"].show();
	},
	set_descriptions: function(epoch_begin, epoch_end, info) {
	    let date_begin = new Date(epoch_begin * 1000);
	    let date_end = new Date(epoch_end * 1000);
	    
	    let desc = i18n('traffic_recording.about_to_download_flow');
	    desc = desc.replace('%{date_begin}', this.format_date(date_begin));
	    desc = desc.replace('%{date_end}', this.format_date(date_end));
	    desc = desc.replace('%{extra_info}', info);
	    this.description = desc;
	},
	show_hide_menu: function() {
	    this.show_menu = !this.show_menu;
	},
    },
});

</script>

<style scoped>
input ~ .alert {
  display: none;
}
input:invalid ~ .alert {
  display: block;
}
</style>

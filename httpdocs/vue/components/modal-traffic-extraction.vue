<template>
<modal :id="id_modal" @apply="apply" ref="modal">
  <template v-slot:title>{{i18n('traffic_recording.pcap_extract')}}</template>
  <template v-slot:body>
    
    <div class="alert alert-info" v-html="description"></div>
    <form style="height:95%;">
      <div class="tab-content" style="height:100%;">	
        <div class="row">
          <div class="form-group mb-3 col-md-3 has-feedback">
	    <button class="btn btn-sm btn-secondary" type="button" @click="show_hide_menu">{{i18n('advanced')}}<i :class="{ 'fas fa-caret-down': show_menu, 'fas fa-caret-up': !show_menu}"></i></button>
          </div>
	  
	  <div class="form-group mb-3 col-md-9 text-right asd">
	    <label class="radio-inline"><input type="radio" name="extract_now" v-model="extract_now"  value="true" checked="">{{i18n('traffic_recording.extract_now')}}</label>
	    <label class="radio-inline"><input type="radio" name="extract_now" v-model="extract_now" value="false">{{i18n('traffic_recording.queue_as_job')}}</label>
	  </div>
        </div>
	
        <div v-show="show_menu" class="row" id="pcapDownloadModal_advanced" style="">
          <div class="form-group mb-3 col-md-12 has-feedback">
	    <br>
            <label class="form-label">{{i18n('traffic_recording.filter_nbpf')}}<a class="ntopng-external-link" href="https://www.ntop.org/guides/n2disk/filters.html"><i class="fas fa-external-link-alt"></i></a></label>
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
    <button type="btn btn-primary" @click="apply" class="btn btn-primary">{{i18n('apply')}}</button>
  </template>  
</modal>  
</template>

<script type="text/javascript">
export default {
    components: {
	'modal': Vue.defineAsyncComponent( () => ntopng_vue_loader.loadModule(`${base_path}/vue/components/modal.vue`, ntopng_vue_loader.loadOptions) ),
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
	    i18n: (t) => i18n(t),
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
	format_date: function(d) {
	    let s = `${d.getDate()}/${d.getMonth()}/${d.getFullYear()} ${d.getHours()}:${d.getMinutes()}`;
	    return s;
	},
	apply: async function() {
	    if (this.bpf_filter != null && this.bpf_filter != "") {
		let url_request = `${base_path}/lua/pro/rest/v2/check/filter.lua?query=${this.bpf_filter}`;
		let res = await ntopng_utility.http_request(url_request, null, false, true);
		this.invalid_bpf = !res.response;
		if (this.invalid_bpf == true) {
		    return;
		}		
	    }
	    let url_request_obj = {
		ifid: ntopng_url_manager.get_url_entry("ifid"),
		epoch_begin: ntopng_url_manager.get_url_entry("epoch_begin"),
		epoch_end: ntopng_url_manager.get_url_entry("epoch_end"),
		bpf_filter: this.bpf_filter,
	    };
	    let url_request_params = ntopng_url_manager.obj_to_url_params(url_request_obj);
	    if (this.extract_now == true) {
		
		let url_request = `${base_path}/lua/rest/v2/get/pcap/live_extraction.lua?${url_request_params}`;
		window.open(url_request, '_self', false);
	    } else {
		let url_request = `${base_path}/lua/traffic_extraction.lua?${url_request_params}`;
		let resp = await ntopng_utility.http_request(url_request, null, false, true);
		let job_id = resp.id;
		//let job_id = 2;
		let alert_text_html = i18n('traffic_recording.extraction_scheduled');
		let page_name = i18n('traffic_recording.traffic_extraction_jobs');
		let ifid = ntopng_url_manager.get_url_entry("ifid");
		let href = `<a href="/lua/if_stats.lua?ifid=${ifid}page=traffic_recording&tab=jobs&job_id=${job_id}">${page_name}</a>`; 
		alert_text_html = alert_text_html.replace('%{page}', href);
		ntopng_events_manager.emit_custom_event(ntopng_custom_events.SHOW_GLOBAL_ALERT_INFO, alert_text_html);
	    }
	    this.$refs["modal"].close();
	},
	show: async function(bpf_filter) {
	    if (bpf_filter == null) {
		let url_params = ntopng_url_manager.get_url_params();
		let url_request = `${base_path}/lua/pro/rest/v2/get/db/filter/bpf.lua?${url_params}`;
		let res = await ntopng_utility.http_request(url_request);
		if (res == null || res.bpf == null) {
		    console.error(`modal-traffic-extraction: ${url_request} return null value`);
		    return;
		}
		bpf_filter = res.bpf;
	    }
	    let status = ntopng_status_manager.get_status();
	    if (status.epoch_begin == null || status.epoch_end == null) {
		console.error("modal-traffic-extraction: epoch_begin and epoch_end undefined in url");
		return;
	    }
	    let date_begin = new Date(status.epoch_begin * 1000);
	    let date_end = new Date(status.epoch_end * 1000);
	    
	    let desc = i18n('traffic_recording.about_to_download_flow');
	    desc = desc.replace('%{date_begin}', this.format_date(date_begin));
	    desc = desc.replace('%{date_end}', this.format_date(date_end));
	    this.description = desc;
	    
	    // let url_params = ntopng_url_manager.get_url_params();
	    // let url_request = `${base_path}/lua/pro/rest/v2/get/db/filter/bpf.lua?${url_params}`;
	    // let res = await ntopng_utility.http_request(url_request);
	    // this.bpf_filter = res.bpf;
	    this.bpf_filter = bpf_filter;
	    this.$refs["modal"].show();
	},
	show_hide_menu: function() {
	    this.show_menu = !this.show_menu;
	},
    },
}

</script>

<style scoped>
input ~ .alert {
  display: none;
}
input:invalid ~ .alert {
  display: block;
}
</style>

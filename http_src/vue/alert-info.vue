<template>
<div style="width:100%" v-if="show_alert == true" class="alert alert-dismissable" :class="alert_type">
  <span v-html="body"></span>
<button v-if="!no_close_button" type="button" @click="close" class="btn-close"  aria-label="Close"></button>
</div>
</template>

<script>
import { defineComponent } from 'vue';
export default defineComponent({
    components: {
    },
    props: {
	id: String,
	global: Boolean,
	no_close_button: Boolean,
    },
    emits: [],
    /** This method is the first method of the component called, it's called before html template creation. */
    created() {
    },
    data() {
	return {
	    show_alert: false,
	    i18n: (t) => i18n(t),
	    body: "",
	    alert_type: "alert-success",
	};
    },
    /** This method is the first method called after html template creation. */
    mounted() {
	if (this.global == true) {
	    ntopng_events_manager.on_custom_event(this.$props["id"], ntopng_custom_events.SHOW_GLOBAL_ALERT_INFO, (info) => {
		if (info.type != null) {
		    this.alert_type = info.type;
		}
		if (info.timeout != null) {
		    setTimeout(() => { this.close(); }, 1000 * info.timeout);
		}
		this.show(info.text_html);
	    });	
	}
    },
    methods: {
	close: function() {
	    this.show_alert = false;
	},
	show: function(body, alert_type) {
	    this.show_alert = true;
	    this.body = body;
	    if (alert_type != null) {
		this.alert_type = alert_type;
	    }
	},
    },
});
</script>

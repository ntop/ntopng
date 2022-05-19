<template>
<div style="width:100%" v-if="show_alert == true" class="alert alert-success alert-dismissable">
  <span v-html="body"></span>
<button type="button" @click="close" class="btn-close"  aria-label="Close"></button>
</div>
</template>

<script>
import { defineComponent } from 'vue';
export default defineComponent({
    components: {
    },
    props: {
	id: String,
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
	};
    },
    /** This method is the first method called after html template creation. */
    mounted() {
	ntopng_events_manager.on_custom_event(this.$props["id"], ntopng_custom_events.SHOW_GLOBAL_ALERT_INFO, (html_text) => this.show(html_text));	
    },
    methods: {
	close: function() {
	    this.show_alert = false;
	},
	show: function(body) {
	    this.show_alert = true;
	    this.body = body;
	},
    },
});
</script>

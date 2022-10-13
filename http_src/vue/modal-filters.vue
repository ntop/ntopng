<!-- (C) 2022 - ntop.org     -->
<template>
<modal :id="id_modal" ref="modal">
  <template v-slot:title>{{i18n('alerts_dashboard.add_filter')}}</template>
  <template v-slot:body>
    <form autocomplete="off">
      <div class="form-group row">
	<label class="col-form-label col-sm-3" for="dt-filter-type-select">
	  <b>Filter</b>
	</label>
	<div class="col-sm-8">
    <select-search v-model:selected_option="filter_type_selected"
      :id="'filter_type'"
      :options="filters_options"
      @select_option="change_filter()">
    </select-search>
	</div>
      </div>
      <hr>
      <div class="dt-filter-template-container form-group row">
	<label class="col-form-label col-sm-3">
          <b>{{filter_type_label_selected}}</b>
	</label>
	<div class="col-sm-8">
          <div class="input-group mb-3">
            <div class="input-group-prepend col-sm-3">
              <select-search v-model:selected_option="operator_selected"
                :id="'operator_filter'"
                :options="operators_to_show"
                @select_option="change_operator_type">
              </select-search>
            </div>
            <div class="col-sm-9" v-if="options_to_show">
              <select-search v-model:selected_option="option_selected"
                :id="'data_filter'"
                :options="options_to_show"
                @select_option="change_data_filter">
              </select-search>
            </div>
            <template v-else>
              <input v-show="!options_to_show" v-model="input_value" :pattern="data_pattern_selected" name="value" :required="input_required" type="text" class="form-control">
              <span v-show="!options_to_show" style="margin: 0px;padding:0;" class="alert invalid-feedback">{{i18n('invalid_value')}}</span>
            </template>
          </div>
          <!-- end div input-group mb-3 -->
	</div>
	<!-- end div form-group-row -->
      </div>
    </form>
  </template>
  <template v-slot:footer>
    <button type="button" :disabled="check_disable_apply()" @click="apply" class="btn btn-primary">{{i18n('apply')}}</button>
  </template>
</modal>
</template>

<script type="text/javascript">
import { default as Modal } from "./modal.vue";
import { default as SelectSearch } from './select-search.vue'

export default {
    components: {
	'modal': Modal,
  'select-search': SelectSearch,
    }, 
    props: {
	id: String,
	filters_options: Array,
    },
    updated() {
    },
    data() {
	return {
	    i18n: (t) => i18n(t),
	    jQuery: $,
	    id_modal: `${this.$props.id}_modal`,
	    filter_type_selected: [],
	    filter_type_label_selected: null,
	    operator_selected: [],
	    option_selected: [],
	    input_value: null,
	    data_pattern_selected: null,
	    input_required: false,
	    options_to_show: null,
	    operators_to_show: [],
	};
    },
    emits: ["apply"],
    created() {},
    /** This method is the first method called after html template creation. */
    async mounted() {
      await ntopng_sync.on_ready(this.id_modal);
      ntopng_events_manager.on_custom_event(this.$props["id"], ntopng_custom_events.SHOW_MODAL_FILTERS, (filter) => this.show(filter));	
      // notifies that component is ready
      ntopng_sync.ready(this.$props["id"]);
    },
    methods: {
	show: function(filter) {
    if (this.$props.filters_options == null || this.$props.filters_options.length == 0) { 
      return; 
    }
    if (filter != null) {
	  	this.filter_type_selected = filter;
		  this.change_filter(filter);		
    } else {
      this.filter_type_selected = this.$props.filters_options[0];
      this.change_filter();
    }
    this.$refs["modal"].show();
	},
  post_change: function(filter) {
    if (filter.id && this.$props.filters_options) {
      /* Filter type selected, e.g. Alert Type, Application, ecc. */
			this.filter_type_selected = this.$props.filters_options.find((fo) => fo.id == filter.id);
    }
    if (filter.value) {
      /* Filter selected for the type, e.g. DNS, ICMP, ecc. */
      if (this.options_to_show) {
			  this.option_selected = this.options_to_show.find((fo) => fo.value == filter.value);
      } else {
		    this.option_selected = [];
		    this.data_pattern_selected = this.get_data_pattern(filter.value_type);
        this.input_value = filter.value;
      }
    }
    if (filter.operator && this.operators_to_show) {
      /* Operator filter selected, e.g. =, !=, ecc. */
			this.operator_selected = this.operators_to_show.find((fo) => fo.id == filter.operator);
    }
  },
  change_operator_type: function(selected_operator_type) {
    if(selected_operator_type != []) {
      this.operator_selected = selected_operator_type
    }
  },  
  change_data_filter: function(selected_filter) {
    if(selected_filter != []) {
      this.option_selected = selected_filter
    }
  },  
  change_filter: function(selected_filter) {
    this.options_to_show = null;
    this.option_selected = null;
    this.input_value = null
    let filters_options = this.$props.filters_options;
    /* Search the filter selected */
    let filter = filters_options.find((fo) => fo.id == this.filter_type_selected.id);
    if (filter == null) { 
      return; 
    }
    /* Set the correct filters to display */
    this.operators_to_show = filter.operators;
    this.filter_type_label_selected = filter.label;
    if (filter.options != null) {
      this.options_to_show = filter.options.sort((a, b) => {
        if (a == null || a.label == null) { return -1; }
        if (b == null || b.label == null) { return 1; }
        return a.label.toString().localeCompare(b.label.toString());
      });
      if(!this.option_selected)
        this.option_selected = this.options_to_show[0]
    } else {
      this.options_to_show = null
    }

    if(filter.operators && this.operator_selected.length == 0) {
      this.operator_selected = filter.operators[0]
    }

    if (selected_filter != null) { 
      this.post_change(selected_filter); 
    }
	},
	get_data_pattern: function(value_type) {
	    this.input_required = true;
	    if (value_type == "text") {
		this.input_required = false;
		return `.*`;
	    } else if (value_type == "ip") {
		let r_ipv4 = NtopUtils.REGEXES.ipv4;
		let r_ipv4_vlan = r_ipv4.replace("$", "@[0-9]{0,5}$");
		let r_ipv6 = NtopUtils.REGEXES.ipv6;
		let r_ipv6_vlan = r_ipv6.replaceAll("$", "@[0-9]{0,5}$");
		return `(${r_ipv4})|(${r_ipv4_vlan})|(${r_ipv6})|(${r_ipv6_vlan})`;
	    }
	    return NtopUtils.REGEXES[value_type];
	},
	check_disable_apply: function() {
	    let regex = new RegExp(this.data_pattern_selected);
	    let disable_apply = !this.options_to_show && (
		(this.input_required && (this.input_value == null || this.input_value == ""))
		    || (regex.test(this.input_value) == false)
		);
	    return disable_apply;
	},
	apply: function() {
    let value = this.input_value;
    let value_label = this.input_value;
    if (value == null || (this.option_selected != undefined && this.option_selected.length != 0)) {
      let filter = this.filters_options.find((fo) => fo.id == this.filter_type_selected.id);
      let option = filter.options.find((o) => o.value == this.option_selected.value);
      value = option.value;
      value_label = option.value_label || option.label;
    } else if (value == null) {
      value = "";
    }
    let params = {
      id: this.filter_type_selected.id,
      label: this.filter_type_label_selected,
      operator: this.operator_selected.id,
      value: value,
      value_label: value_label,
    };
    this.$emit("apply", params);
    ntopng_events_manager.emit_custom_event(ntopng_custom_events.MODAL_FILTERS_APPLY, params);
    this.close();
	},
	close: function() {
	    this.$refs["modal"].close();
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

<!-- (C) 2022 - ntop.org     -->
<template>
<modal :id="id_modal"  @showed="showed()" ref="modal">
  <template v-slot:title>{{i18n('alerts_dashboard.add_filter')}}</template>
  <template v-slot:body>
    <form autocomplete="off">
      <div class="form-group row">
	<label class="col-form-label col-sm-3" for="dt-filter-type-select">
	  <b>Filter</b>
	</label>
	<div class="col-sm-8">
          <input type="hidden" name="index" />
          <select @change="change_filter()" v-model="filter_type_selected" required name="filter_type" class="form-select">
            <option v-for="item in filters_options" :value="item.id">
              {{item.label}}
            </option>	  
          </select>
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
              <select class="form-select" v-model="operator_selected">
		<option v-for="item in operators_to_show" :value="item.id">
                  {{item.label}}
		</option>	  
              </select>
            </div>
            <div class="col-sm-9" v-show="options_to_show">
              <select class="select2 form-select" ref="select2" required v-model="option_selected" name="filter_type">
		<option v-for="item in options_to_show" :value="item.value">
                  {{item.label}}
		</option>	  
              </select>
            </div>
            <!-- <div v-show="!options_to_show" class="input-group"> -->
              <input v-show="!options_to_show" v-model="input_value" :pattern="data_pattern_selected" name="value" :required="input_required" type="text" class="form-control">
              <!-- <span class="invalid-feedback">Invalid value</span> -->
              <span v-show="!options_to_show" style="margin: 0px;padding:0;" class="alert invalid-feedback">{{i18n('invalid_value')}}</span>
              <!-- </div> -->
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

export default {
    components: {
	'modal': Modal,
    }, 
    watch: {
	"filters_options": function(val, oldVal) {
	    // if (val == null || val.length == 0) { return; } 
	    // this.filter_type_selected = val[0].id;
	    // this.change_filter();
	}
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
	    filter_type_selected: null,
	    filter_type_label_selected: null,
	    operator_selected: null,
	    option_selected: null,
	    input_value: null,
	    data_pattern_selected: null,
	    input_required: false,
	    options_to_show: null,
	    operators_to_show: [],
	};
    },
    emits: ["apply"],
    created() {
    },
    /** This method is the first method called after html template creation. */
    async mounted() {
	let me = this;
	//$("#select2Input").select2({ dropdownParent: "#modal-container" };
	await ntopng_sync.on_ready(this.id_modal);
	ntopng_events_manager.on_custom_event(this.$props["id"], ntopng_custom_events.SHOW_MODAL_FILTERS, (filter) => this.show(filter));	
	// notifies that component is ready
	ntopng_sync.ready(this.$props["id"]);
    },
    methods: {
	show: function(filter) {
	    if (this.$props.filters_options == null || this.$props.filters_options.length == 0) { return; }
	    if (filter != null) {
		this.filter_type_selected = filter.id;
		let post_change = (filter_def) => {
		    if (this.option_selected != null) {
			this.option_selected = filter.value;
		    } else {
			this.input_value = filter.value;
		    }
		    this.operator_selected = filter.operator;
		};
		this.change_filter(post_change);		
	    }
	    else {
		this.filter_type_selected = this.$props.filters_options[0].id;
		this.change_filter();
	    }
	    this.$refs["modal"].show();
	},
	change_filter: function(post_change) {
	    this.options_to_show = null;
	    this.option_selected = null;
	    // use setTimeout to fix select2 bugs on first element selected
	    setTimeout(() => {
		let filters_options = this.$props.filters_options;
		let filter = filters_options.find((fo) => fo.id == this.filter_type_selected);
		if (filter == null) { return; }
		this.input_value = null;
		
		this.filter_type_label_selected = filter.label;
		this.options_to_show = filter.options;
		if (filter.options != null) {
		    this.options_to_show = filter.options.sort((a, b) => {
			if (a == null || a.label == null) { return -1; }
			if (b == null || b.label == null) { return 1; }
			return a.label.toString().localeCompare(b.label.toString());
		    });
		}
		this.operators_to_show = filter.operators;

		if (filter.operators != null && filter.operators.length > 0) {
		    let operator = filter.operators[0].id;
		    this.operator_selected = filter.operators[0].id;
		}
		else {
		    this.operator_selected = null;
		}
		if (filter.options != null && filter.options.length > 0) {
		    this.option_selected = filter.options[0].value;
		}
		else {
		    this.option_selected = null;
		    this.data_pattern_selected = this.get_data_pattern(filter.value_type);
		}
		if (post_change != null) { post_change(filter); }
	    }, 0);
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
	showed: function() {
	    let me = this;;
	    // setTimeout(() => {
	    let select2Div = me.$refs["select2"];
	    if (!$(select2Div).hasClass("select2-hidden-accessible")) {
		$(select2Div).select2({
		    width: '100%',
      theme: 'bootstrap-5',
      dropdownParent: $(select2Div).parent(),
		});
		$(select2Div).on('select2:select', function (e) {
		    let data = e.params.data;
		    me.option_selected = data.id;
		});
	    }
	},
	apply: function() {
	    let value = this.input_value;
	    let value_label = this.input_value;
	    if (value == null && this.option_selected != null) {
		let filter = this.filters_options.find((fo) => fo.id == this.filter_type_selected);
		let option = filter.options.find((o) => o.value == this.option_selected);
		value = option.value;
		value_label = option.value_label;
	    } else if (value == null) {
		value = "";
	    }
	    let params = {
		id: this.filter_type_selected,
		label: this.filter_type_label_selected,
		operator: this.operator_selected,
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

<template>
<div style="width:100%">
  <div class="mb-1" >    
    <modal-filters :filters_options="modal_data" @apply="apply_modal" ref="modal_filters" :id="id_modal_filters">
    </modal-filters>
    <data-time-range-picker :id="id_data_time_range_picker">
      <template v-slot:begin>
	<div v-if="is_alert_stats_url" class="d-flex align-items-center me-2">
	  <div class="btn-group" id="statusSwitch" role="group">
            <a href="#" @click="update_status_view('historical')" class="btn btn-sm" :class="{'active': status_view == 'historical', 'btn-seconday': status_view != 'historical', 'btn-primary': status_view == 'historical'}">Past</a>
            <a href="#" @click="update_status_view('acknowledged')" class="btn btn-sm" :class="{'active': status_view == 'acknowledged', 'btn-seconday': status_view != 'acknowledged', 'btn-primary': status_view == 'acknowledged'}">Ack</a>
            <a v-if="page != 'flow'" href="#" @click="update_status_view('engaged')" class="btn btn-sm" :class="{'active': status_view == 'engaged', 'btn-seconday': status_view != 'engaged', 'btn-primary': status_view == 'engaged'}">Engaged</a>
	  </div>
	</div>
	<select v-if="enable_query_preset" class="me-2 form-select" v-model="query_presets"  @change="update_select_query_presets()">
	  <template v-for="item in query_preset">
	    <option v-if="item.builtin == true" :value="item.value">{{ item.name }}</option>
	  </template>
	  <optgroup v-if="page != 'analysis'" :label="i18n('queries.queries')">
	    <template v-for="item in query_preset">
	      
    	      <option v-if="!item.builtin" :value="item.value">{{ item.name }}</option>
	    </template>
	  </optgroup>
	</select>
      </template>
      <template v-slot:extra_buttons>
	<slot name="extra_range_buttons"></slot>
      </template>
    </data-time-range-picker>
  </div>

  <!-- tagify -->
  <div v-if="page != 'all'" class="d-flex mt-1" style="width:100%">
    <input class="w-100 form-control h-auto" name="tags" ref="tagify" :placeholder="i18n('show_alerts.filters')">
    
    <button v-show="modal_data && modal_data.length > 0" class="btn btn-link" aria-controls="flow-alerts-table" type="button" id="btn-add-alert-filter" @click="show_modal_filters"><span><i class="fas fa-plus" data-original-title="" title="Add Filter"></i></span>
    </button>
    
    <button v-show="modal_data && modal_data.length > 0" data-bs-toggle="tooltip" data-placement="bottom" title="{{ i18n('show_alerts.remove_filters') }}" @click="remove_filters" class="btn ms-1 my-auto btn-sm btn-remove-tags">
      <i class="fas fa-times"></i>
    </button>
  </div>
  <!-- end tagify -->

</div>
</template>

<script type="text/javascript">
import { default as DataTimeRangePicker } from "./data-time-range-picker.vue";
import { default as ModalFilters } from "./modal-filters.vue";

function get_page(alert_stats_page) {
    let page = ntopng_url_manager.get_url_entry("page");
    if (page == null) {
	if (alert_stats_page) {
	    page = "all";
	} else {
	    page = "overview";
	}
    }
    return page;
}

async function get_filter_const(is_alert_stats_url, page) {
    let url_request;
    if (is_alert_stats_url) {
	url_request = `${base_path}/lua/rest/v2/get/alert/filter/consts.lua?page=${page}`;
    } else {
	let query_preset = ntopng_url_manager.get_url_entry("query_preset");
	if (query_preset == null) { query_preset = ""; }
	url_request = `${base_path}/lua/pro/rest/v2/get/db/filter/consts.lua?page=${page}&query_preset=${query_preset}`;
    }
    let filter_consts = await ntopng_utility.http_request(url_request);
    return filter_consts;
}

let FILTERS_CONST = [];
let TAG_OPERATORS;
let DEFINED_TAGS;
const VIEW_ONLY_TAGS = true;
/* Initial Tags */
let initialTags; 
//let pageHandle = {};
let TAGIFY;
let IS_ALERT_STATS_URL = window.location.toString().match(/alert_stats.lua/) != null;
let QUERY_PRESETS = ntopng_url_manager.get_url_entry("query_preset");
if (QUERY_PRESETS == null) {
    QUERY_PRESETS = "";
}
let STATUS_VIEW = ntopng_url_manager.get_url_entry("status");
if (STATUS_VIEW == null || STATUS_VIEW == "") {
    STATUS_VIEW = "historical";
}
const ENABLE_QUERY_PRESET = !IS_ALERT_STATS_URL;

let PAGE = get_page(IS_ALERT_STATS_URL);

const update_select_query_presets = function() {
    let value = $(`#select-query-presets`).val();
    let status = ntopng_status_manager.get_status();
    status['query_preset'] = value;
    ntopng_utility.replace_url_and_reload(status);
}

const create_tag_from_filter = function(filter) {
    let f_const = FILTERS_CONST.find((f) => f.id == filter.id);
    if (f_const == null) { console.error("create_tag_from_filter: filter const not found;"); }
    
    let value_label = filter.value;
    if (f_const.options != null) {
	let opt = f_const.options.find((o) => o.value == filter.value);
	if (opt != null) {
	    value_label = opt.label;
	}
    }
    const tag = {
	label: f_const.label,
	key: f_const.id,
	value: value_label,
	realValue: filter.value,
	title: `${f_const.label}${filter.operator}${value_label}`,
	selectedOperator: filter.operator,
    };
    if (tag.value == "") { tag.value = "''" }
    if (tag.realValue == null || tag.selectedOperator == null || tag.selectedOperator == "") {
	return null;
    }
    return tag;
}  

const load_filters_data = async function() {    
    FILTERS_CONST = await get_filter_const(IS_ALERT_STATS_URL, PAGE);
    FILTERS_CONST.filter((x) => x.label == null).forEach((x) => { console.error(`label not defined for filter ${JSON.stringify(x)}`); x.label = ""; });
    FILTERS_CONST.sort((a, b) => a.label.localeCompare(b.label));
    i18n_ext.tags = {};
    TAG_OPERATORS = {};
    DEFINED_TAGS = {};
    FILTERS_CONST.forEach((f_def) => {
	i18n_ext.tags[f_def.id] = f_def.label;
	f_def.operators.forEach((op) => TAG_OPERATORS[op.id] = op.label);
	DEFINED_TAGS[f_def.id] = f_def.operators.map((op) => op.id);
    });
    let entries = ntopng_url_manager.get_url_entries();
    let filters = [];
    for (const [key, value] of entries) {
    	let filter_def = FILTERS_CONST.find((fc) => fc.id == key);
    	if (filter_def != null) {
    	    let options_string = value.split(",");
	    options_string.forEach((opt_stirng) => {
    		let [value, operator] = opt_stirng.split(";");
		if (
		    operator == null || value == null || operator == ""
		    || (filter_def.options != null && filter_def.options.find((opt) => opt.value == value) == null)
		   ) {
		    return;
		}
		filters.push({id: filter_def.id, operator: operator, value: value});
	    });
    	}	
    }
    return filters;
    // "l7proto=XXX;eq"
}

function get_filters_object(filters) {
    if (filters == null) { return {}; }
    let filters_groups = {};
    filters.forEach((f) => {
	let group = filters_groups[f.id];
	if (group == null) {
	    group = [];
	    filters_groups[f.id] = group;
	}
	group.push(f);
    });
    let filters_object = {};
    for (let f_id in filters_groups) {
	let group = filters_groups[f_id];
	let filter_values = group.filter((f) => f.value != null && f.operator != null && f.operator != "").map((f) => `${f.value};${f.operator}`).join(",");
	filters_object[f_id] = filter_values;
    }
    return filters_object;
}

async function set_query_preset(range_picker_vue) {
    let page = range_picker_vue.page;
    let url_request = `${base_path}/lua/pro/rest/v2/get/db/preset/consts.lua?page=${page}`;
    let res = await ntopng_utility.http_request(url_request);
    let query_preset = res[0].list.map((el) => {
	return {
	    value: el.id, //== null ? "flow" : el.id,
	    name: el.name,
	    builtin: true,
	};
    });
    if (res.length > 1) {
	res[1].list.forEach((el) => {
    	    let query = {
    		value: el.id,
    		name: el.name,
    	    };
    	    query_preset.push(query);
	});
    }
    if (range_picker_vue.query_presets == null || range_picker_vue.query_presets == "") {
	range_picker_vue.query_presets = query_preset[0].value;	
	ntopng_url_manager.set_key_to_url("query_preset", query_preset[0].value);
    }
    range_picker_vue.query_preset = query_preset;
    return res;
}

export default {
    props: {
	id: String,
    },
    components: {	  
   	'data-time-range-picker': DataTimeRangePicker,
	'modal-filters': ModalFilters,
    },
    /**
     * First method called when the component is created.
     */
    created() {
    },
    async mounted() {
	let dt_range_picker_mounted = ntopng_sync.on_ready(this.id_data_time_range_picker);
	let modal_filters_mounted = ntopng_sync.on_ready(this.id_modal_filters);
	await dt_range_picker_mounted;

	if (this.enable_query_preset) {
	    await set_query_preset(this);
	}
	if (this.page != 'all') {
	    let filters = await load_filters_data();
	    
	    TAGIFY = create_tagify(this);
	    ntopng_events_manager.emit_event(ntopng_events.FILTERS_CHANGE, {filters});
	    ntopng_events_manager.on_event_change(this.$props["id"], ntopng_events.FILTERS_CHANGE, (status) => this.reload_status(status), true);
	}
	this.modal_data = FILTERS_CONST;
	
	//await modal_filters_mounted;
	ntopng_sync.ready(this.$props["id"]);
    },
    data() {
	return {
	    i18n: i18n,
	    id_modal_filters: `${this.$props.id}_modal_filters`,
	    id_data_time_range_picker: `${this.$props.id}_data-time-range-picker`,
	    show_filters: false,
	    edit_tag: null,
	    is_alert_stats_url: IS_ALERT_STATS_URL,
	    query_preset: [],
	    query_presets: QUERY_PRESETS,
	    status_view: STATUS_VIEW,
	    enable_query_preset: ENABLE_QUERY_PRESET,
	    page: PAGE,
	    modal_data: [],
	    last_filters: [],
	};
    },
    methods: {
	is_filter_defined: function(filter) {
	    return DEFINED_TAGS[filter.id] != null;
	},
	update_status_view: function(status) {
	    ntopng_url_manager.set_key_to_url("status", status);
	    ntopng_url_manager.reload_url();	    
	},
	update_select_query_presets: function() {
	    let url = ntopng_url_manager.get_url_params();
	    ntopng_url_manager.set_key_to_url("query_preset", this.query_presets);
	    ntopng_url_manager.reload_url();
	},
	show_modal_filters: function() {
	    this.$refs["modal_filters"].show();
	},
	remove_filters: function() {
	    let filters = [];
	    ntopng_events_manager.emit_event(ntopng_events.FILTERS_CHANGE, {filters});
	},
	reload_status: function(status) {
	    let filters = status.filters;
	    if (filters == null) { return; }
	    // delete all previous filter
	    ntopng_url_manager.delete_params(FILTERS_CONST.map((f) => f.id));
	    TAGIFY.tagify.removeAllTags();
	    let filters_object = get_filters_object(filters);
	    ntopng_url_manager.add_obj_to_url(filters_object);
	    filters.forEach((f) => {
		let tag = create_tag_from_filter(f);
		if (tag == null) { return; }
		TAGIFY.addFilterTag(tag);
	    });
	    this.last_filters = filters;
	},
	apply_modal: function(params) {
	    let status = ntopng_status_manager.get_status();
	    let filters = status.filters;
	    if (filters == null) { filters = []; }
	    if (this.edit_tag != null) {
		filters = filters.filter((f) => f.id != this.edit_tag.key || f.value != this.edit_tag.realValue);
		this.edit_tag = null;
	    }
	    filters.push(params);
	    
	    // trigger event and then call reload_status
	    ntopng_events_manager.emit_event(ntopng_events.FILTERS_CHANGE, {filters});
	},
    },
};

function create_tagify(range_picker_vue) {
    // create tagify
    const tagify = new Tagify(range_picker_vue.$refs["tagify"], {
	duplicates: true,
	delimiters : null,
	dropdown : {
            enabled: 1, // suggest tags after a single character input
            classname : 'extra-properties' // custom class for the suggestions dropdown
	},
	autoComplete: { enabled: false },
	templates : {
            tag : function(tagData){
		try{
                    return `<tag title='${tagData.value}' contenteditable='false' spellcheck="false" class='tagify__tag ${tagData.class ? tagData.class : ""}' ${this.getAttributes(tagData)}>
                        <x title='remove tag' class='tagify__tag__removeBtn'></x>
                        <div>
                            ${tagData.label ? `<b>${tagData.label}</b>&nbsp;` : ``}
                            ${!VIEW_ONLY_TAGS && tagData.operators ? `<select class='operator'>${tagData.operators.map(op => `<option ${tagData.selectedOperator === op ? 'selected' : ''} value='${op}'>${TAG_OPERATORS[op]}</option>`).join()}</select>` : `<b class='operator'>${tagData.selectedOperator ? TAG_OPERATORS[tagData.selectedOperator] : '='}</b>`}&nbsp;
                            <span class='tagify__tag-text'>${tagData.value}</span>
                        </div>
                    </tag>`
		}
		catch(err){
                    console.error(`An error occured when creating a new tag: ${err}`);
		}
            },
	},
	validate: function(tagData) {
	    return (typeof tagData.key !== 'undefined' &&
		    typeof tagData.selectedOperator !== 'undefined' &&
		    typeof tagData.value !== 'undefined');
	}
    });
    
    $(document).ready(function() {
	// add existing tags
	tagify.addTags(initialTags);
    }); /* $(document).ready() */
    
    const createValueFromTag = function(tag) {
	if (!tag.selectedOperator) tag.selectedOperator = 'eq';
	let val = tag.realValue != null ? tag.realValue : tag.value;
	let value = `${val};${tag.selectedOperator}`;
	return value;
    }
    
    const addFilterTag = async function(tag) {
        /* Convert values to string (this avoids issues e.g. with 0) */
        if (typeof tag.realValue == 'number') { tag.realValue = ''+tag.realValue; }
        if (typeof tag.value == 'number') { tag.value = ''+tag.value; }
	
        const existingTagElms = tagify.getTagElms();
	
        /* Lookup by key, value and operator (do not add the same key and value multiple times) */
        let existingTagElement = existingTagElms.find(htmlTag => 
						      htmlTag.getAttribute('key') === tag.key
						      && htmlTag.getAttribute('realValue') === tag.realValue 
						      //&& htmlTag.getAttribute('selectedOperator') === tag.selectedOperator
						     );
        let existingTag = tagify.tagData(existingTagElement);
        if (existingTag !== undefined) {
            return;
        }
	
        // has the tag an operator object?
        if (DEFINED_TAGS[tag.key] && !Array.isArray(DEFINED_TAGS[tag.key])) {
            tag.operators = DEFINED_TAGS[tag.key].operators;
        }
	
        if (!tag.selectedOperator) {
            tag.selectedOperator = 'eq';
        }
        // add filter!
        tagify.addTags([tag]);
    }
    
    // when an user remove the tag
    tagify.on('remove', async function(e) {
      const key = e.detail.data.key;
      const value = e.detail.data.realValue;
      const status = ntopng_status_manager.get_status();
      
      if (key === undefined) { return; }
      if (status.filters == null) { return; }

      const filters = status.filters.filter((f) => (f.id != key || (f.id == key && f.value != value)));
      ntopng_events_manager.emit_event(ntopng_events.FILTERS_CHANGE, {filters});	
    });
    
    tagify.on('add', async function(e) {
        const detail = e.detail;
        if (detail.data === undefined) { return; }	
        const tag = detail.data;	
        // let's check if the tag has a key field
        if (!tag.key) {
            tagify.removeTags([e.detail.tag]);
            e.preventDefault();
            e.stopPropagation();
            return;
        }	
    });
    
    // Tag 'click' event handler to open the 'Edit' modal. Note: this prevents
    // inline editing of the tag ('edit:updated' is never called as a consequence)
    tagify.on('click', async function(e) {
        const detail = e.detail;	
        if (detail.data === undefined) { return; }
        if (detail.data.key === undefined) {return;}
        const tag = detail.data;
	// remember that this tag already exixts
	range_picker_vue.edit_tag = tag;
	// show modal-filters
	ntopng_events_manager.emit_custom_event(ntopng_custom_events.SHOW_MODAL_FILTERS, {id: tag.key, operator: tag.selectedOperator, value: tag.realValue});
    });
    
    tagify.on('edit:updated', async function(e) {
	console.warn("UPDATED");
	return;
    });
    
    $(`tags`).on('change', 'select.operator', async function(e) {
	console.warn("TAGS change");
	return;
    });
    return {
	tagify,
	addFilterTag,
    };
}
</script>


<style scoped>
.tagify__input {
  min-width: 175px;
}
.tagify__tag {
  white-space: nowrap;
  margin: 3px 0px 5px 5px;
}
.tagify__tag select.operator {
  margin: 0px 4px;
  border: 1px solid #c4c4c4;
  border-radius: 4px;
}
.tagify__tag b.operator {
  margin: 0px 4px;
  background-color: white;
  border: 1px solid #c4c4c4;
  border-radius: 4px;
  padding: 0.05em 0.2em;
}
.tagify__tag > div {
  display: flex;
  align-items: center;
}
</style>

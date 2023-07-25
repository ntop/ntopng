<template>
<input class="w-100 form-control h-auto" name="tags" ref="tagify_ref" :placeholder="_i18n('show_alerts.filters')">
<button class="btn btn-link"
	aria-controls="flow-alerts-table"
	type="button" id="btn-add-alert-filter"
	@click="emit('add_tag')">
  <span><i class="fas fa-plus" data-original-title="" title="Add Filter"></i></span>
</button>
<button data-placement="bottom"
        :title="_i18n('show_alerts.remove_tags')" @click="remove_tags"
        class="btn ms-1 my-auto btn-sm btn-remove-tags">
  <span><i class="fas fa-times"></i></span>
</button>
<slot name="extra_buttons"></slot>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, computed, nextTick, watch } from "vue";
import { default as DataTimeRangePicker } from "./data-time-range-picker.vue";
import { default as ModalFilters } from "./modal-filters.vue";
import filtersManager from "../utilities/filters-manager.js";

const _i18n = (t) => i18n(t);

const emit = defineEmits(['update:tags', 'add_tag', 'remove_tag', 'edit_tag', 'remove_tags']);
const props = defineProps({
    tags: Array,
    disable: Boolean,
});

defineExpose({ get_tagify_obj });

const tagify_ref = ref(null);

const tags_2 = ref([]);
let tagify_obj = null;

const tag_operator_label_dict = filtersManager.tag_operator_label_dict;

onBeforeMount(async () => {
});

onMounted(async () => {
    tags_2.value = props.tags;
    tagify_obj = create_tagify();
    sync_tags_in_tagify();
});

watch(() => props.tags, (cur_value, old_value) => {
    tags_2.value = props.tags;
    sync_tags_in_tagify();
}, { flush: 'pre'});

function remove_tags() {
    tagify_obj.tagify.removeAllTags();
    sync_tags_from_tagify();
    emit('update:tags', tags_2.value);	
    emit('remove_tags');
}

function sync_tags_in_tagify() {
    tagify_obj.tagify.removeAllTags();
    tags_2.value.forEach((tag) => tagify_obj.add_tag(tag, true));
}

function sync_tags_from_tagify() {
    const current_tags_elements = tagify_obj.tagify.getTagElms();
    const current_tags = current_tags_elements.map((el) => tagify_obj.tagify.tagData(el));
    console.log(current_tags);
    tags_2.value.length = 0;
    current_tags.forEach((t) => tags_2.value.push(t));
    // tags_2.value = current_tags;
}

function create_tagify() {
    const tagify = new Tagify(tagify_ref.value, {
        duplicates: true,
        delimiters: null,
        dropdown: {
            enabled: 1, // suggest tags after a single character input
            classname: 'extra-properties' // custom class for the suggestions dropdown
        },
        autoComplete: { enabled: false },
        templates: {
            tag: function (tagData) {
                try {
                    return `<tag title='${tagData.value}' contenteditable='false' spellcheck="false" class='tagify__tag'>
                        <x title='remove tag' class='tagify__tag__removeBtn'></x>
                        <div>
                           <b>${tagData.label ? tagData.label : tagData.key}</b>&nbsp;
                           <b class='operator'>${tagData.selectedOperator ? tag_operator_label_dict[tagData.selectedOperator] : '='}</b>&nbsp;
                            <span class='tagify__tag-text'>${tagData.value}</span>
                        </div>
                    </tag>`
                }
                catch (err) {
                    console.error(`An error occured when creating a new tag: ${err}`);
                }
            },
        },
        validate: function (tagData) {
            return (typeof tagData.key !== 'undefined' &&
                    typeof tagData.selectedOperator !== 'undefined' &&
                    typeof tagData.value !== 'undefined');
        }
    });
    
    const add_tag = async function (tag, not_update_tags) {
        /* Convert values to string (this avoids issues e.g. with 0) */
        if (typeof tag.realValue == 'number') { tag.realValue = '' + tag.realValue; }
        if (typeof tag.value == 'number') { tag.value = '' + tag.value; }
	
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
	
        if (!tag.selectedOperator) {
            tag.selectedOperator = 'eq';
        }
        // add filter!
        tagify.addTags([tag]);
	if (not_update_tags == true) {
	    return;
	}
	tags_2.value.push(tag);
	emit('update:tags', tags_2.value);	
    }
    tagify.on('remove', async function (e) {
	const tag = e?.detail?.data;
	if (tag == null) { return; }

	sync_tags_from_tagify();
	emit('update:tags', tags_2.value);	
	emit("remove_tag", tag);
    });
    tagify.on('add', async function (e) {
	const tag = e?.detail?.data;
	if (tag == null) { return; }
        // let's check if the tag has a key field
        if (!tag.key) {
            tagify.removeTags([e.detail.tag]);
            e.preventDefault();
            e.stopPropagation();
            return;
        }
    });
    tagify.on('click', async function (e) {
	const tag = e?.detail?.data;
	if (tag?.key == null) { return; }
	emit("edit_tag", tag);
    });
    return { tagify, add_tag };
}

function get_tagify_obj() {
    return tagify_obj;
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

.tagify__tag>div {
    display: flex;
    align-items: center;
}
</style>

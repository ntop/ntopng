{#
  (C) 2022 - ntop.org
  This template is used by the `Service Map` page inside the `Hosts` menu.    
#}

{
  
}
<template>
  <div class="dropdown<">
    <button class="btn btn-link dropdown-toggle" type="button" data-bs-toggle="dropdown" aria-haspopup="true" aria-expanded="false">
      {{ active_entry.label }} <i :class="(filter_icon || '')"></i>
    </button> 
    <div class="dropdown-menu dropdown-menu-end scrollable-dropdown">
      <a type="button" v-for="element in list" @click="change_filter(element)" :class="{ 'active': (element.currently_active == true) }" class="dropdown-item"><i :class="(element.icon || '')"></i> {{ element.label }}</a>
    </div>
  </div>
</template>

<script>
import { defineComponent } from 'vue';

const filtering_icon = 'fas fa-filter'

export default defineComponent({
  components: {
  },
  props: {
    id: Number,
    dropdown_list: Array,
    url_param: String,
    active_element: Object,
  },
  emits: ["click_item"],
  /** This method is the first method of the component called, it's called before html template creation. */
  created() {
    this.list = this.$props.dropdown_list; 
  },
  data() {
    return {
      list: [],
      filter_icon: '',
      active_entry: {},
    };
  },
  /** This method is the first method called after html template creation. */
  mounted() {
    this.active_entry = this.$props.active_element
    this.set_active_entry();
    (this.active_entry && this.active_entry.filter_icon == false) ? this.filter_icon = '' : this.filter_icon = filtering_icon
    ntopng_sync.ready(this.$props["ref"]);
  },
  methods: {
    change_filter: function(element) {
      (element.filter_icon == false) ? this.filter_icon = '' : this.filter_icon = filtering_icon
      this.list.forEach((el) => { el.currently_active = false });
      element.currently_active = true;
      this.active_entry = element
      this.$emit('click_item', element, this.$props.url_param, this.$props.id)
    },
    set_active_entry: function() {
      const curr_value = ntopng_url_manager.get_url_entry(this.$props.url_param)
      if(curr_value && curr_value != '') {
        let num_non_active_entries = 0
        this.list.forEach((el) => { 
          num_non_active_entries += 1
          el.currently_active = false;
          if(curr_value == el.key) {
            el.currently_active = true;
            this.active_entry = el;
            num_non_active_entries -= 1
          }
        });
        
        if(num_non_active_entries == this.list.length) {
          this.list[0].currently_active = true
          this.active_entry = this.list[0];
          ntopng_url_manager.set_key_to_url(this.$props.url_param, '');
        }
      }      
    }
  },
});
</script>

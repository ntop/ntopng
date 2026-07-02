<!-- (C) 2022 - ntop.org     -->

<template>
<div class="row">
  <div class="col-12">
    <div class="card" style="height:80vh">
      <div class="card-body p-2" style="height:100%; display:flex; flex-direction:column;">
        <div class="d-flex ms-auto flex-row-reverse flex-shrink-0 mb-2">
          <div>
            <label class="my-auto me-1"></label>
            <div>
              <button class="btn btn-link m-1" tabindex="0" type="button" @click="reload">
                <i class="fas fa-arrows-rotate"></i>
              </button>
            </div>
          </div>
          <template v-for="(value, key, index) in props.context.available_filters">
            <div class="m-1" v-if="value.length > 0">
              <div style="min-width: 14rem;">
                <label class="my-auto me-1">{{ _i18n('bubble_map.' + key) }}: </label>
                <SelectSearch
                  v-model:selected_option="active_filter_list[key]"
                  :options="value"
                  @select_option="click_item">
                </SelectSearch>
              </div>
            </div>
          </template>
        </div>
        <div class="flex-grow-1" style="min-height: 0;">
          <BubbleChart ref="bubble_chart_ref" :chart="bubble_cfg" />
        </div>
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount } from "vue";
import { default as SelectSearch } from "./select-search.vue";
import { default as BubbleChart } from "./charts/bubble-chart.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);
const props = defineProps({
  context: Object
})

const rest_url = `${http_prefix}/lua/pro/rest/v2/charts/alert/analysis.lua`
const active_filter_list = {}
const bubble_chart_ref = ref(null)

const build_url_params = () => {
  /* Base params, always present */
  const params = {
    bubble_mode: ntopng_url_manager.get_url_entry('bubble_mode') ?? 0,
    timeframe:   ntopng_url_manager.get_url_entry('timeframe') ?? 3600,
    vlan:        ntopng_url_manager.get_url_entry('vlan') ?? '',
    ifid:        ntopng_url_manager.get_url_entry('ifid') ?? props.context.ifid,
  }

  /* Add every active SelectSearch filter so the API reflects the current selection */
  for (const [name, filter] of Object.entries(active_filter_list)) {
    if (filter != null && filter.id != null)
      params[name] = filter.id
  }

  return params
}

const build_bubble_cfg = () => ({
  update_url: rest_url,
  url_params: build_url_params(),
})
const bubble_cfg = ref(build_bubble_cfg())

const reload = function() {
  /* Reassign the cfg so BubbleChart's deep watch re-fetches with the current params */
  bubble_cfg.value = build_bubble_cfg()
}

const click_item = function(item) {
  /* Track the new selection so build_url_params() picks it up */
  ntopng_url_manager.set_key_to_url(item.filter_name, item.id)
  active_filter_list[item.filter_name] = item

  /* Reassign the cfg: BubbleChart's deep watch on props.chart re-runs load() with new params */
  bubble_cfg.value = build_bubble_cfg()
}

onBeforeMount(() => {
  /* Before mounting the various widgets, update the url to the correct one, by adding ifid, ecc. */
  const timeframe = ntopng_url_manager.get_url_entry('timeframe');
  const vlan = ntopng_url_manager.get_url_entry('vlan');
  const bubble_mode = ntopng_url_manager.get_url_entry('bubble_mode');

  if(!bubble_mode) ntopng_url_manager.set_key_to_url('bubble_mode', 0) /* First Entry */
  if(!timeframe) ntopng_url_manager.set_key_to_url('timeframe', 3600) /* Default 5 min */
  if(!vlan) ntopng_url_manager.set_key_to_url('vlan', '') /* Default no vlan */

  ntopng_url_manager.set_key_to_url('ifid', props.context.ifid) /* Current interface */

  for(const [name, filters] of Object.entries(props.context.available_filters)) {
    filters.forEach((filter) => {
      filter.filter_name = name
      if(filter.currently_active)
        active_filter_list[name] = filter;
    })
  }

  /* Rebuild cfg now that active_filter_list is populated, so the first BubbleChart
     render already honors the pre-selected filters */
  bubble_cfg.value = build_bubble_cfg()
});
</script>

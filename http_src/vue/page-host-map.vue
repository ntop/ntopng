<!-- (C) 2022 - ntop.org -->

<template>
<div class="row">
  <div class="col-12">
    <div class="card">
      <div class="card-body">
        <div class="d-flex flex-column mb-3" style="height: 70vh;">
          <div class="d-flex ms-auto flex-row-reverse flex-shrink-0">
            <label class="my-auto me-1"></label>
            <div class="m-1" v-for="(value, key) in props.context.available_filters" :key="key">
              <template v-if="value.length > 0">
                <div style="min-width: 18rem;">
                  <label class="my-auto me-1">{{ _i18n('bubble_map.' + key) }}: </label>
                  <SelectSearch
                    v-model:selected_option="active_filter_list[key]"
                    :options="value"
                    @select_option="click_item">
                  </SelectSearch>
                </div>
              </template>
            </div>
          </div>
          <div class="flex-grow-1" style="min-height: 0;">
            <BubbleChart v-if="chart_cfg" :chart="chart_cfg" />
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import { ref, reactive, onBeforeMount } from "vue";
import { default as BubbleChart } from "./charts/bubble-chart.vue";
import { default as SelectSearch } from "./select-search.vue";
import { ntopng_url_manager } from "../services/context/ntopng_globals_services";

const _i18n = (t) => i18n(t);

const props = defineProps({ context: Object });

const active_filter_list = reactive({});

const rest_url = `${http_prefix}/lua/pro/rest/v2/charts/host/map.lua`;

function buildUrlParams() {
    const params = {
        bubble_mode: ntopng_url_manager.get_url_entry('bubble_mode') ?? 0,
        ifid:        ntopng_url_manager.get_url_entry('ifid'),
    };

    /* Include every active SelectSearch filter so the API reflects the current selection */
    for (const [name, filter] of Object.entries(active_filter_list)) {
        if (filter != null && filter.id != null)
            params[name] = filter.id;
    }

    return params;
}

const chart_cfg = ref(null);

function click_item(item) {
    ntopng_url_manager.set_key_to_url(item.filter_name, item.id);
    /* Track selection so buildUrlParams() picks it up, then reassign to trip the deep watch */
    active_filter_list[item.filter_name] = item;
    chart_cfg.value = { update_url: rest_url, url_params: buildUrlParams() };
}

onBeforeMount(() => {
    if (!ntopng_url_manager.get_url_entry('bubble_mode'))
        ntopng_url_manager.set_key_to_url('bubble_mode', 0);
    ntopng_url_manager.set_key_to_url('ifid', props.context.ifid);

    for (const [name, filters] of Object.entries(props.context.available_filters)) {
        filters.forEach((filter) => {
            filter.filter_name = name;
            if (filter.currently_active)
                active_filter_list[name] = filter;
        });
    }

    /* Init after URL params are set so ifid is available */
    chart_cfg.value = { update_url: rest_url, url_params: buildUrlParams() };
});
</script>

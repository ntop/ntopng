<!--
  (C) 2013-22 - ntop.org
-->

<template>
<div class="row">
  <div class="col-md-12 col-lg-12">
    <div class="card card-shadow">
      <div class="overlay justify-content-center align-items-center position-absolute h-100 w-100">
        <div class="text-center">
          <div class="spinner-border text-primary mt-5" role="status">
            <span class="sr-only position-absolute">Loading...</span>
          </div>
        </div>
      </div>
      <div class="card-body">
        <Sankey ref="flow_sankey"
          :id="id"
          :page_csrf="props.page_csrf"
          :url="props.url"
          :url_params="props.url_params"
          :extra_settings="extra_settings">
        </Sankey>
      </div>
    </div>
  </div>
</div>
</template>

<script setup>
import { ref, onMounted } from "vue";
import { default as Sankey } from "./sankey.vue";
import sankeyUtils from "../utilities/map/sankey_utils"

const props = defineProps({
  page_csrf: String,
  url: String,
  url_params: Object,
})

const flow_sankey = ref(null);
const extra_settings = {}

const id = "flow-sankey"
const _i18n = (t) => i18n(t);

const update_data = function() {
  flow_sankey.value.updateData(); 
};

onMounted(() => { 
  extra_settings.linkTitle = sankeyUtils.formatFlowTitle
  update_data()
})

</script>







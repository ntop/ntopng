<template>
    <div>
        <template v-if="isDataAvailable">
            <Chart ref="chart" :id="id" :chart_type="chart_type" :base_url_request="base_url"
                :get_custom_chart_options="get_chart_options" :register_on_status_change="false">
            </Chart>
        </template>
        <div v-else style="position: relative; display: flex; flex-direction: column; justify-content: center; align-items: center; width: 100%; height: 100%; min-height: 250px; padding: 5% 20px; color: #666;">
            <div style="font-size: clamp(16px, 2vw, 18px); margin-bottom: 2vh;"><i class="fas fa-search"></i> {{_i18n("dashboard.no_assets_discovered")}}</div>
            <div style="font-size: clamp(14px, 1.5vw, 16px);"> {{ _i18n("dashboard.waiting_assets_discovery") }} </div>
        </div>
    </div>
</template>

<script setup>
import { ref, onMounted, onBeforeMount, watch, computed } from "vue";
import dataUtils from "../utilities/data-utils";
import { default as Chart } from "./chart.vue";

const _i18n = (t) => i18n(t);

const chart_type = ref(ntopChartApex.typeChart.BAR);
const chart = ref(null);
const url_list = ref(null);
const isDataAvailable = ref(false);

const props = defineProps({
    id: String,          /* Component ID */
    i18n_title: String,  /* Title (i18n) */
    ifid: String,        /* Interface ID */
    epoch_begin: Number, /* Time interval begin */
    epoch_end: Number,   /* Time interval end */
    max_width: Number,   /* Component Width (4, 8, 12) */
    max_height: Number,  /* Component Hehght (4, 8, 12)*/
    params: Object,      /* Component-specific parameters from the JSON template definition */
    get_component_data: Function, /* Callback to request data (REST) */
    filters: Object
});

const base_url = computed(() => {
    return `${http_prefix}${props.params.url}`;
});

const get_url_params = () => {
    return {
        ifid: props.ifid,
        epoch_begin: props.epoch_begin,
        epoch_end: props.epoch_end,
        new_charts: true,
        ...props.params.url_params,
        ...props.filters
    }
}

async function checkDataAvailability() {
    try {
        const url = base_url.value;
        const url_params = get_url_params();
        const options = await props.get_component_data(url, url_params, undefined, props.epoch_begin);
        
        // check if data is available
        const hasData = options && 
                      options.series && 
                      options.series[0] && 
                      options.series[0].data && 
                      options.series[0].data.filter(value => value > 0).length > 0;
        
        isDataAvailable.value = hasData;
        return hasData;
    } catch (error) {
        console.error("Error checking data availability:", error);
        isDataAvailable.value = false;
        return false;
    }
}

function get_chart_options() {
    const url = base_url.value;
    const url_params = get_url_params();
    const options = props.get_component_data(url, url_params, undefined, props.epoch_begin);

    Promise.resolve(options).then(response => {
        // process if there is data
        if (!response || !response.series || !response.series[0] || !response.series[0].data) {
            isDataAvailable.value = false;
            return options;
        }
        
        // remove values that are 0 to not render them
        response.series[0].data = response.series[0].data.filter((value) => value > 0);
        
        // no value after filtering
        if (response.series[0].data.length === 0) {
            isDataAvailable.value = false;
            return options;
        }
        
        isDataAvailable.value = true;
        let data_count = response.series[0].data.length;

        // remove labels and links of values that are 0
        if (response.urls && response.urls.length) {
            response.urls = response.urls.splice(0, data_count);
        }
        
        if (response.xaxis && response.xaxis.categories) {
            response.xaxis.categories = response.xaxis.categories.splice(0, data_count);
        }

        if (response.chart) {
            response.chart = {
                ...response.chart,
                events: {
                    dataPointSelection: function (event, chartContext, config) {
                        const selectedIndex = config.dataPointIndex;
                        if (url_list.value && url_list.value[selectedIndex] && 
                            !dataUtils.isEmptyString(url_list.value[selectedIndex])) {
                            window.location.href = url_list.value[selectedIndex];
                        }
                    }
                }
            };
        }

        // Y-axis configuration
        response.yaxis = {
            forceNiceScale: true,
            showForNullSeries: true,
            showAlways: true,
            labels: {
                show: true
            }
        }

        if (response.urls) {
            url_list.value = response.urls;
        }
    }).catch(error => {
        console.error("Error processing chart data:", error);
        isDataAvailable.value = false;
    });
    
    return options;
}

/* Watch - detect changes on epoch_begin / epoch_end and refresh the component */
watch(() => [props.epoch_begin, props.epoch_end, props.filters], async (cur_value, old_value) => {
    await checkDataAvailability();
    if (isDataAvailable.value && chart.value) {
        refresh_chart();
    }
}, { flush: 'pre', deep: true });

onBeforeMount(async () => {
    await checkDataAvailability();
});

onMounted(() => {
    // No additional initialization needed here
});

async function refresh_chart() {
    if (isDataAvailable.value && chart.value) {
        chart.value.update_chart();
    }
}
</script>
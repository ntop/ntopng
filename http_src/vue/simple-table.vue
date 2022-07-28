<!-- (C) 2022 - ntop.org     -->
<template>
<div>
<table  class="table table-borderless graph-statistics mb-2" style="">
    <thead class="text-center">
        <tr>
            <th class="graph-val-total-title fs-6" style="border-left-width: 1px; border-top-width: 1px;"> Total:</th>
            <th class="graph-val-95percentile-title fs-6" style="border-left-width: 1px; border-top-width: 1px;">95th <a href="https://en.wikipedia.org/wiki/Percentile">Percentile</a>:</th>
            <th class="graph-val-average-title fs-6" style="border-left-width: 1px; border-top-width: 1px;">Average:</th>
            <th class="graph-val-max-title fs-6" style="border-left-width: 1px; border-top-width: 1px; border-right-width: 1px;">Max:</th>
        </tr>
    </thead>
    <tbody><tr>
   <td class="graph-val-total text-center" style="border-width: 1px;"> <span>{{total}}</span></td>
   <td class="graph-val-95percentile text-center" style="border-top-width: 1px; border-right-width: 1px; border-bottom-width: 1px;"> <span>{{percentile_sent}} [Sent]<br>{{percentile_rcvd}} [Rcvd]</span></td>
   <td class="graph-val-average text-center" style="border-top-width: 1px; border-right-width: 1px; border-bottom-width: 1px;"> <span>{{avg_sent}} Kbit/s [Sent]<br>{{avg_rcvd}} [Rcvd]</span></td>
   <!-- <td class="graph-val-min" style="display:none;border-bottom-width: 1px;border-top-width: 1px;border-right-width: 1px;">nil: <span></span></td> -->
   <td class="graph-val-max text-center" style="border-bottom-width: 1px; border-top-width: 1px; border-right-width: 1px;"> <span>{{max_sent}} [Sent]<br>{{max_rcvd}} [Rcvd]</span></td>
</tr></tbody></table>

</div>
</template>

<script>
export default {
    components: {
    },
    props: {
	chart_options: Object,
    },
    watch: {
	"chart_options": function(val, oldVal) {
	    this.reloaded_table();
	}
    },
    emits: [],
    /** This method is the first method of the component called, it's called before html template creation. */
    created() {
    },
    data() {
	return {
        total:0,
        percetile_sent:0,
        percetile_rcvd:0,
        avg_sent:0,
        avg_rcvd:0,
	    max_sent: 0,
	    max_rcvd: 0,

	};
    },
    /** This method is the first method called after html template creation. */
    async mounted() {
	console.log("Mounted Simple table");
    },
    methods: {
	reloaded_table: function() {
        let fBit =  ntopChartApex.chartOptionsUtility.getApexYFormatter(ntopChartApex.chartOptionsUtility.apexYFormatterTypes.bps.id);
        let fBytes = ntopChartApex.chartOptionsUtility.getApexYFormatter(ntopChartApex.chartOptionsUtility.apexYFormatterTypes.bytes.id);
	    console.log("reloaded table called");
	    //console.log(Object.keys(this.chart_options.statistics));
        console.log(this.chart_options.statistics.by_serie);
        console.log("OBJECT KEYS")
        let total = fBit(this.chart_options.statistics.total)
        let max_sent = this.chart_options.statistics.by_serie[0].max_val;
        let max_rcvd = this.chart_options.statistics.by_serie[1].max_val;
        let avg_sent = this.chart_options.statistics.by_serie[0].average;
        let avg_rcvd = this.chart_options.statistics.by_serie[1].average;
        let percentile_sent = this.chart_options.statistics.by_serie[0]["95th_percentile"];
        let percentile_rcvd = this.chart_options.statistics.by_serie[1]["95th_percentile"];
        this.max_sent = fBit(max_sent*8);
        this.max_rcvd = fBit(max_rcvd*8);
        this.avg_sent = fBit(avg_sent*8);
        this.avg_rcvd = fBit(avg_rcvd*8);
        this.percentile_sent = fBit(percentile_sent*8);
        this.percentile_rcvd = fBit(percentile_rcvd*8);
        this.total = fBytes(total)

	},
    },
};
</script>

<!-- (C) 2022 - ntop.org     -->
<template>
<div class="input-group mx-1">    
  <div class="form-group">
    <div class="controls d-flex flex-wrap">
      <div class="btn-group me-auto btn-group-sm">
        <slot></slot>
        <select v-model="select_time_value" @change="change_select_time" class="form-select me-2">
                <!-- <option value="min_5">{{context.text.show_alerts_presets["5_min"]}}</option> -->
                <option value="min_5">{{i18n('show_alerts.presets.5_min')}}</option>
        
                <option value="min_30">{{i18n('show_alerts.presets.30_min')}}</option>
        
                <option value="hour">{{i18n('show_alerts.presets.hour')}}</option>
        
                <option value="day">{{i18n('show_alerts.presets.day')}}</option>
                <option value="week">{{i18n('show_alerts.presets.week')}}</option>
        
                <option value="month">{{i18n('show_alerts.presets.month')}}</option>
                <option value="year">{{i18n('show_alerts.presets.year')}}</option>
                <option value="custom">{{i18n('graphs.custom')}}</option>
        </select>
        
        <div class="btn-group">
            <span class="input-group-text">
                <i class="fas fa-calendar-alt"></i>
            </span>
            <input  class="flatpickr flatpickr-input" type="text" placeholder="Choose a date.." data-id="datetime" ref="begin-date">
            <!-- <input ref="begin-date" @change="enable_apply=true" @change="change_begin_date" type="date" class="date_time_input begin-timepicker form-control border-right-0 fix-safari-input"> -->
            <!-- <input ref="begin-time" @change="enable_apply=true" type="time" class="date_time_input begin-timepicker form-control border-right-0 fix-safari-input"> -->
            <span class="input-group-text">
                <i class="fas fa-long-arrow-alt-right"></i>
            </span>
            <input  class="flatpickr flatpickr-input" type="text" placeholder="Choose a date.." data-id="datetime" ref="end-date">
            <!-- <input ref="end-date" @change="enable_apply=true" type="date" class="date_time_input end-timepicker form-control border-left-0 fix-safari-input" style="width: 2.5rem;"> -->
            <!-- <input ref="end-time" @change="enable_apply=true" type="time" class="date_time_input end-timepicker form-control border-left-0 fix-safari-input"> -->
            <span v-show="wrong_date" :title="i18n('wrong_date_range')" style="margin-left:0.2rem;color:red;">
                <i class="fas fa-exclamation-circle"></i>
            </span>
        </div>

        <div class="d-flex align-items-center ms-2">
            <button :disabled="!enable_apply || wrong_date" @click="apply" class="btn btn-sm btn-primary">{{i18n('apply')}}</button>
                
            <div class="btn-group">
                <button @click="jump_time_back()" class="btn btn-sm btn-link" ref="btn-jump-time-back">
                <i class="fas fa-long-arrow-alt-left"></i>
                </button>
                <button @click="jump_time_ahead()" class="btn btn-sm btn-link me-2" ref="btn-jump-time-ahead">
                <i class="fas fa-long-arrow-alt-right"></i>
                </button>
                <button @click="zoom(2)" class="btn btn-sm btn-link" ref="btn-zoom-in">
                <i class="fas fa-search-plus"></i>
                </button>
                <button @click="zoom(0.5)" class="btn btn-sm btn-link" ref="btn-zoom-out">
                <i class="fas fa-search-minus"></i>
                </button>
            </div>
        </div>        
      </div>
    </div>
  </div>  
</div>
</template>

<script>
export default {
    components: {
    },
    props: {
	text: Object,
	id: String,
    },
    emits: ["epoch_change"],
    /** This method is the first method of the component called, it's called before html template creation. */
    created() {	
    },
    /** This method is the first method called after html template creation. */
    mounted() {
	let epoch_begin = ntopng_url_manager.get_url_entry("epoch_begin");
	let epoch_end = ntopng_url_manager.get_url_entry("epoch_end");
	if (epoch_begin != null && epoch_end != null) {
	    // update the status
            ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, { epoch_begin: Number.parseInt(epoch_begin), epoch_end: Number.parseInt(epoch_end) }, this.status_id);
	}
	let me = this;
	let f_set_picker = (picker, var_name) => {
	    return $(this.$refs[picker]).flatpickr({
	 	enableTime: true,
	 	dateFormat: "d-m-Y H:i",
		//locale: "it",
	 	//dateFormat: "Y-m-d H:i",
	 	time_24hr: true,
		clickOpens: true,
		//mode: "range",
	 	//static: true,
	 	onChange: function(selectedDates, dateStr, instance) {
	 	    let utc_s = me.get_utc_seconds(new Date(selectedDates).getTime());
		    //me[var_name] = utc_s;
		    me.enable_apply = true;
		    me.wrong_date = me.flat_begin_date.selectedDates[0].getTime() > me.flat_end_date.selectedDates[0].getTime();
	 	    //me.a[data] = d;
	 	},
	    });
	};
	this.flat_begin_date = f_set_picker("begin-date", "begin_date");
	this.flat_end_date = f_set_picker("end-date", "end_date");
	
        ntopng_events_manager.on_event_change(this.status_id, ntopng_events.EPOCH_CHANGE, (new_status) => this.on_status_updated(new_status), true);
	// notifies that component is ready
	ntopng_sync.ready(this.$props["id"]);
    },
    
    /** Methods of the component. */
    methods: {
        on_status_updated: function(status) {
            let end_date_time_utc = Date.now();        
            // default begin date time now - 30 minutes
            let begin_date_time_utc = end_date_time_utc - 30 * 60 * 1000;
            if (status.epoch_end != null && status.epoch_begin != null
		&& Number.parseInt(status.epoch_end) > Number.parseInt(status.epoch_begin)) {
		status.epoch_begin = Number.parseInt(status.epoch_begin);
		status.epoch_end = Number.parseInt(status.epoch_end);
                end_date_time_utc = status.epoch_end * 1000;
                begin_date_time_utc = status.epoch_begin * 1000;
            } else {
                status.epoch_end = this.get_utc_seconds(end_date_time_utc);
                status.epoch_begin = this.get_utc_seconds(begin_date_time_utc);
                this.emit_epoch_change(status, this.status_id);
            }
	    this.flat_begin_date.setDate(new Date(status.epoch_begin * 1000));
	    this.flat_end_date.setDate(new Date(status.epoch_end * 1000));
            // this.set_date_time("begin-date", begin_date_time_utc, false);
            // this.set_date_time("begin-time", begin_date_time_utc, true);
            // this.set_date_time("end-date", end_date_time_utc, false);
            // this.set_date_time("end-time", end_date_time_utc, true);
            this.set_select_time_value(begin_date_time_utc, end_date_time_utc);
            this.epoch_status = status;
            this.enable_apply = false;
	    ntopng_url_manager.add_obj_to_url({epoch_begin: status.epoch_begin, epoch_end: status.epoch_end});
        },
        set_select_time_value: function(begin_utc, end_utc) {
            let s_values = this.get_select_values();
            const tolerance = 60;
            const now = this.get_utc_seconds(Date.now());
            const end_utc_s = this.get_utc_seconds(end_utc);
            const begin_utc_s = this.get_utc_seconds(begin_utc);
            
            if (this.is_between(end_utc_s, now, tolerance)) {
                if (this.is_between(begin_utc_s, now - s_values.min_5, tolerance)) {
                    this.select_time_value = "min_5";
                } else if (this.is_between(begin_utc_s, now - s_values.min_30, tolerance)) {
                    this.select_time_value = "min_30";
                } else if (this.is_between(begin_utc_s, now - s_values.hour, tolerance)) {
                    this.select_time_value = "hour";
                } else if (this.is_between(begin_utc_s, now - s_values.day, tolerance)) {
                    this.select_time_value = "day";
                } else if (this.is_between(begin_utc_s, now - s_values.week, tolerance)) {
                    this.select_time_value = "week";
                } else if (this.is_between(begin_utc_s, now - s_values.month, tolerance)) {
                    this.select_time_value = "month";
                } else if (this.is_between(begin_utc_s, now - s_values.year, tolerance)) {
                    this.select_time_value = "year";
                } else {
                    this.select_time_value = "custom";
                }
            } else {
                this.select_time_value = "custom";
            }
            
        },
        apply: function() {
            // let date_begin = this.$refs["begin-date"].valueAsDate;
            // let d_time_begin = this.$refs["begin-time"].valueAsDate;
            // date_begin.setHours(d_time_begin.getHours());
            // date_begin.setMinutes(d_time_begin.getMinutes() + d_time_begin.getTimezoneOffset());
            // date_begin.setSeconds(d_time_begin.getSeconds());
            
            // let date_end = this.$refs["end-date"].valueAsDate;
            // let d_time_end = this.$refs["end-time"].valueAsDate;
            // date_end.setHours(d_time_end.getHours());
            // date_end.setMinutes(d_time_end.getMinutes() + d_time_end.getTimezoneOffset());
            // date_end.setSeconds(d_time_end.getSeconds());
            // let epoch_begin = this.get_utc_seconds(date_begin.valueOf());
            // let epoch_end = this.get_utc_seconds(date_end.valueOf());
	    let now_s = this.get_utc_seconds(Date.now());
	    let begin_date = this.flat_begin_date.selectedDates[0];
	    let epoch_begin = this.get_utc_seconds(begin_date.getTime());
	    let end_date = this.flat_end_date.selectedDates[0];
	    let epoch_end = this.get_utc_seconds(end_date.getTime());
	    if (epoch_end > now_s) {
		epoch_end = now_s;
	    }
            let status = { epoch_begin , epoch_end };
            this.emit_epoch_change(status);
        },
        set_date_time: function(ref_name, utc_ts, is_time) {
            utc_ts = this.get_utc_seconds(utc_ts) * 1000;        
            let date_time = new Date(utc_ts);
            date_time.setMinutes(date_time.getMinutes() - date_time.getTimezoneOffset());
	    if (is_time) {
		this.$refs[ref_name].value = date_time.toISOString().substring(11,16);
	    } else {
		this.$refs[ref_name].value = date_time.toISOString().substring(0,10);
	    }
        },
        change_select_time: function() {
            let s_values = this.get_select_values();
            let interval_s = s_values[this.select_time_value];
            let epoch_end = this.get_utc_seconds(Date.now());
            let epoch_begin = epoch_end - interval_s;
            let status = { epoch_begin: epoch_begin, epoch_end: epoch_end };
            this.emit_epoch_change(status);
        },
        get_select_values: function() {
            let min = 60;
            return {
                min_5: min * 5,
                min_30: min * 30,
                hour: min * 60,
                day: this.get_last_day_seconds(), 
                week: this.get_last_week_seconds(), 
                month: this.get_last_month_seconds(), 
                year: this.get_last_year_seconds(),
            };
        },
        get_utc_seconds: function(utc_ts) {
            return Number.parseInt(utc_ts / 1000);
        },
        is_between: function(x, y, tolerance) {
            return x >= y - tolerance && x <= y;
        },
        get_last_day_seconds: function() {
            let t = new Date();
            return this.get_utc_seconds(Date.now() - t.setDate(t.getDate() - 1));
        },
        get_last_week_seconds: function() {
            let t = new Date();
            return this.get_utc_seconds(Date.now() - t.setDate(t.getDate() - 7));
        },
        get_last_month_seconds: function() {
            let t = new Date();
            return this.get_utc_seconds(Date.now() - t.setMonth(t.getMonth() - 1));
        },
        get_last_year_seconds: function() {
            let t = new Date();
            return this.get_utc_seconds(Date.now() - t.setMonth(t.getMonth() - 12));
        },
        zoom: function(scale) {
            if (this.epoch_status == null) { return; }
            let interval = (this.epoch_status.epoch_end - this.epoch_status.epoch_begin) / scale;
            let center = (this.epoch_status.epoch_end / 2 + this.epoch_status.epoch_begin / 2);
            this.epoch_status.epoch_begin = center - interval / 2;
            this.epoch_status.epoch_end = center + interval / 2;
            let now = this.get_utc_seconds(Date.now());
            if (this.epoch_status.epoch_end > now) {
                this.epoch_status.epoch_end = now;
            }
            this.epoch_status.epoch_end = Number.parseInt(this.epoch_status.epoch_end);
            this.epoch_status.epoch_begin = Number.parseInt(this.epoch_status.epoch_begin);
            if (this.epoch_status.epoch_begin == this.epoch_status.epoch_end) {
                this.epoch_status.epoch_begin -= 2;
            }
            this.emit_epoch_change(this.epoch_status);
        },
        jump_time_back: function() {
            if (this.epoch_status == null) { return; }
            const min = 60;
            this.epoch_status.epoch_begin -= (30 * min);
            this.epoch_status.epoch_end -= (30 * min);
            this.emit_epoch_change(this.epoch_status);
        },
        jump_time_ahead: function() {
            if (this.epoch_status == null) { return; }
            const min = 60;
            let previous_end = this.epoch_status.epoch_end;
            let now = this.get_utc_seconds(Date.now());
            
            this.epoch_status.epoch_end += (30 * min);
            if (this.epoch_status.epoch_end > now) {
                this.epoch_status.epoch_end = now;
            }
            this.epoch_status.epoch_begin += (this.epoch_status.epoch_end - previous_end);
            this.emit_epoch_change(this.epoch_status);
        },
        emit_epoch_change: function(epoch_status, id) {
            if (epoch_status.epoch_end == null || epoch_status.epoch_begin == null) { return; };
            this.wrong_date = false;
            if (epoch_status.epoch_begin > epoch_status.epoch_end) {
                this.wrong_date = true;
		return;
            }
            this.$emit("epoch_change", epoch_status);
            ntopng_events_manager.emit_event(ntopng_events.EPOCH_CHANGE, epoch_status, id);
        },
        change_begin_date: function() {
        },
    },
    /**
       Private date of vue component.
    */
    data() {
        return {
	    i18n: (t) => i18n(t),
            status_id: "data-time-range-picker" + this._uid,
            epoch_status: null,
            enable_apply: false,
            select_time_value: "min_5",
            wrong_date: false,
	    flat_begin_date: null,
	    flat_end_date: null,
        };
    },
}

</script>

<style scoped>
.date_time_input {
  width: 10.5rem;
  max-width: 10.5rem;
  min-width: 10.5rem;
}
</style>

/**
    (C) 2022 - ntop.org    
*/

export const ntopng_sync = function() {
    let components_ready = {};
    let subscribers = [];        
    return {
	ready: function(component_name) {
	    components_ready[component_name] = true;
	    subscribers.filter((s) => s.component_name == component_name).forEach((s) => s.resolve());
	    subscribers = subscribers.filter((s) => s.component_name != component_name);
	},
	on_ready: function(component_name) {
	    return new Promise((resolve, rejevt) => {
		if (components_ready[component_name]) {
		    resolve();
		    return;
		}
		subscribers.push({resolve, component_name, completed: false});
	    });
	},
    };
}();

/**
* Utility globals functions.
*/
export const ntopng_utility = function() {

  return {	
      /**
       * Deep copy of a object.
       * @param {object} obj.
       * @returns {object}.
       */
      clone: function(obj) {
          if (obj == null) { return null; }
          return JSON.parse(JSON.stringify(obj));
      },
object_to_array: function(obj) {
    if (obj == null) { return []; }
    let array = [];
    for (let key in obj) {
  array.push(obj[key]);
    }
    return array;
},
      from_utc_to_server_date_format: function(utc_ms, format) {
	  if (format == null) { format = "DD/MMM/YYYY HH:mm"; }
	  let m = moment.tz(utc_ms, ntop_zoneinfo);
	  let m_local = moment(utc_ms);
	  let tz_local = m_local.format(format);
	  let tz_server = m.format(format);
	  return tz_server;
      },
is_object: function(e) {
  return typeof e === 'object'
    && !Array.isArray(e)
    && e !== null;
},
copy_object_keys: function(source_obj, dest_obj, recursive_object = false) {
  if (source_obj == null) {
    return;
  }
    for (let key in source_obj) {
	if (source_obj[key] == null) { continue; }
    if (recursive_object == true && this.is_object(source_obj[key]) && this.is_object(dest_obj[key])) {
      this.copy_object_keys(source_obj[key], dest_obj[key], recursive_object);
    } else {
      dest_obj[key] = source_obj[key];
    }
  }
},
http_request: async function(url, options, throw_exception, not_unwrap) {
    try {
  let res = await fetch(url, options);
  if (res.ok == false) {
      console.error(`http_request ${url}\n ok == false`);
      console.error(res);
      return null;
  }
  let json_res = await res.json();
	if (not_unwrap == true) { return json_res; }
  return json_res.rsp;
    } catch (err) {
  console.error(err);
  if (throw_exception == true) { throw err; }
  return null;
    }
},
  }
}();

/**
* Allows to manage the application global status.
* The status is incapsulated into the url.
*/
export const ntopng_status_manager = function() {
  let gloabal_status = {};
  /** @type {{ [id: string]: (status: object) => void}} */
  let subscribers = {}; // dictionary of { [id: string]: f_on_ntopng_status_change() }
  const clone = ntopng_utility.clone;

  const relplace_global_status = function(status) {
gloabal_status = status;
  }
  /**
   * Notifies the status to all subscribers with id different from skip_id.
   * @param {object} status object that represent the application status.
   * @param {string} skip_id if != null doesn't notify the subscribers with skip_id identifier.
   */
  const notify_subscribers = function(status, skip_id) {
      for (let id in subscribers) {
          if (id == skip_id) { continue; }
          let f_on_change = subscribers[id];
          f_on_change(clone(status));
      }
  };

  return {	
      /**
       * Gets the current global application status.
       * @returns {object}
       */
      get_status: function() {
    return clone(gloabal_status);
      },

update_subscribers: function() {
    const status = this.get_status();
    notify_subscribers(status);
},

      /**
       * Allows to subscribers f_on_change callback on status change event.
       * @param {string} id an identifier of the subscribtion. 
       * @param {(status:object) => void} f_on_change callback that take object status as param.
       * @param {boolean} get_init_notify if true the callback it's immediately called with the last status available.
       */
      on_status_change: function(id, f_on_change, get_init_notify) {
          subscribers[id] = f_on_change;
          if (get_init_notify == true) {
              let status = this.get_status();
              f_on_change(clone(status));
          }
      },

      /**
       * Raplaces the application status and notifies the new status to all subscribers.
       * Notifies the new status to all subscribers.
       * @param {Object} status object that represent the application status.
       * @param {string} skip_id if != null doesn't notify the subscribers with skip_id identifier.
       */
      replace_status: function(status, skip_id) {
    relplace_global_status(status);
          notify_subscribers(status, skip_id);
      },

      /**
       * Adds or replaces all obj param keys to the application status.
       * Notifies the new status to all subscribers.
       * @param {Object} obj object to add or edit to the application status. 
       * @param {string} skip_id if != null doesn't notify the subscribers with skip_id identifier.
       */
      add_obj_to_status: function(obj, skip_id) {
          let new_status = this.get_status();
    ntopng_utility.copy_object_keys(obj, new_status);
          this.replace_status(new_status, skip_id);
      },

      /**
       * Adds or replaces the value key to the application status.
       * Notifies the new status to all subscribers.
       * @param {string} key key to adds or replaces.
       * @param {any} value value to adds or replaces.
       * @param {*} skip_id if != null doesn't notify the subscribers with skip_id identifier.
       */
      add_value_to_status: function(key, value, skip_id) {
          let new_status = this.get_status();
          new_status[key] = value;
          // /* This is needed to have muliple filters for the same key */
          // (new_status[key] && new_status[key].search(value) === -1) ? new_status[key] += "," + value : new_status[key] = value
          
          this.replace_status(new_status, skip_id);
      },
  }
}();

const ntopng_params_url_serializer = {
  // filters: function(key, filters) {
  // 	if (filters == null) { return ""; }
  // 	let filters_groups = {};
  // 	filters.forEach((f) => {
  // 	    let group = filters_groups[f.id];
  // 	    if (group == null) {
  // 		group = [];
  // 		filters_groups[f.id] = group;
  // 	    }
  // 	    group.push(f);
  // 	});
  // 	let url_params_array = [];
  // 	for (let f_id in filters_groups) {
  // 	    let group = filters_groups[f_id];
  // 	    let url_values = group.filter((f) => f.value != null && f.operator != null && f.operator != "").map((f) => `${f.value};${f.operator}`).join(",");
  // 	    let url_params = ntopng_url_manager.serialize_param(f_id, url_values);
  // 	    url_params_array.push(url_params);
  // 	}
  // 	return url_params_array.join("&");
  // },
};

export const ntopng_url_manager = function() {
  /** @type {{ [key: string]: (obj: any) => string}} */
  let custom_params_serializer = {};
  ntopng_utility.copy_object_keys(ntopng_params_url_serializer, custom_params_serializer);
  
  return {
get_url_params: function() {
    return window.location.search.substring(1);
},
get_url_search_params: function(url) {
    if (url == null) {
  url = this.get_url_params();
    }
    // for(const [key, value] of entries) {
          const url_params = new URLSearchParams(url);
    return url_params;
},
get_url_entries: function(url) {
          const url_params = this.get_url_search_params(url);
          const entries = url_params.entries();
    return entries;
},	
get_url_entry: function(param_name) {
    let entries = this.get_url_entries();
    for(const [key, value] of entries) {
  if (key == param_name) { return value; }
    }
    return null;
},
get_url_object: function(url) {
    let entries = this.get_url_entries(url);
    let obj = {};
    for (const [key, value] of entries) {
  obj[key] = value;
    }
    return obj;
},
reload_url: function() {
    window.location.reload();
},
replace_url: function(url_params) {
          window.history.replaceState({}, null, `?${url_params}`);
},
replace_url_and_reload: function(url_params) {
    this.replace_url(url_params);
    this.reload_url();
},
serialize_param: function(key, value) {
    if (value == null) {
  value = "";
    }
    return `${key}=${encodeURIComponent(value)}`;
},	
set_custom_key_serializer: function(key, f_get_url_param) {
    custom_params_serializer[key] = f_get_url_param;
},

/**
 * Convert js object into a string that represent url params.
 * Uses custom serializer if set.
 * @param {object} obj.
 * @returns {string}.
 */
obj_to_url_params: function(obj) {
    let params = [];
    const default_serializer = this.serialize_param;
    for (let key in obj) {
  let serializer = custom_params_serializer[key];
  if (serializer == null) {
      serializer = default_serializer;
  }
  let param = serializer(key, obj[key]);
  params.push(param);
    }
    let url_params = params.join("&");
          return url_params;
},
delete_params: function(params_key) {
    let search_params = this.get_url_search_params();
    params_key.forEach((p) => {
  search_params.delete(p);
    });
    this.replace_url(search_params.toString());	    
},
set_key_to_url: function(key, value) {
    if (value == null) { value = ""; }	  
    let search_params = this.get_url_search_params();
    search_params.set(key, value);
    this.replace_url(search_params.toString());
},
add_obj_to_url: function(url_params_obj) {
    let new_url_params = this.obj_to_url_params(url_params_obj);
    let search_params = this.get_url_search_params();
    let new_entries = this.get_url_entries(new_url_params);
    for (const [key, value] of new_entries) {
  search_params.set(key, value);
    }
    this.replace_url(search_params.toString());
},
  }
}();
  
/**
* Object that represents a list of prefedefined events that represent the status.
*/
export const ntopng_events = {
  EPOCH_CHANGE: "epoch_change", // { epoch_begin: number, epoch_end: number }
  FILTERS_CHANGE: "filters_change", // {filters: {id: string, operator: string, value: string}[] }
};

const ntopng_events_compare = {
  EPOCH_CHANGE: function(new_status, old_status) {
return new_status.epoch_begin != old_status.epoch_begin
    || new_status.epoch_end != old_status.epoch_end;
  },
  FILTERS_CHANGE: function(new_status, old_status) {	
return (new_status.filters == null && old_status.filters != null)
    || (new_status.filters != null && old_status.filters == null)
    || (new_status.filters != null && old_status.filters != null &&
  (
      (new_status.filters.length != old_status.filters.length)
    || (new_status.filters.some((f_new) => old_status.filters.find((f_old) => f_old.id == f_new.id) == null))
  )
       );
  },
};

/**
* Object that represents a list of prefedefined custom events.
*/
export const ntopng_custom_events = {
  SHOW_MODAL_FILTERS: "show_modal_filters", // {id: string, operator: string, value: string}
  MODAL_FILTERS_APPLY: "modal_filters_apply", // {id: string, label: string, operator: string, value: string, value_label: string}
    SHOW_GLOBAL_ALERT_INFO: "show_global_alert_info", // html_text: string
};


/**
* A global events service that allows to manage the application global status.
* The status is incapsulated into the url.
*/
export const ntopng_events_manager = function() {
  const events_manager_id = "events_manager";
  let status = {};

  /** @type {{ [event_name: string]: { [id: string]: (status: object) => void}}} */
  let events_subscribers = {}; // dictionary of { [event_name: string]: { [id: string]: f_on_event }

  const clone = ntopng_utility.clone;

  /**
   * Notifies the status to all subscribers with id different from skip_id.
   * @param {{ [id: string]: (status: object) => void}} subscribers dictionary of id => f_on_event().
   * @param {object} status object that represent the application status.
   * @param {string} skip_id if != null doesn't notify the subscribers with skip_id identifier.
   */
  const notify_subscribers = function(subscribers, status, skip_id) {
      for (let id in subscribers) {
          if (id == skip_id) { continue; }
          let f_on_change = subscribers[id];
          f_on_change(clone(status));
      }
  };

  /**
   * A callback that dispatches each event to all subscribers.
   * @param {object} new_status 
   */
  const on_status_change = function(new_status) {
for (let event_name in ntopng_events) {
    let f_compare = ntopng_events_compare[event_name];
    if (f_compare(new_status, status) == true) {
  let subscribers = events_subscribers[event_name];
  notify_subscribers(subscribers, new_status);
    }
}

      status = new_status;
  };

  ntopng_status_manager.on_status_change(events_manager_id, on_status_change, true);

  const emit = function(event, params, skip_id) {
let subscribers = events_subscribers[event];
if (subscribers == null) { return; }
notify_subscribers(subscribers, params, skip_id);
  };

  const on_event = function(id, event, f_on_event, get_init_notify) {
      if (events_subscribers[event] == null) {
          events_subscribers[event] = {};        
      }
      if (get_init_notify == true) {
          let status = ntopng_status_manager.get_status();        
          f_on_event(clone(status));
      }
      events_subscribers[event][id] = f_on_event;
  };

  return {
emit_custom_event: function(event, params) {
    emit(event, params);
},
on_custom_event: function(id, event, f_on_event) {
    on_event(id, event, f_on_event);
},
      /**
       * Changes the application status and emits the new status to all subcribers registered to the event. 
       * @param {string} event event name.
       * @param {object} new_status object to add or edit to the application status.
       * @param {string} skip_id if != null doesn't notify the subscribers with skip_id identifier.
       */
      emit_event: function(event, new_status, skip_id) {
    emit(event, new_status, skip_id)
          ntopng_status_manager.add_obj_to_status(new_status, events_manager_id);
      },
      /**
       * Allows to subscribers f_on_event callback on status change on event event_name.
       * @param {string} id an identifier of the subscribtion. 
       * @param {string} event event name. 
       * @param {(status:object) => void} f_on_event callback that take object status as param.
       * @param {boolean} get_init_notify if true the callback it's immediately called with the last status available.
       */
      on_event_change: function(id, event, f_on_event, get_init_notify) {
    on_event(id, event, f_on_event, get_init_notify);
      },
  }    
}();

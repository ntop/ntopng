/**
    (C) 2022 - ntop.org    
*/

/**
 * Utility globals functions.
 */
const ntopng_utility = function() {
    return {
        /**
         * Deep copy of a object.
         * @param {object} obj 
         * @returns {object}
         */
        clone: function(obj) {
            if (obj == null) { return null; }
            return JSON.parse(JSON.stringify(obj));
        }
    };
}();

/**
 * Allows to manage the application global status.
 * The status is incapsulated into the url.
 */
const ntopng_status_manager = function() {
    /** @type {{ [id: string]: (status: object) => void}} */
    let subscribers = {}; // dictionary of { [id: string]: f_on_ntopng_status_change() }

    /**
     * Convert js object into a string that represent url params.
     * @param {object} obj
     */
    const obj_to_url_params = function(obj) {
        let s = "";
        for (let key in obj) {
            if (s != "") {
                s += "&";
            }
            s += (key + "=" + encodeURIComponent(obj[key]));
        }
        return s;
    };

    /**
     * Gets js object from url params.
     * @param {*} entries 
     * @returns {object}
     */
    const url_params_to_object = function(entries) {
        const result = {}
        for(const [key, value] of entries) {
            result[key] = value;
        }
        return result;
    };

    const clone = ntopng_utility.clone;
    
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
	obj_to_url_params: obj_to_url_params,
	
        /**
         * Gets the current global application status.
         * @returns {object}
         */
        get_status: function() {
            const url_params = new URLSearchParams(window.location.search.substring(1));
            const entries = url_params.entries(); 
            const params = url_params_to_object(entries);
            return params;
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
            let url_params = "?" + obj_to_url_params(status);
            window.history.replaceState({}, null, url_params);
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
            for (let key in obj) {
                new_status[key] = obj[key];
            }
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
            this.replace_status(new_status, skip_id);
        },
    }
}();

/**
 * Object that represents a list of prefedefined events
 */
const ntopng_events = {
    EPOCH_CHANGE: "epoch_change" // { epoch_begin: number, epoch_end: number }
};

/**
 * A global events service that allows to manage the application global status.
 * The status is incapsulated into the url.
 */
const ntopng_events_manager = function() {
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
        if (status.epoch_end != new_status.epoch_end || status.epoch_begin != new_status.epoch_begin) {
            let subscribers = events_subscribers[ntopng_events.EPOCH_CHANGE];
            notify_subscribers(subscribers, new_status);
        }
        status = new_status;
    };

    ntopng_status_manager.on_status_change(events_manager_id, on_status_change, true);

    return {
        /**
         * Changes the application status and emits the new status to all subcribers registered to the event. 
         * @param {string} event event name.
         * @param {object} new_status object to add or edit to the application status.
         * @param {string} skip_id if != null doesn't notify the subscribers with skip_id identifier.
         */
        emit_event: function(event, new_status, skip_id) {
            ntopng_status_manager.add_obj_to_status(new_status, events_manager_id);
            status = ntopng_status_manager.get_status();
            let subscribers = events_subscribers[event];
            if (subscribers == null) { return; }
            notify_subscribers(subscribers, new_status, skip_id);
        },
    
        /**
         * Allows to subscribers f_on_event callback on status change on event event_name.
         * @param {string} id an identifier of the subscribtion. 
         * @param {string} event_name event name. 
         * @param {(status:object) => void} f_on_event callback that take object status as param.
         * @param {boolean} get_init_notify if true the callback it's immediately called with the last status available.
         */
        on_event_change: function(id, event_name, f_on_event, get_init_notify) {
            if (events_subscribers[event_name] == null) {
                events_subscribers[event_name] = {};        
            }
            if (get_init_notify == true) {
                let status = ntopng_status_manager.get_status();        
                f_on_event(clone(status));
            }
            events_subscribers[event_name][id] = f_on_event;
        },
    }    
}();

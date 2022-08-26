/**
    (C) 2022 - ntop.org    
*/

export const ntopng_map_manager = {
  /**
   * Change the status of a service.
   * @param {string} service_id id of the service.
   * @param {string} new_state id of the new status of the service.
   * @param {function} callback function to be called on success.
   */
  toggle_state: function(service_id, new_state, callback, csrf) {
    const request = $.post(`${http_prefix}/lua/pro/enterprise/switch_service_state.lua`, { 
      service_id: service_id, service_status: new_state, csrf: csrf
    });
    request.then((data) => {
      if(data.success && callback) 
        callback();
    });
  }
}

/*
 *
 * (C) 2015-21 - ntop.org
 *
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *
 */

#include "ntop_includes.h"

/* Keep these constants in sync with hosts_control.lua */
#define ALERT_EXCLUSIONS_KEY_PREFIX "ntopng.prefs.alert_exclusions"

/* *************************************** */

AlertExclusions::AlertExclusions() {
  init_tstamp = time(NULL);
  host_filters = new (std::nothrow) AddressTree();
  loadConfiguration();
}

/* *************************************** */

static void free_ptree_bitmap(void *data) {
  if(data) {
    Bitmap *host_filter = static_cast<Bitmap*>(data);  
    delete host_filter;
  }   
}

/* *************************************** */

AlertExclusions::~AlertExclusions() {
  if (host_filters) {
    host_filters->cleanup(free_ptree_bitmap);
    delete host_filters;
  }
}

/* *************************************** */

bool AlertExclusions::addHostDisabledFlowAlert(const char * const host, FlowAlertTypeEnum disabled_flow_alert_type) {
  Bitmap *host_filter = NULL;
  void *host_data;
  bool success = false;

  if (host_filters == NULL)
    return false;

  /* Check if there is already a bitmap for the host */
  host_data = host_filters->matchAndGetData(host);

  if (host_data) {
    host_filter = static_cast<Bitmap*>(host_data);
  } else {
    /* Accolate a bitmap for the host */
    host_filter = new (std::nothrow) Bitmap();
    if (host_filter)
      host_filters->addAddressAndData(host, host_filter);
  }

  if (host_filter) {
    /* Add filter to the bitmap */
    host_filter->setBit(disabled_flow_alert_type);
    success = true;
  }

  return success;
}

/* *************************************** */

void AlertExclusions::setDisabledFlowAlertsBitmap(IpAddress *addr, Bitmap *host_b) const {
  const Bitmap *b = &default_host_filter;

  if (host_filters != NULL && addr != NULL) {
    void *host_data = host_filters->matchAndGetData(addr);
    if (host_data != NULL)
      b = static_cast<Bitmap*>(host_data);
  }

  host_b->set(b);
}

/* *************************************** */

void AlertExclusions::loadConfiguration() {
  json_object *json = NULL;
  struct json_object_iterator it;
  struct json_object_iterator itEnd;
  enum json_tokener_error jerr = json_tokener_success;
  char *value = NULL;
  u_int actual_len = ntop->getRedis()->len(ALERT_EXCLUSIONS_KEY_PREFIX);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reloading alert exclusions"); 

  if((value = (char *) malloc(actual_len + 1)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory to deserialize %s", ALERT_EXCLUSIONS_KEY_PREFIX);
    goto out;
  }

  if(ntop->getRedis()->get((char*)ALERT_EXCLUSIONS_KEY_PREFIX, value, actual_len + 1) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to find %s", ALERT_EXCLUSIONS_KEY_PREFIX);
    goto out;
  }

  if((json = json_tokener_parse_verbose(value, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "JSON Parse error [%s] %s [len: %u][strlen: %u]",
				 json_tokener_error_desc(jerr), value, actual_len, strlen(value));
    goto out;
  }

  /* Iterate over all alert exclusions */
  it = json_object_iter_begin(json);
  itEnd = json_object_iter_end(json);

  while(!json_object_iter_equal(&it, &itEnd)) {
    const char *alert_key     = json_object_iter_peek_name(&it);
    json_object *alert_config = json_object_iter_peek_value(&it);
    json_object *excluded_hosts;

    if(json_object_object_get_ex(alert_config, "excluded_hosts", &excluded_hosts)) {
      /* For each alert, iterate over all its excluded hosts */
      struct json_object_iterator hosts_it = json_object_iter_begin(excluded_hosts);
      struct json_object_iterator hosts_it_end = json_object_iter_end(excluded_hosts);

      while(!json_object_iter_equal(&hosts_it, &hosts_it_end)) {
	const char *host_ip = json_object_iter_peek_name(&hosts_it);

	/* Add the exclusion for this alert and for this host */
	addHostDisabledFlowAlert(host_ip, (FlowAlertTypeEnum)atoi(alert_key));

	json_object_iter_next(&hosts_it);
      }
    }

    /* Move to the next element */
    json_object_iter_next(&it);
  } /* while */

 out:
  /* Free the json */
  if(json)  json_object_put(json);
  if(value) free(value);
}

/* *************************************** */

bool AlertExclusions::checkChange(time_t *last_change) const {
  bool changed = false;

  if(*last_change < init_tstamp)
    changed = true, *last_change = init_tstamp;

  return changed;
}

/* *************************************** */

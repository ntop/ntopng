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

static void free_excl_host_tree_data(void *data) {
  alert_exclusion_host_tree_data *d = (alert_exclusion_host_tree_data *) data;

  if(d) {
    if (d->host_alert_filter) delete d->host_alert_filter;
    if (d->flow_alert_filter) delete d->flow_alert_filter;
    free(d);
  }   
}

/* *************************************** */

AlertExclusions::~AlertExclusions() {
  if (host_filters) {
    host_filters->cleanup(free_excl_host_tree_data);
    delete host_filters;
  }
}

/* *************************************** */

alert_exclusion_host_tree_data *AlertExclusions::getHostData(const char * const host) {
  alert_exclusion_host_tree_data *d;

  if (host_filters == NULL)
    return NULL;

  /* Check if there is already a bitmap for the host */
  d = (alert_exclusion_host_tree_data *) host_filters->matchAndGetData(host);

  if (!d) {
    /* Allocate data for the host */
    d = (alert_exclusion_host_tree_data *) calloc(1, sizeof(*d));
    if (!d) return NULL; /* allocation failure */
    host_filters->addAddressAndData(host, d);
  }

  return d;
}

/* *************************************** */

bool AlertExclusions::addHostDisabledHostAlert(const char * const host, HostAlertTypeEnum disabled_host_alert_type) {
  alert_exclusion_host_tree_data *d = getHostData(host);

  if (!d)
    return false;

  if (!d->host_alert_filter) {
    /* Allocate a bitmap for the host */
    d->host_alert_filter = new (std::nothrow) Bitmap16();
    if (!d->host_alert_filter) return false; /* allocation failure */
  }

  /* Add filter to the bitmap */
  d->host_alert_filter->setBit(disabled_host_alert_type);

  return true;
}

/* *************************************** */

bool AlertExclusions::addHostDisabledFlowAlert(const char * const host, FlowAlertTypeEnum disabled_flow_alert_type) {
  alert_exclusion_host_tree_data *d = getHostData(host);

  if (!d)
    return false;

  if (!d->flow_alert_filter) {
    /* Allocate a bitmap for the host */
    d->flow_alert_filter = new (std::nothrow) Bitmap128();
    if (!d->flow_alert_filter) return false; /* allocation failure */
  }

  /* Add filter to the bitmap */
  d->flow_alert_filter->setBit(disabled_flow_alert_type);

  return true;
}

/* *************************************** */

void AlertExclusions::setDisabledHostAlertsBitmaps(IpAddress *addr, Bitmap16 *host_alerts, Bitmap128 *flow_alerts) const {
  const Bitmap16 *hb = &default_host_host_alert_filter;
  const Bitmap128 *fb = &default_host_flow_alert_filter;

  if (host_filters != NULL && addr != NULL) {
    alert_exclusion_host_tree_data *d = (alert_exclusion_host_tree_data *) host_filters->matchAndGetData(addr);
    if (d) {
      if (d->host_alert_filter) hb = d->host_alert_filter;
      if (d->flow_alert_filter) fb = d->flow_alert_filter;
    }
  }

  host_alerts->set(hb);
  flow_alerts->set(fb);
}

/* *************************************** */

void AlertExclusions::loadConfiguration() {
  json_object *json = NULL;
  struct json_object_iterator entity_it;
  struct json_object_iterator entity_itEnd;
  enum json_tokener_error jerr = json_tokener_success;
  char *value = NULL;
  u_int actual_len = ntop->getRedis()->len(ALERT_EXCLUSIONS_KEY_PREFIX);

  // ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reloading alert exclusions");

  if((value = (char *) malloc(actual_len + 1)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory to deserialize %s", ALERT_EXCLUSIONS_KEY_PREFIX);
    goto out;
  }

  if(ntop->getRedis()->get((char*)ALERT_EXCLUSIONS_KEY_PREFIX, value, actual_len + 1) != 0) {
    //ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to find %s", ALERT_EXCLUSIONS_KEY_PREFIX);
    goto out;
  }

  if((json = json_tokener_parse_verbose(value, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "JSON Parse error [%s] %s [len: %u][strlen: %u]",
				 json_tokener_error_desc(jerr), value, actual_len, strlen(value));
    goto out;
  }

  /* Iterate over all alert entities */
  entity_it = json_object_iter_begin(json);
  entity_itEnd = json_object_iter_end(json);

  while(!json_object_iter_equal(&entity_it, &entity_itEnd)) {
    const char *alert_entity_id  = json_object_iter_peek_name(&entity_it);
    json_object *entity_config = json_object_iter_peek_value(&entity_it);

    /* Take the alert entity from the key */
    AlertEntity alert_entity = (AlertEntity)atoi(alert_entity_id);

    /* Iterate over all entity alert exclusions */
    struct json_object_iterator excl_it = json_object_iter_begin(entity_config);
    struct json_object_iterator excl_itEnd = json_object_iter_end(entity_config);

    while(!json_object_iter_equal(&excl_it, &excl_itEnd)) {
      const char *alert_key     = json_object_iter_peek_name(&excl_it);
      json_object *alert_config = json_object_iter_peek_value(&excl_it);
      json_object *excluded_hosts;

      if(json_object_object_get_ex(alert_config, "excluded_hosts", &excluded_hosts)) {
	/* For each alert, iterate over all its excluded hosts */
	struct json_object_iterator hosts_it = json_object_iter_begin(excluded_hosts);
	struct json_object_iterator hosts_it_end = json_object_iter_end(excluded_hosts);

	while(!json_object_iter_equal(&hosts_it, &hosts_it_end)) {
	  const char *host_ip = json_object_iter_peek_name(&hosts_it);

	  /* Add the exclusion for this alert and for this host */
	  switch(alert_entity) {
	  case alert_entity_flow:
	    addHostDisabledFlowAlert(host_ip, (FlowAlertTypeEnum)atoi(alert_key));
	    break;
	  case alert_entity_host:
	    addHostDisabledHostAlert(host_ip, (HostAlertTypeEnum)atoi(alert_key));
	  default:
	    break;
	  }

#if 0
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Exclusion loaded [%s][alert_entity: %u][alert_key: %u]",
				       host_ip, alert_entity, atoi(alert_key));
#endif

	  json_object_iter_next(&hosts_it);
	}
      }

      /* Move to the next element */
      json_object_iter_next(&excl_it);
    } /* EXCLUSIONS while */

    /* Move to the next element */
    json_object_iter_next(&entity_it);
  } /* ENTITIES while */

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

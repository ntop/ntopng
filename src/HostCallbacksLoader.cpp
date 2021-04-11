/*
 *
 * (C) 2013-21 - ntop.org
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
#include "host_callbacks_includes.h"

/* **************************************************** */

HostCallbacksLoader::HostCallbacksLoader() : CallbacksLoader() {
}

/* **************************************************** */

HostCallbacksLoader::~HostCallbacksLoader() {
  for(std::map<std::string, HostCallback*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it)
    delete it->second;
}

/* **************************************************** */

void HostCallbacksLoader::registerCallbacks() {
  /* TODO: implement dynamic loading */
  HostCallback *fcb;

  if((fcb = new FlowFlood()))                  cb_all[fcb->getName()] = fcb;
  if((fcb = new SYNScan()))                    cb_all[fcb->getName()] = fcb;
  if((fcb = new SYNFlood()))                   cb_all[fcb->getName()] = fcb;
  if((fcb = new DNSServerContacts()))          cb_all[fcb->getName()] = fcb;
  if((fcb = new SMTPServerContacts()))         cb_all[fcb->getName()] = fcb;
  if((fcb = new NTPServerContacts()))          cb_all[fcb->getName()] = fcb;
  if((fcb = new P2PTraffic()))                 cb_all[fcb->getName()] = fcb;
  if((fcb = new DNSTraffic()))                 cb_all[fcb->getName()] = fcb;
  if((fcb = new FlowAnomaly()))                cb_all[fcb->getName()] = fcb;

#ifdef NTOPNG_PRO
  if((fcb = new DNSRepliesRequestsRatio()))    cb_all[fcb->getName()] = fcb;
  if((fcb = new ScoreHostCallback()))          cb_all[fcb->getName()] = fcb;
#endif

  // printCallbacks();
}

/* **************************************************** */

void HostCallbacksLoader::loadConfiguration() {
  json_object *json = NULL, *json_config, *json_config_host;
  struct json_object_iterator it;
  struct json_object_iterator itEnd;
  enum json_tokener_error jerr = json_tokener_success;
  char *value = NULL;
  u_int actual_len = ntop->getRedis()->len(CALLBACKS_CONFIG); // TODO: check if this is the right place

  if((value = (char *) malloc(actual_len + 1)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory to deserialize %s", CALLBACKS_CONFIG);
    goto out;
  }

  if(ntop->getRedis()->get((char*)CALLBACKS_CONFIG, value, actual_len + 1) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to find configuration %s", CALLBACKS_CONFIG);
    goto out;
  }

  if((json = json_tokener_parse_verbose(value, &jerr)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "JSON Parse error [%s] %s [len: %u][strlen: %u]",
				 json_tokener_error_desc(jerr), value, actual_len, strlen(value));
    goto out;
  }

  if(!json_object_object_get_ex(json, "config", &json_config)) {
    /* 'config' section inside the JSON */
    ntop->getTrace()->traceEvent(TRACE_ERROR, "'config' not found in JSON");
    goto out;
  }

  if(!json_object_object_get_ex(json_config, "host", &json_config_host)) {
    /* 'host' section inside 'config' JSON */
    ntop->getTrace()->traceEvent(TRACE_ERROR, "'host' not found in 'config' JSON");
    goto out;
  }

  /*
    Iterate over all script configurations
  */
  it = json_object_iter_begin(json_config_host);
  itEnd = json_object_iter_end(json_config_host);

  while(!json_object_iter_equal(&it, &itEnd)) {
    const char *callback_key   = json_object_iter_peek_name(&it);
    json_object *callback_config = json_object_iter_peek_value(&it);
    json_object *json_script_conf, *json_hook_all;

    /* Periodicities that are currently available for user scripts */
    static std::map<std::string, u_int32_t> hooks = {{"min", 60}, {"5mins", 300}};

    for(std::map<std::string, u_int32_t>::const_iterator it = hooks.begin(); it != hooks.end(); ++it) {
      if(json_object_object_get_ex(callback_config, it->first.c_str() /* This is either "min" or "5mins" */, &json_hook_all)) {
	json_object *json_enabled;
	bool enabled;

	if(cb_all.find(callback_key) != cb_all.end()) {
	  HostCallback *cb = cb_all[callback_key];

	  if(json_object_object_get_ex(json_hook_all, "enabled", &json_enabled))
	    enabled = json_object_get_boolean(json_enabled);
	  else
	    enabled = false;

	  if(enabled) {
	    /* Script enabled */
	    if(json_object_object_get_ex(json_hook_all, "script_conf", &json_script_conf)) {
	      if(cb_all.find(callback_key) != cb_all.end()) {
		HostCallback *cb = cb_all[callback_key];

		if(cb->loadConfiguration(json_script_conf)) {
		  ntop->getTrace()->traceEvent(TRACE_INFO, "Successfully enabled callback %s for %s", callback_key, it->first.c_str());
		} else {
		  ntop->getTrace()->traceEvent(TRACE_ERROR, "Error while loading callback %s configuration for %s",
					       callback_key, it->first.c_str());
		}

		cb->enable(it->second /* This is the periodicity in seconds */);
		cb->scriptEnable(); 
	      }
	    }
	  } else {
	    /* Script disabled */
	    cb->scriptDisable(); 
	  }
	} else {
	  ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to find host callback  %s", callback_key);
	}
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

/* **************************************************** */

void HostCallbacksLoader::printCallbacks() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Available Callbacks:");

  for(std::map<std::string, HostCallback*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "\t%s", it->first.c_str());
}

/* **************************************************** */

std::list<HostCallback*>* HostCallbacksLoader::getCallbacks(NetworkInterface *iface) {
  std::list<HostCallback*> *l = new std::list<HostCallback*>;

  for(std::map<std::string, HostCallback*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it) {
    HostCallback *cb = it->second;

    if(cb->isEnabled())
      cb->addCallback(l, iface);
  }

  return(l);
}

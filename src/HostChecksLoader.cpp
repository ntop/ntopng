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
#include "host_checks_includes.h"

/* **************************************************** */

HostChecksLoader::HostChecksLoader() : ChecksLoader() {
}

/* **************************************************** */

HostChecksLoader::~HostChecksLoader() {
  for(std::map<std::string, HostCheck*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it)
    delete it->second;
}

/* **************************************************** */

void HostChecksLoader::registerCheck(HostCheck *cb) {
  if(cb_all.find(cb->getName()) != cb_all.end()) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Ignoring duplicate host check %s", cb->getName().c_str());
    delete cb;
  } else
    cb_all[cb->getName()] = cb;
}

/* **************************************************** */

void HostChecksLoader::registerChecks() {
  /* TODO: implement dynamic loading */
  HostCheck *fcb;

  if((fcb = new FlowFlood()))                  registerCheck(fcb);
  if((fcb = new SYNScan()))                    registerCheck(fcb);
  if((fcb = new SYNFlood()))                   registerCheck(fcb);
  if((fcb = new DNSServerContacts()))          registerCheck(fcb);
  if((fcb = new SMTPServerContacts()))         registerCheck(fcb);
  if((fcb = new NTPServerContacts()))          registerCheck(fcb);
  if((fcb = new P2PTraffic()))                 registerCheck(fcb);
  if((fcb = new DNSTraffic()))                 registerCheck(fcb);
  if((fcb = new RemoteConnection()))           registerCheck(fcb);
  if((fcb = new DangerousHost()))              registerCheck(fcb);

#ifdef NTOPNG_PRO
  if((fcb = new ScoreAnomaly()))               registerCheck(fcb);
  if((fcb = new FlowAnomaly()))                registerCheck(fcb);
#endif

  // printChecks();
}

/* **************************************************** */

void HostChecksLoader::loadConfiguration() {
  json_object *json = NULL, *json_config, *json_config_host;
  struct json_object_iterator it;
  struct json_object_iterator itEnd;
  enum json_tokener_error jerr = json_tokener_success;
  char *value = NULL;
  u_int actual_len = ntop->getRedis()->len(CHECKS_CONFIG); // TODO: check if this is the right place

  if((value = (char *) malloc(actual_len + 1)) == NULL) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to allocate memory to deserialize %s", CHECKS_CONFIG);
    goto out;
  }

  if(ntop->getRedis()->get((char*)CHECKS_CONFIG, value, actual_len + 1) != 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to find configuration %s", CHECKS_CONFIG);
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
    const char *check_key   = json_object_iter_peek_name(&it);
    json_object *check_config = json_object_iter_peek_value(&it);
    json_object *json_script_conf, *json_hook_all;

    /* Periodicities that are currently available for user scripts */
    static std::map<std::string, u_int32_t> hooks = {{"min", 60}, {"5mins", 300}};

    for(std::map<std::string, u_int32_t>::const_iterator it = hooks.begin(); it != hooks.end(); ++it) {
      if(json_object_object_get_ex(check_config, it->first.c_str() /* This is either "min" or "5mins" */, &json_hook_all)) {
	json_object *json_enabled;
	bool enabled;

	if(cb_all.find(check_key) != cb_all.end()) {
	  HostCheck *cb = cb_all[check_key];

	  if(!cb->isCheckCompatibleWithEdition()) {
	    ntop->getTrace()->traceEvent(TRACE_INFO, "Check not compatible with current edition [check: %s]", check_key);
	    continue;
	  }

	  if(json_object_object_get_ex(json_hook_all, "enabled", &json_enabled))
	    enabled = json_object_get_boolean(json_enabled);
	  else
	    enabled = false;

	  if(!enabled) {
	    ntop->getTrace()->traceEvent(TRACE_INFO, "Skipping check not enabled [check: %s]", check_key);
	    continue;
	  }

	  /* Script enabled */
	  if(json_object_object_get_ex(json_hook_all, "script_conf", &json_script_conf)) {
	    if(cb->loadConfiguration(json_script_conf)) {
	      ntop->getTrace()->traceEvent(TRACE_INFO, "Successfully enabled check %s for %s", check_key, it->first.c_str());
	    } else {
	      ntop->getTrace()->traceEvent(TRACE_ERROR, "Error while loading check %s configuration for %s",
					   check_key, it->first.c_str());
	    }

	    cb->enable(it->second /* This is the periodicity in seconds */);
	    cb->scriptEnable(); 
	  } else {
	    ntop->getTrace()->traceEvent(TRACE_ERROR, "Error while loading check configuration for %s", check_key);
	    /* Script disabled */
	    cb->scriptDisable(); 
	  }
	} else {
	  ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to find host check %s", check_key);
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

void HostChecksLoader::printChecks() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Available Checks:");

  for(std::map<std::string, HostCheck*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "\t%s", it->first.c_str());
}

/* **************************************************** */

std::list<HostCheck*>* HostChecksLoader::getChecks(NetworkInterface *iface) {
  std::list<HostCheck*> *l = new std::list<HostCheck*>;

  for(std::map<std::string, HostCheck*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it) {
    HostCheck *cb = it->second;

    if(cb->isEnabled())
      cb->addCheck(l, iface);
  }

  return(l);
}

/* **************************************************** */

bool HostChecksLoader::luaCheckInfo(lua_State* vm, std::string check_name) const {
  std::map<std::string, HostCheck*>::const_iterator it = cb_all.find(check_name);

  if(it == cb_all.end())
    return false;

  lua_newtable(vm);
  lua_push_str_table_entry(vm, "edition", Utils::edition2name(it->second->getEdition()));
  lua_push_str_table_entry(vm, "key", it->second->getName().c_str());

  return true;
}

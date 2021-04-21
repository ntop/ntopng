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
#include "flow_callbacks_includes.h"

/* **************************************************** */

FlowCallbacksLoader::FlowCallbacksLoader() : CallbacksLoader() {
}

/* **************************************************** */

FlowCallbacksLoader::~FlowCallbacksLoader() {
  for(std::map<std::string, FlowCallback*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it)
    delete it->second;
}

/* **************************************************** */

void FlowCallbacksLoader::registerCallback(FlowCallback *cb) {
  if(cb_all.find(cb->getName()) != cb_all.end()) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Ignoring duplicate flow callback %s", cb->getName().c_str());
    delete cb;
  } else
    cb_all[cb->getName()] = cb;
  
}
/* **************************************************** */

void FlowCallbacksLoader::registerCallbacks() {
  /* TODO: implement dynamic loading */
  FlowCallback *fcb;

  if((fcb = new BlacklistedFlow()))                             registerCallback(fcb);
  if((fcb = new BlacklistedCountry()))                          registerCallback(fcb);
  if((fcb = new DeviceProtocolNotAllowed()))                    registerCallback(fcb);
#ifndef NTOPNG_PRO
  if((fcb = new ExternalAlertCheck()))                          registerCallback(fcb);
#endif
  if((fcb = new FlowRiskBinaryApplicationTransfer()))           registerCallback(fcb);
  if((fcb = new FlowRiskDNSSuspiciousTraffic()))                registerCallback(fcb);
  if((fcb = new FlowRiskHTTPNumericIPHost()))                   registerCallback(fcb);
  if((fcb = new FlowRiskHTTPSuspiciousHeader()))                registerCallback(fcb);
  if((fcb = new FlowRiskHTTPSuspiciousUserAgent()))             registerCallback(fcb);
  if((fcb = new FlowRiskHTTPSuspiciousURL()))                   registerCallback(fcb);
  if((fcb = new FlowRiskKnownProtocolOnNonStandardPort()))      registerCallback(fcb);
  if((fcb = new FlowRiskMalformedPacket()))                     registerCallback(fcb);
  if((fcb = new FlowRiskSMBInsecureVersion()))                  registerCallback(fcb);
  if((fcb = new FlowRiskSSHObsolete()))                         registerCallback(fcb);
  if((fcb = new FlowRiskSuspiciousDGADomain()))                 registerCallback(fcb);
  if((fcb = new FlowRiskTLSMissingSNI()))                       registerCallback(fcb);
  if((fcb = new FlowRiskTLSNotCarryingHTTPS()))                 registerCallback(fcb);
  if((fcb = new FlowRiskTLSSuspiciousESNIUsage()))              registerCallback(fcb);
  if((fcb = new FlowRiskUnsafeProtocol()))                      registerCallback(fcb);
  if((fcb = new FlowRiskURLPossibleXSS()))                      registerCallback(fcb);
  if((fcb = new FlowRiskURLPossibleRCEInjection()))             registerCallback(fcb);
  if((fcb = new FlowRiskURLPossibleSQLInjection()))             registerCallback(fcb);
  if((fcb = new IECUnexpectedTypeId()))                         registerCallback(fcb);
  if((fcb = new IECInvalidTransition()))                        registerCallback(fcb);
  if((fcb = new LowGoodputFlow()))                              registerCallback(fcb);
  if((fcb = new NotPurged()))                                   registerCallback(fcb);  
  if((fcb = new RemoteAccess()))                                registerCallback(fcb);
  if((fcb = new RemoteToLocalInsecureProto()))                  registerCallback(fcb);
  if((fcb = new RemoteToRemote()))                              registerCallback(fcb);
  if((fcb = new TCPZeroWindow()))                               registerCallback(fcb);
  if((fcb = new TCPNoDataExchanged()))                          registerCallback(fcb);
  if((fcb = new UDPUnidirectional()))                           registerCallback(fcb);
  if((fcb = new UnexpectedDNSServer()))                         registerCallback(fcb);
  if((fcb = new UnexpectedDHCPServer()))                        registerCallback(fcb);
  if((fcb = new UnexpectedNTPServer()))                         registerCallback(fcb);
  if((fcb = new UnexpectedSMTPServer()))                        registerCallback(fcb);
  if((fcb = new WebMining()))                                   registerCallback(fcb);

#ifdef NTOPNG_PRO
  if((fcb = new DataExfiltration()))                            registerCallback(fcb);
  if((fcb = new DNSDataExfiltration()))                         registerCallback(fcb);
  if((fcb = new ElephantFlow()))                                registerCallback(fcb);
  if((fcb = new PotentiallyDangerous()))                        registerCallback(fcb);
  if((fcb = new ExternalAlertCheckPro()))                       registerCallback(fcb);
  if((fcb = new InvalidDNSQuery()))                             registerCallback(fcb);
  if((fcb = new LongLivedFlow()))                               registerCallback(fcb);
  if((fcb = new SuspiciousTCPProbing()))                        registerCallback(fcb);
  if((fcb = new SuspiciousTCPSYNProbing()))                     registerCallback(fcb);
  if((fcb = new TCPConnectionRefused()))                        registerCallback(fcb);
  if((fcb = new FlowRiskTLSCertificateExpired()))               registerCallback(fcb);
  if((fcb = new FlowRiskTLSCertificateMismatch()))              registerCallback(fcb);
  if((fcb = new FlowRiskTLSOldProtocolVersion()))               registerCallback(fcb);
  if((fcb = new FlowRiskTLSUnsafeCiphers()))                    registerCallback(fcb);
  if((fcb = new FlowRiskTLSCertificateSelfSigned()))            registerCallback(fcb);
  if((fcb = new TLSMaliciousSignature()))                       registerCallback(fcb);
#ifdef HAVE_NEDGE
  if((fcb = new NedgeBlockedFlow()))                            registerCallback(fcb);
#endif
#endif

#if 0
  if(!(_has_protocol_detected || _has_periodic_update || _has_flow_end)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Flow callback %s does not define any callback: ignored", getName());
    throw "Invalid plugin definition";
  }
#endif

  // printCallbacks();
}

/* **************************************************** */

void FlowCallbacksLoader::loadConfiguration() {
  json_object *json = NULL, *json_config, *json_config_flow;
  struct json_object_iterator it;
  struct json_object_iterator itEnd;
  enum json_tokener_error jerr = json_tokener_success;
  char *value = NULL;
  u_int actual_len = ntop->getRedis()->len(CALLBACKS_CONFIG);

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

  if(!json_object_object_get_ex(json_config, "flow", &json_config_flow)) {
    /* 'flow' section inside 'config' JSON */
    ntop->getTrace()->traceEvent(TRACE_ERROR, "'flow' not found in 'config' JSON");
    goto out;
  }

  /*
    Iterate over all script configurations
  */
  it = json_object_iter_begin(json_config_flow);
  itEnd = json_object_iter_end(json_config_flow);

  while(!json_object_iter_equal(&it, &itEnd)) {
    const char *callback_key   = json_object_iter_peek_name(&it);
    json_object *callback_config = json_object_iter_peek_value(&it);
    json_object *json_script_conf, *json_hook_all;

    if(json_object_object_get_ex(callback_config, "all", &json_hook_all)) {
      json_object *json_enabled;
      bool enabled;

      if(cb_all.find(callback_key) != cb_all.end()) {
	FlowCallback *cb = cb_all[callback_key];

	if(json_object_object_get_ex(json_hook_all, "enabled", &json_enabled))
	  enabled = json_object_get_boolean(json_enabled);
	else
	  enabled = false;

	if(enabled && cb->isCallbackCompatibleWithEdition()) {
	  /* Script enabled */
	  if(json_object_object_get_ex(json_hook_all, "script_conf", &json_script_conf)) {
	    if(cb_all.find(callback_key) != cb_all.end()) {
	      FlowCallback *cb = cb_all[callback_key];

	      if(cb->loadConfiguration(json_script_conf)) {
		ntop->getTrace()->traceEvent(TRACE_INFO, "Successfully enabled callback %s", callback_key);
	      } else {
		ntop->getTrace()->traceEvent(TRACE_WARNING, "Error while loading callback %s configuration",
					     callback_key);
	      }

	      cb->enable();
	      cb->scriptEnable(); 
	    }
	  }
	} else {
	  /* Script disabled */
	  cb->scriptDisable(); 
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

void FlowCallbacksLoader::printCallbacks() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Available Callbacks:");

  for(std::map<std::string, FlowCallback*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "\t%s", it->first.c_str());
}

/* **************************************************** */

std::list<FlowCallback*>* FlowCallbacksLoader::getCallbacks(NetworkInterface *iface, FlowCallbacks callback) {
  std::list<FlowCallback*> *l = new std::list<FlowCallback*>;

  for(std::map<std::string, FlowCallback*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it) {
    FlowCallback *cb = it->second;

    if(cb->isEnabled())
      cb->addCallback(l, iface, callback);
  }

  return(l);
}

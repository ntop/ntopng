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
#include "flow_checks_includes.h"

/* **************************************************** */

FlowChecksLoader::FlowChecksLoader() : ChecksLoader() {
  /*
    Assuments all risks as unhanlded. Bits corresponding to risks handled by checks will be set to
    zero during checks registration.
   */
  NDPI_BITMASK_SET_ALL(unhandled_ndpi_risks);
  NDPI_CLR_BIT(unhandled_ndpi_risks, NDPI_NO_RISK);
}

/* **************************************************** */

FlowChecksLoader::~FlowChecksLoader() {
  for(std::map<std::string, FlowCheck*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it)
    delete it->second;
}

/* **************************************************** */

void FlowChecksLoader::registerCheck(FlowCheck *cb) {
  if(cb_all.find(cb->getName()) != cb_all.end()) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Ignoring duplicate flow check %s", cb->getName().c_str());
    delete cb;
  } else
    cb_all[cb->getName()] = cb;

  /*
    If this is a check that handles an nDPI flow risk, the corresponding risk is cleared in the
    unhandled risks bitmap
   */
  FlowRisk *fr = dynamic_cast<FlowRisk*>(cb);
  if(fr) NDPI_CLR_BIT(unhandled_ndpi_risks, fr->handledRisk());
}
/* **************************************************** */

void FlowChecksLoader::registerChecks() {
  /* TODO: implement dynamic loading */
  FlowCheck *fcb;

  if((fcb = new BlacklistedFlow()))                             registerCheck(fcb);
  if((fcb = new BlacklistedCountry()))                          registerCheck(fcb);
  if((fcb = new DeviceProtocolNotAllowed()))                    registerCheck(fcb);
#ifndef NTOPNG_PRO
  if((fcb = new ExternalAlertCheck()))                          registerCheck(fcb);
#endif
  if((fcb = new FlowRiskBinaryApplicationTransfer()))           registerCheck(fcb);
  if((fcb = new FlowRiskDNSSuspiciousTraffic()))                registerCheck(fcb);
  if((fcb = new FlowRiskHTTPNumericIPHost()))                   registerCheck(fcb);
  if((fcb = new FlowRiskHTTPSuspiciousHeader()))                registerCheck(fcb);
  if((fcb = new FlowRiskHTTPSuspiciousUserAgent()))             registerCheck(fcb);
  if((fcb = new FlowRiskHTTPSuspiciousURL()))                   registerCheck(fcb);
  if((fcb = new FlowRiskKnownProtocolOnNonStandardPort()))      registerCheck(fcb);
  if((fcb = new FlowRiskMalformedPacket()))                     registerCheck(fcb);
  if((fcb = new FlowRiskSMBInsecureVersion()))                  registerCheck(fcb);
  if((fcb = new FlowRiskSSHObsolete()))                         registerCheck(fcb);
  if((fcb = new FlowRiskSuspiciousDGADomain()))                 registerCheck(fcb);
  if((fcb = new FlowRiskTLSMissingSNI()))                       registerCheck(fcb);
  if((fcb = new FlowRiskTLSNotCarryingHTTPS()))                 registerCheck(fcb);
  if((fcb = new FlowRiskTLSSuspiciousESNIUsage()))              registerCheck(fcb);
  if((fcb = new FlowRiskUnsafeProtocol()))                      registerCheck(fcb);
  if((fcb = new FlowRiskURLPossibleXSS()))                      registerCheck(fcb);
  if((fcb = new FlowRiskURLPossibleRCEInjection()))             registerCheck(fcb);
  if((fcb = new FlowRiskURLPossibleSQLInjection()))             registerCheck(fcb);
  if((fcb = new IECUnexpectedTypeId()))                         registerCheck(fcb);
  if((fcb = new IECInvalidTransition()))                        registerCheck(fcb);
  if((fcb = new LowGoodputFlow()))                              registerCheck(fcb);
  if((fcb = new NotPurged()))                                   registerCheck(fcb);  
  if((fcb = new RemoteAccess()))                                registerCheck(fcb);
  if((fcb = new RemoteToLocalInsecureProto()))                  registerCheck(fcb);
  if((fcb = new RemoteToRemote()))                              registerCheck(fcb);
  if((fcb = new TCPZeroWindow()))                               registerCheck(fcb);
  if((fcb = new TCPNoDataExchanged()))                          registerCheck(fcb);
  if((fcb = new UDPUnidirectional()))                           registerCheck(fcb);
  if((fcb = new UnexpectedDNSServer()))                         registerCheck(fcb);
  if((fcb = new UnexpectedDHCPServer()))                        registerCheck(fcb);
  if((fcb = new UnexpectedNTPServer()))                         registerCheck(fcb);
  if((fcb = new UnexpectedSMTPServer()))                        registerCheck(fcb);
  if((fcb = new WebMining()))                                   registerCheck(fcb);

#ifdef NTOPNG_PRO
  if((fcb = new DataExfiltration()))                            registerCheck(fcb);
  if((fcb = new DNSDataExfiltration()))                         registerCheck(fcb);
  if((fcb = new ElephantFlow()))                                registerCheck(fcb);
  if((fcb = new ExternalAlertCheckPro()))                       registerCheck(fcb);
  if((fcb = new InvalidDNSQuery()))                             registerCheck(fcb);
  if((fcb = new LateralMovement()))                             registerCheck(fcb);
  if((fcb = new PeriodicityChanged()))                          registerCheck(fcb);
  if((fcb = new LongLivedFlow()))                               registerCheck(fcb);
  if((fcb = new TCPConnectionRefused()))                        registerCheck(fcb);
  if((fcb = new FlowRiskTLSCertificateExpired()))               registerCheck(fcb);
  if((fcb = new FlowRiskTLSCertificateMismatch()))              registerCheck(fcb);
  if((fcb = new FlowRiskTLSOldProtocolVersion()))               registerCheck(fcb);
  if((fcb = new FlowRiskTLSUnsafeCiphers()))                    registerCheck(fcb);
  if((fcb = new FlowRiskTLSCertificateSelfSigned()))            registerCheck(fcb);
  if((fcb = new TLSMaliciousSignature()))                       registerCheck(fcb);
#ifdef HAVE_NEDGE
  if((fcb = new NedgeBlockedFlow()))                            registerCheck(fcb);
#endif
#endif

#if 0
  if(!(_has_protocol_detected || _has_periodic_update || _has_flow_end)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Flow check %s does not define any check: ignored", getName());
    throw "Invalid plugin definition";
  }
#endif

  // printChecks();
}

/* **************************************************** */

void FlowChecksLoader::loadConfiguration() {
  json_object *json = NULL, *json_config, *json_config_flow;
  struct json_object_iterator it;
  struct json_object_iterator itEnd;
  enum json_tokener_error jerr = json_tokener_success;
  char *value = NULL;
  u_int actual_len = ntop->getRedis()->len(CHECKS_CONFIG);

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
    const char *check_key   = json_object_iter_peek_name(&it);
    json_object *check_config = json_object_iter_peek_value(&it);
    json_object *json_script_conf, *json_hook_all;

    if(json_object_object_get_ex(check_config, "all", &json_hook_all)) {
      json_object *json_enabled;
      bool enabled;

      if(cb_all.find(check_key) != cb_all.end()) {
	FlowCheck *cb = cb_all[check_key];

	if(!cb->isCheckCompatibleWithEdition()) {
	  ntop->getTrace()->traceEvent(TRACE_INFO, "Check not compatible with current edition [check: %s]", check_key);
	  goto next_object;
	}

	if(json_object_object_get_ex(json_hook_all, "enabled", &json_enabled))
	  enabled = json_object_get_boolean(json_enabled);
	else
	  enabled = false;

	if(!enabled) {
	  ntop->getTrace()->traceEvent(TRACE_INFO, "Skipping check not enabled [check: %s]", check_key);
	  goto next_object;
	}

	/* Script enabled */
	if(json_object_object_get_ex(json_hook_all, "script_conf", &json_script_conf)) {
	  if(cb->loadConfiguration(json_script_conf)) {
	    ntop->getTrace()->traceEvent(TRACE_INFO, "Successfully enabled check %s", check_key);
	  } else {
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "Error while loading check %s configuration",
					 check_key);
	  }

	  cb->enable();
	  cb->scriptEnable(); 
	} else {
	  /* Script disabled */
	  cb->scriptDisable(); 
	}
      }	else
	ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to find flow check %s", check_key);
    }

  next_object:
    /* Move to the next element */
    json_object_iter_next(&it);
  } /* while */

 out:
  /* Free the json */
  if(json)  json_object_put(json);
  if(value) free(value);
}

/* **************************************************** */

void FlowChecksLoader::printChecks() {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Available Checks:");

  for(std::map<std::string, FlowCheck*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it)
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "\t%s", it->first.c_str());

  if(unhandled_ndpi_risks) {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Unhandled Risks:");

    for(int i = 0; i < NDPI_MAX_RISK; i++)
      if(NDPI_ISSET_BIT(unhandled_ndpi_risks, (ndpi_risk_enum)i))
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "\t%s [%u]", ndpi_risk2str((ndpi_risk_enum)i), i);
  }
}

/* **************************************************** */

std::list<FlowCheck*>* FlowChecksLoader::getChecks(NetworkInterface *iface, FlowChecks check) {
  std::list<FlowCheck*> *l = new std::list<FlowCheck*>;

  for(std::map<std::string, FlowCheck*>::const_iterator it = cb_all.begin(); it != cb_all.end(); ++it) {
    FlowCheck *cb = it->second;

    if(cb->isEnabled())
      cb->addCheck(l, iface, check);
  }

  return(l);
}

/* **************************************************** */

bool FlowChecksLoader::luaCheckInfo(lua_State* vm, std::string check_name) const {
  std::map<std::string, FlowCheck*>::const_iterator it = cb_all.find(check_name);

  if(it == cb_all.end())
    return false;

  lua_newtable(vm);
  /*
    Following keys are compatible and interoperable with Lua plugins as found under plugins_utils.lua
    inside plugin metadata Lua table
   */
  lua_push_str_table_entry(vm, "edition", Utils::edition2name(it->second->getEdition()));
  lua_push_str_table_entry(vm, "key", it->second->getName().c_str());

  return true;
}

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

FlowAlertsLoader::FlowAlertsLoader() {
  memset(&alert_to_score, 0, sizeof(alert_to_score));

  /* TODO: implement dynamic loading */
  registerAlert(FlowRiskBinaryApplicationTransferAlert::getClassType(), FlowRiskBinaryApplicationTransferAlert::getDefaultScore());
  registerAlert(FlowRiskDNSSuspiciousTrafficAlert::getClassType(), FlowRiskDNSSuspiciousTrafficAlert::getDefaultScore());
  registerAlert(FlowRiskHTTPNumericIPHostAlert::getClassType(), FlowRiskHTTPNumericIPHostAlert::getDefaultScore());
  registerAlert(FlowRiskHTTPSuspiciousHeaderAlert::getClassType(), FlowRiskHTTPSuspiciousHeaderAlert::getDefaultScore());
  registerAlert(FlowRiskHTTPSuspiciousURLAlert::getClassType(), FlowRiskHTTPSuspiciousURLAlert::getDefaultScore());
  registerAlert(FlowRiskHTTPSuspiciousUserAgentAlert::getClassType(), FlowRiskHTTPSuspiciousUserAgentAlert::getDefaultScore());
  registerAlert(FlowRiskKnownProtocolOnNonStandardPortAlert::getClassType(), FlowRiskKnownProtocolOnNonStandardPortAlert::getDefaultScore());
  registerAlert(FlowRiskMalformedPacketAlert::getClassType(), FlowRiskMalformedPacketAlert::getDefaultScore());
  registerAlert(FlowRiskSMBInsecureVersionAlert::getClassType(), FlowRiskSMBInsecureVersionAlert::getDefaultScore());
  registerAlert(FlowRiskSSHObsoleteAlert::getClassType(), FlowRiskSSHObsoleteAlert::getDefaultScore());
  registerAlert(FlowRiskSuspiciousDGADomainAlert::getClassType(), FlowRiskSuspiciousDGADomainAlert::getDefaultScore());
  registerAlert(FlowRiskTLSMissingSNIAlert::getClassType(), FlowRiskTLSMissingSNIAlert::getDefaultScore());
  registerAlert(FlowRiskTLSNotCarryingHTTPSAlert::getClassType(), FlowRiskTLSNotCarryingHTTPSAlert::getDefaultScore());
  registerAlert(FlowRiskTLSSuspiciousESNIUsageAlert::getClassType(), FlowRiskTLSSuspiciousESNIUsageAlert::getDefaultScore());
  registerAlert(FlowRiskURLPossibleRCEInjectionAlert::getClassType(), FlowRiskURLPossibleRCEInjectionAlert::getDefaultScore());
  registerAlert(FlowRiskURLPossibleSQLInjectionAlert::getClassType(), FlowRiskURLPossibleSQLInjectionAlert::getDefaultScore());
  registerAlert(FlowRiskURLPossibleXSSAlert::getClassType(), FlowRiskURLPossibleXSSAlert::getDefaultScore());
  registerAlert(FlowRiskUnsafeProtocolAlert::getClassType(), FlowRiskUnsafeProtocolAlert::getDefaultScore());

  /* PRO */
  registerAlert(FlowRiskTLSCertificateExpiredAlert::getClassType(), FlowRiskTLSCertificateExpiredAlert::getDefaultScore());
  registerAlert(FlowRiskTLSCertificateMismatchAlert::getClassType(), FlowRiskTLSCertificateMismatchAlert::getDefaultScore());
  registerAlert(FlowRiskTLSCertificateSelfSignedAlert::getClassType(), FlowRiskTLSCertificateSelfSignedAlert::getDefaultScore());
  registerAlert(FlowRiskTLSOldProtocolVersionAlert::getClassType(), FlowRiskTLSOldProtocolVersionAlert::getDefaultScore());
  registerAlert(FlowRiskTLSUnsafeCiphersAlert::getClassType(), FlowRiskTLSUnsafeCiphersAlert::getDefaultScore());

  registerAlert(BlacklistedCountryAlert::getClassType(), BlacklistedCountryAlert::getDefaultScore());
}
/* **************************************************** */

FlowAlertsLoader::~FlowAlertsLoader() {
}

/* **************************************************** */

void FlowAlertsLoader::registerAlert(FlowAlertType alert_type, u_int8_t alert_score) {
  if(alert_type.id >= MAX_DEFINED_FLOW_ALERT_TYPE)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Ignoring alert with unknown id %u", alert_type.id);

  alert_to_score[alert_type.id] = alert_score;
}

/* **************************************************** */

u_int8_t FlowAlertsLoader::getAlertScore(FlowAlertTypeEnum alert_id) const {
  if(alert_id < MAX_DEFINED_FLOW_ALERT_TYPE)
    return alert_to_score[alert_id];

  return 0;
}

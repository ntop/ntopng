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

FlowAlertsLoader::FlowAlertsLoader() {
  memset(&alert_to_score, 0, sizeof(alert_to_score));

  /* TODO: implement dynamic loading */

  /* Risks - Community */
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

  /* Risks - PRO */
  registerAlert(FlowRiskTLSCertificateExpiredAlert::getClassType(), FlowRiskTLSCertificateExpiredAlert::getDefaultScore());
  registerAlert(FlowRiskTLSCertificateMismatchAlert::getClassType(), FlowRiskTLSCertificateMismatchAlert::getDefaultScore());
  registerAlert(FlowRiskTLSCertificateSelfSignedAlert::getClassType(), FlowRiskTLSCertificateSelfSignedAlert::getDefaultScore());
  registerAlert(FlowRiskTLSOldProtocolVersionAlert::getClassType(), FlowRiskTLSOldProtocolVersionAlert::getDefaultScore());
  registerAlert(FlowRiskTLSUnsafeCiphersAlert::getClassType(), FlowRiskTLSUnsafeCiphersAlert::getDefaultScore());

  /* Other */
  registerAlert(BlacklistedCountryAlert::getClassType(),         BlacklistedCountryAlert::getDefaultScore());
  registerAlert(BlacklistedFlowAlert::getClassType(),            BlacklistedFlowAlert::getDefaultScore());
  registerAlert(DNSDataExfiltrationAlert::getClassType(),        DNSDataExfiltrationAlert::getDefaultScore());
  registerAlert(DataExfiltrationAlert::getClassType(),           DataExfiltrationAlert::getDefaultScore());
  registerAlert(DeviceProtocolNotAllowedAlert::getClassType(),   DeviceProtocolNotAllowedAlert::getDefaultScore());
  registerAlert(ElephantFlowAlert::getClassType(),               ElephantFlowAlert::getDefaultScore());
  registerAlert(ExternalAlertCheckAlert::getClassType(),         ExternalAlertCheckAlert::getDefaultScore());
  registerAlert(IECInvalidTransitionAlert::getClassType(),       IECInvalidTransitionAlert::getDefaultScore());
  registerAlert(IECUnexpectedTypeIdAlert::getClassType(),        IECUnexpectedTypeIdAlert::getDefaultScore());
  registerAlert(InvalidDNSQueryAlert::getClassType(),            InvalidDNSQueryAlert::getDefaultScore());
  registerAlert(LateralMovementAlert::getClassType(),            LateralMovementAlert::getDefaultScore());
  registerAlert(PeriodicityChangedAlert::getClassType(),         PeriodicityChangedAlert::getDefaultScore());
  registerAlert(LongLivedFlowAlert::getClassType(),              LongLivedFlowAlert::getDefaultScore());
  registerAlert(LowGoodputFlowAlert::getClassType(),             LowGoodputFlowAlert::getDefaultScore());
  registerAlert(NedgeBlockedFlowAlert::getClassType(),           NedgeBlockedFlowAlert::getDefaultScore());
  registerAlert(NotPurgedAlert::getClassType(),                  NotPurgedAlert::getDefaultScore());
  registerAlert(RemoteAccessAlert::getClassType(),               RemoteAccessAlert::getDefaultScore());
  registerAlert(RemoteToLocalInsecureProtoAlert::getClassType(), RemoteToLocalInsecureProtoAlert::getDefaultScore());
  registerAlert(RemoteToRemoteAlert::getClassType(),             RemoteToRemoteAlert::getDefaultScore());
  registerAlert(TCPConnectionRefusedAlert::getClassType(),       TCPConnectionRefusedAlert::getDefaultScore());
  registerAlert(TCPNoDataExchangedAlert::getClassType(),         TCPNoDataExchangedAlert::getDefaultScore());
  registerAlert(TCPZeroWindowAlert::getClassType(),              TCPZeroWindowAlert::getDefaultScore());
  registerAlert(TLSMaliciousSignatureAlert::getClassType(),      TLSMaliciousSignatureAlert::getDefaultScore());
  registerAlert(UDPUnidirectionalAlert::getClassType(),          UDPUnidirectionalAlert::getDefaultScore());
  registerAlert(UnexpectedDHCPServerAlert::getClassType(),       UnexpectedDHCPServerAlert::getDefaultScore());
  registerAlert(UnexpectedDNSServerAlert::getClassType(),        UnexpectedDNSServerAlert::getDefaultScore());
  registerAlert(UnexpectedNTPServerAlert::getClassType(),        UnexpectedNTPServerAlert::getDefaultScore());
  registerAlert(UnexpectedSMTPServerAlert::getClassType(),       UnexpectedSMTPServerAlert::getDefaultScore());
  registerAlert(WebMiningAlert::getClassType(),                  WebMiningAlert::getDefaultScore());
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

/* **************************************************** */

void FlowAlertsLoader::printRegisteredAlerts() const {
  for(int i = 0; i < MAX_DEFINED_FLOW_ALERT_TYPE; i++) {
    if(alert_to_score[i])
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Alert [%u][score: %u]", i, alert_to_score[i]);
  }
}

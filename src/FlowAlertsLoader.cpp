/*
 *
 * (C) 2013-22 - ntop.org
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

  /* Set all alerts to no risk, then initialize risk-based alerts */
  for(int i = 0; i < MAX_DEFINED_FLOW_ALERT_TYPE; i++)
    alert_to_risk[i] = NDPI_NO_RISK;

  /* TODO: implement dynamic loading */

  /* Register all flow-risk based alerts */
  for(u_int risk_id = 1; risk_id < NDPI_MAX_RISK; risk_id++) {
    ndpi_risk_enum risk = (ndpi_risk_enum)risk_id;
    FlowAlertType fat = FlowRiskAlerts::getFlowRiskAlertType(risk);

    if(fat.id != flow_alert_normal)
      registerAlert(fat, FlowRiskAlerts::getFlowRiskScore(risk)),
	registerRisk(fat, risk);
  }

  /* Other */
  registerAlert(BlacklistedCountryAlert::getClassType(),         BlacklistedCountryAlert::getDefaultScore());
  registerAlert(BlacklistedFlowAlert::getClassType(),            BlacklistedFlowAlert::getDefaultScore());
  registerAlert(BroadcastNonUDPTrafficAlert::getClassType(),     BroadcastNonUDPTrafficAlert::getDefaultScore());
  registerAlert(DNSDataExfiltrationAlert::getClassType(),        DNSDataExfiltrationAlert::getDefaultScore());
  registerAlert(DataExfiltrationAlert::getClassType(),           DataExfiltrationAlert::getDefaultScore());
  registerAlert(DeviceProtocolNotAllowedAlert::getClassType(),   DeviceProtocolNotAllowedAlert::getDefaultScore());
  registerAlert(ElephantFlowAlert::getClassType(),               ElephantFlowAlert::getDefaultScore());
  registerAlert(ExternalAlertCheckAlert::getClassType(),         ExternalAlertCheckAlert::getDefaultScore());
  registerAlert(IECInvalidTransitionAlert::getClassType(),       IECInvalidTransitionAlert::getDefaultScore());
  registerAlert(IECInvalidCommandTransitionAlert::getClassType(),IECInvalidCommandTransitionAlert::getDefaultScore());
  registerAlert(IECUnexpectedTypeIdAlert::getClassType(),        IECUnexpectedTypeIdAlert::getDefaultScore());
  registerAlert(InvalidDNSQueryAlert::getClassType(),            InvalidDNSQueryAlert::getDefaultScore());
#if defined(NTOPNG_PRO) && !defined(HAVE_NEDGE)
  registerAlert(LateralMovementAlert::getClassType(),            LateralMovementAlert::getDefaultScore());
  registerAlert(PeriodicityChangedAlert::getClassType(),         PeriodicityChangedAlert::getDefaultScore());
#endif
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
  else
    alert_to_score[alert_type.id] = alert_score;
}

/* **************************************************** */

void FlowAlertsLoader::registerRisk(FlowAlertType alert_type, ndpi_risk_enum risk) {
  if(alert_type.id >= MAX_DEFINED_FLOW_ALERT_TYPE)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Ignoring alert with unknown id %u", alert_type.id);

  alert_to_risk[alert_type.id] = risk;
}

/* **************************************************** */

u_int8_t FlowAlertsLoader::getAlertScore(FlowAlertTypeEnum alert_id) const {
  if(alert_id < MAX_DEFINED_FLOW_ALERT_TYPE)
    return alert_to_score[alert_id];

  return 0;
}

/* **************************************************** */

ndpi_risk_enum FlowAlertsLoader::getAlertRisk(FlowAlertTypeEnum alert_id) const {
  if(alert_id < MAX_DEFINED_FLOW_ALERT_TYPE)
    return alert_to_risk[alert_id];

  return NDPI_NO_RISK;
}

/* **************************************************** */

void FlowAlertsLoader::printRegisteredAlerts() const {
  for(int i = 0; i < MAX_DEFINED_FLOW_ALERT_TYPE; i++) {
    if(alert_to_score[i])
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Alert [%u][score: %u]", i, alert_to_score[i]);
  }
}

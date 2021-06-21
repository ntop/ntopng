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

#ifndef _FLOW_ALERTS_INCLUDES_H_
#define _FLOW_ALERTS_INCLUDES_H_

#include "flow_alerts/FlowRiskAlert.h"
#include "flow_alerts/BlacklistedFlowAlert.h"
#include "flow_alerts/BlacklistedCountryAlert.h"
#include "flow_alerts/ExternalAlertCheckAlert.h"
#include "flow_alerts/LowGoodputFlowAlert.h"
#include "flow_alerts/NotPurgedAlert.h"
#include "flow_alerts/RemoteAccessAlert.h"
#include "flow_alerts/RemoteToLocalInsecureProtoAlert.h"
#include "flow_alerts/RemoteToRemoteAlert.h"
#include "flow_alerts/TCPNoDataExchangedAlert.h"
#include "flow_alerts/TCPZeroWindowAlert.h"
#include "flow_alerts/UDPUnidirectionalAlert.h"
#include "flow_alerts/UnexpectedServerAlert.h"
#include "flow_alerts/UnexpectedDHCPServerAlert.h"
#include "flow_alerts/UnexpectedDNSServerAlert.h"
#include "flow_alerts/UnexpectedNTPServerAlert.h"
#include "flow_alerts/UnexpectedSMTPServerAlert.h"
#include "flow_alerts/UnexpectedServerAlert.h"
#include "flow_alerts/WebMiningAlert.h"
#include "flow_alerts/DeviceProtocolNotAllowedAlert.h"
#include "flow_alerts/FlowRiskBinaryApplicationTransferAlert.h"
#include "flow_alerts/FlowRiskDNSSuspiciousTrafficAlert.h"
#include "flow_alerts/FlowRiskHTTPNumericIPHostAlert.h"
#include "flow_alerts/FlowRiskHTTPSuspiciousHeaderAlert.h"
#include "flow_alerts/FlowRiskHTTPSuspiciousURLAlert.h"
#include "flow_alerts/FlowRiskHTTPSuspiciousUserAgentAlert.h"
#include "flow_alerts/FlowRiskKnownProtocolOnNonStandardPortAlert.h"
#include "flow_alerts/FlowRiskMalformedPacketAlert.h"
#include "flow_alerts/FlowRiskSMBInsecureVersionAlert.h"
#include "flow_alerts/FlowRiskSSHObsoleteAlert.h"
#include "flow_alerts/FlowRiskSuspiciousDGADomainAlert.h"
#include "flow_alerts/FlowRiskTLSAlert.h"
#include "flow_alerts/FlowRiskTLSMissingSNIAlert.h"
#include "flow_alerts/FlowRiskTLSNotCarryingHTTPSAlert.h"
#include "flow_alerts/FlowRiskTLSSuspiciousESNIUsageAlert.h"
#include "flow_alerts/FlowRiskURLPossibleRCEInjectionAlert.h"
#include "flow_alerts/FlowRiskURLPossibleSQLInjectionAlert.h"
#include "flow_alerts/FlowRiskURLPossibleXSSAlert.h"
#include "flow_alerts/FlowRiskUnsafeProtocolAlert.h"
#include "flow_alerts/IECInvalidTransitionAlert.h"
#include "flow_alerts/IECUnexpectedTypeIdAlert.h"

/* Pro Alerts - do NOT use #ifdef as alerts must always be available */
#include "flow_alerts/FlowRiskTLSUnsafeCiphersAlert.h"
#include "flow_alerts/FlowRiskTLSCertificateExpiredAlert.h"
#include "flow_alerts/FlowRiskTLSCertificateMismatchAlert.h"
#include "flow_alerts/FlowRiskTLSOldProtocolVersionAlert.h"
#include "flow_alerts/TLSMaliciousSignatureAlert.h"
#include "flow_alerts/FlowRiskTLSCertificateSelfSignedAlert.h"
#include "flow_alerts/DataExfiltrationAlert.h"
#include "flow_alerts/ElephantFlowAlert.h"
#include "flow_alerts/LateralMovementAlert.h"
#include "flow_alerts/PeriodicityChangedAlert.h"
#include "flow_alerts/LongLivedFlowAlert.h"
#include "flow_alerts/DNSDataExfiltrationAlert.h"
#include "flow_alerts/TCPConnectionRefusedAlert.h"
#include "flow_alerts/NedgeBlockedFlowAlert.h"
#include "flow_alerts/InvalidDNSQueryAlert.h"

#endif /* _FLOW_ALERTS_INCLUDES_H_ */

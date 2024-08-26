/*
 *
 * (C) 2013-24 - ntop.org
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

#ifndef _FLOW_CHECKS_INCLUDES_H_
#define _FLOW_CHECKS_INCLUDES_H_

#include "flow_alerts_includes.h"

#include "flow_checks/BlacklistedFlow.h"
#include "flow_checks/BlacklistedCountry.h"
#include "flow_checks/BroadcastNonUDPTraffic.h"
#include "flow_checks/CustomFlowLuaScript.h"
#include "flow_checks/DeviceProtocolNotAllowed.h"
#include "flow_checks/ExternalAlertCheck.h"
#include "flow_checks/FlowRisk.h"
#include "flow_checks/FlowRiskGeneric.h"
#include "flow_checks/FlowRiskBinaryApplicationTransfer.h"
#include "flow_checks/FlowRiskDesktopOrFileSharingSession.h"
#include "flow_checks/FlowRiskDNSSuspiciousTraffic.h"
#include "flow_checks/FlowRiskNumericIPHost.h"
#include "flow_checks/FlowRiskHTTPObsoleteServer.h"
#include "flow_checks/FlowRiskHTTPSuspiciousHeader.h"
#include "flow_checks/FlowRiskHTTPSuspiciousUserAgent.h"
#include "flow_checks/FlowRiskHTTPSuspiciousURL.h"
#include "flow_checks/FlowRiskKnownProtocolOnNonStandardPort.h"
#include "flow_checks/FlowRiskMalformedPacket.h"
#include "flow_checks/FlowRiskMaliciousFingerprint.h"
#include "flow_checks/FlowRiskMaliciousSHA1Certificate.h"
#include "flow_checks/FlowRiskMalwareHostContacted.h"
#include "flow_checks/FlowRiskPeriodicFlow.h"
#include "flow_checks/FlowRiskSMBInsecureVersion.h"
#include "flow_checks/FlowRiskSSHObsoleteServer.h"
#include "flow_checks/FlowRiskSSHObsoleteClient.h"
#include "flow_checks/FlowRiskSuspiciousDGADomain.h"
#include "flow_checks/FlowRiskTLS.h"
#include "flow_checks/FlowRiskTLSMissingSNI.h"
#include "flow_checks/FlowRiskRiskyASN.h"
#include "flow_checks/FlowRiskRiskyDomain.h"
#include "flow_checks/FlowRiskTLSNotCarryingHTTPS.h"
#include "flow_checks/FlowRiskTLSSuspiciousESNIUsage.h"
#include "flow_checks/FlowRiskSuspiciousEntropy.h"
#include "flow_checks/FlowRiskClearTextCredentials.h"
#include "flow_checks/FlowRiskDNSLargePacket.h"
#include "flow_checks/FlowRiskDNSFragmented.h"
#include "flow_checks/FlowRiskUnsafeProtocol.h"
#include "flow_checks/FlowRiskURLPossibleXSS.h"
#include "flow_checks/FlowRiskURLPossibleRCEInjection.h"
#include "flow_checks/FlowRiskURLPossibleSQLInjection.h"
#include "flow_checks/FlowRiskUnidirectionalTraffic.h"
#include "flow_checks/IECUnexpectedTypeId.h"
#include "flow_checks/IECInvalidTransition.h"
#include "flow_checks/IECInvalidCommandTransition.h"
#include "flow_checks/LowGoodputFlow.h"
#include "flow_checks/NotPurged.h"
#include "flow_checks/RareDestination.h"
#include "flow_checks/RemoteAccess.h"
#include "flow_checks/RemoteToLocalInsecureProto.h"
#include "flow_checks/RemoteToRemote.h"
#include "flow_checks/TCPNoDataExchanged.h"
#include "flow_checks/TCPZeroWindow.h"
#include "flow_checks/TCPPacketsIssues.h"
#include "flow_checks/UnexpectedServer.h"
#include "flow_checks/UnexpectedDNSServer.h"
#include "flow_checks/UnexpectedDHCPServer.h"
#include "flow_checks/UnexpectedNTPServer.h"
#include "flow_checks/UnexpectedSMTPServer.h"
#include "flow_checks/WebMining.h"
#include "flow_checks/VLANBidirectionalTraffic.h"
#include "flow_checks/BlacklistedClientContact.h"
#include "flow_checks/BlacklistedServerContact.h"
#include "flow_checks/TCPFlowReset.h"

#ifdef NTOPNG_PRO
#include "flow_checks/DataExfiltration.h"
#include "flow_checks/DNSDataExfiltration.h"
#include "flow_checks/ElephantFlow.h"
#include "flow_checks/ExternalAlertCheckPro.h"
#include "flow_checks/InvalidDNSQuery.h"
#include "flow_checks/LateralMovement.h"
#include "flow_checks/PeriodicityChanged.h"
#include "flow_checks/LongLivedFlow.h"
#include "flow_checks/ModbusUnexpectedFunctionCode.h"
#include "flow_checks/ModbusTooManyExceptions.h"
#include "flow_checks/ModbusInvalidTransition.h"
#include "flow_checks/TCPConnectionFailed.h"
#include "flow_checks/TCPConnectionRefused.h"
#include "flow_checks/FlowRiskTLSCertValidityTooLong.h"
#include "flow_checks/FlowRiskTLSCertificateExpired.h"
#include "flow_checks/FlowRiskTLSCertificateSelfSigned.h"
#include "flow_checks/FlowRiskTLSCertificateMismatch.h"
#include "flow_checks/FlowRiskTLSFatal.h"
#include "flow_checks/FlowRiskTLSOldProtocolVersion.h"
#include "flow_checks/FlowRiskTLSSuspiciousExtension.h"
#include "flow_checks/FlowRiskTLSUncommonALPN.h"
#include "flow_checks/FlowRiskTLSUnsafeCiphers.h"
#include "flow_checks/NedgeBlockedFlow.h"
#endif

#endif /* _FLOW_CHECKS_INCLUDES_H_ */

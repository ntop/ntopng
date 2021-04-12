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

#ifndef _FLOW_CALLBACKS_INCLUDES_H_
#define _FLOW_CALLBACKS_INCLUDES_H_

#include "flow_alerts_includes.h"

#include "flow_callbacks/BlacklistedFlow.h"
#include "flow_callbacks/BlacklistedCountry.h"
#include "flow_callbacks/DeviceProtocolNotAllowed.h"
#include "flow_callbacks/ExternalAlertCheck.h"
#include "flow_callbacks/FlowRisk.h"
#include "flow_callbacks/FlowRiskBinaryApplicationTransfer.h"
#include "flow_callbacks/FlowRiskDNSSuspiciousTraffic.h"
#include "flow_callbacks/FlowRiskHTTPNumericIPHost.h"
#include "flow_callbacks/FlowRiskHTTPSuspiciousHeader.h"
#include "flow_callbacks/FlowRiskHTTPSuspiciousUserAgent.h"
#include "flow_callbacks/FlowRiskHTTPSuspiciousURL.h"
#include "flow_callbacks/FlowRiskKnownProtocolOnNonStandardPort.h"
#include "flow_callbacks/FlowRiskMalformedPacket.h"
#include "flow_callbacks/FlowRiskSMBInsecureVersion.h"
#include "flow_callbacks/FlowRiskSSHObsolete.h"
#include "flow_callbacks/FlowRiskSuspiciousDGADomain.h"
#include "flow_callbacks/FlowRiskTLS.h"
#include "flow_callbacks/FlowRiskTLSMissingSNI.h"
#include "flow_callbacks/FlowRiskTLSNotCarryingHTTPS.h"
#include "flow_callbacks/FlowRiskTLSSuspiciousESNIUsage.h"
#include "flow_callbacks/FlowRiskUnsafeProtocol.h"
#include "flow_callbacks/FlowRiskURLPossibleXSS.h"
#include "flow_callbacks/FlowRiskURLPossibleRCEInjection.h"
#include "flow_callbacks/FlowRiskURLPossibleSQLInjection.h"
#include "flow_callbacks/IECUnexpectedTypeId.h"
#include "flow_callbacks/IECInvalidTransition.h"
#include "flow_callbacks/LowGoodputFlow.h"
#include "flow_callbacks/NotPurged.h"
#include "flow_callbacks/RemoteAccess.h"
#include "flow_callbacks/RemoteToLocalInsecureProto.h"
#include "flow_callbacks/RemoteToRemote.h"
#include "flow_callbacks/TCPIssues.h"
#include "flow_callbacks/TCPNoDataExchanged.h"
#include "flow_callbacks/TCPZeroWindow.h"
#include "flow_callbacks/UDPUnidirectional.h"
#include "flow_callbacks/UnexpectedServer.h"
#include "flow_callbacks/UnexpectedDNSServer.h"
#include "flow_callbacks/UnexpectedDHCPServer.h"
#include "flow_callbacks/UnexpectedNTPServer.h"
#include "flow_callbacks/UnexpectedSMTPServer.h"
#include "flow_callbacks/WebMining.h"

#ifdef NTOPNG_PRO
#include "flow_callbacks/DataExfiltration.h"
#include "flow_callbacks/DNSDataExfiltration.h"
#include "flow_callbacks/ElephantFlow.h"
#include "flow_callbacks/ExternalAlertCheckPro.h"
#include "flow_callbacks/InvalidDNSQuery.h"
#include "flow_callbacks/LongLivedFlow.h"
#include "flow_callbacks/PotentiallyDangerous.h"
#include "flow_callbacks/SuspiciousTCPProbing.h"
#include "flow_callbacks/SuspiciousTCPSYNProbing.h"
#include "flow_callbacks/TCPConnectionRefused.h"
#include "flow_callbacks/FlowRiskTLSCertificateExpired.h"
#include "flow_callbacks/FlowRiskTLSCertificateSelfSigned.h"
#include "flow_callbacks/FlowRiskTLSCertificateMismatch.h"
#include "flow_callbacks/FlowRiskTLSOldProtocolVersion.h"
#include "flow_callbacks/FlowRiskTLSUnsafeCiphers.h"
#include "flow_callbacks/TLSMaliciousSignature.h"
#include "flow_callbacks/NedgeBlockedFlow.h"
#endif

#endif /* _FLOW_CALLBACKS_INCLUDES_H_ */

/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _HOST_CHECKS_INCLUDES_H_
#define _HOST_CHECKS_INCLUDES_H_

#include "host_alerts_includes.h"
#include "host_checks_includes.h"

#include "host_checks/CountriesContacts.h"
#include "host_checks/CustomHostLuaScript.h"

#include "host_checks/FlowHits.h"
#include "host_checks/FlowFlood.h"
#include "host_checks/SYNScan.h"
#include "host_checks/FINScan.h"
#include "host_checks/RSTScan.h"
#include "host_checks/SYNFlood.h"
#include "host_checks/ICMPFlood.h"

#include "host_checks/ServerContacts.h"
#include "host_checks/DNSServerContacts.h"
#include "host_checks/SMTPServerContacts.h"
#include "host_checks/NTPServerContacts.h"

#include "host_checks/P2PTraffic.h"
#include "host_checks/NTPTraffic.h"
#include "host_checks/DNSTraffic.h"

#include "host_checks/DangerousHost.h"
#include "host_checks/RemoteConnection.h"
#include "host_checks/DomainNamesContacts.h"
#include "host_checks/ScanDetection.h"
#include "host_checks/ScoreThreshold.h"

#include "host_checks/PktThreshold.h"

#ifdef NTOPNG_PRO
#include "host_checks/DNSFlood.h"
#include "host_checks/SNMPFlood.h"
#include "host_checks/ScoreAnomaly.h"
#include "host_checks/FlowAnomaly.h"
#include "host_checks/HostMACReassociation.h"
#endif
#endif /* _HOST_CHECKS_INCLUDES_H_ */

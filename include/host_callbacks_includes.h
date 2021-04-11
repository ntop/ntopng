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

#ifndef _HOST_CALLBACKS_INCLUDES_H_
#define _HOST_CALLBACKS_INCLUDES_H_

#include "host_alerts_includes.h"
#include "host_callbacks_includes.h"

#include "host_callbacks/FlowHits.h"
#include "host_callbacks/FlowFlood.h"
#include "host_callbacks/SYNScan.h"
#include "host_callbacks/SYNFlood.h"

#include "host_callbacks/ServerContacts.h"
#include "host_callbacks/DNSServerContacts.h"
#include "host_callbacks/SMTPServerContacts.h"
#include "host_callbacks/NTPServerContacts.h"

#include "host_callbacks/P2PTraffic.h"
#include "host_callbacks/DNSTraffic.h"

#include "host_callbacks/FlowAnomaly.h"

#ifdef NTOPNG_PRO
#include "host_callbacks/RepliesRequestsRatio.h"
#include "host_callbacks/DNSRepliesRequestsRatio.h"
#include "host_callbacks/ScoreHostCallback.h"
#endif

#endif /* _HOST_CALLBACKS_INCLUDES_H_ */

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

#ifndef _HOST_ALERTS_INCLUDES_H_
#define _HOST_ALERTS_INCLUDES_H_

#include "host_alerts/FlowHitsAlert.h"
#include "host_alerts/FlowFloodAlert.h"
#include "host_alerts/SYNScanAlert.h"
#include "host_alerts/SYNFloodAlert.h"
#include "host_alerts/ServerContactsAlert.h"
#include "host_alerts/DNSServerContactsAlert.h"
#include "host_alerts/SMTPServerContactsAlert.h"
#include "host_alerts/NTPServerContactsAlert.h"
#include "host_alerts/P2PTrafficAlert.h"
#include "host_alerts/DNSTrafficAlert.h"

#include "host_alerts/FlowAnomalyAlert.h"
#include "host_alerts/DangerousHostAlert.h"
#include "host_alerts/RemoteConnectionAlert.h"
#include "host_alerts/ScoreAnomalyAlert.h"

/* Pro Alerts - do NOT use #ifdef as alerts must always be available */

#endif /* _HOST_ALERTS_INCLUDES_H_ */

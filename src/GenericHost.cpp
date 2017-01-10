/*
 *
 * (C) 2013-17 - ntop.org
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

/* *************************************** */

GenericHost::GenericHost(NetworkInterface *_iface) : GenericHashEntry(_iface) {
  if(_iface == NULL)
    ntop->getTrace()->traceEvent(TRACE_WARNING, "NULL interface");

  ndpiStats = new nDPIStats();

  systemHost = false, localHost = false, last_activity_update = 0, host_serial = 0;
  last_bytes = 0, last_bytes_thpt = bytes_thpt = 0, bytes_thpt_trend = trend_unknown;
  last_bytes_periodic = 0, bytes_thpt_diff = 0;
  last_packets = 0, last_pkts_thpt = pkts_thpt = 0, pkts_thpt_trend = trend_unknown;
  last_update_time.tv_sec = 0, last_update_time.tv_usec = 0, vlan_id = 0;
  num_alerts_detected = 0, source_id = 0, low_goodput_client_flows = low_goodput_server_flows = 0;
  // readStats(); - Commented as if put here it's too early and the key is not yet set
  goodput_bytes_thpt = last_goodput_bytes_thpt = bytes_goodput_thpt_diff = 0;
  bytes_goodput_thpt_trend = trend_unknown;
}

/* *************************************** */

GenericHost::~GenericHost() {
  if(ndpiStats)
    delete ndpiStats;
}

/* *************************************** */

void GenericHost::readStats() {
  if(localHost || systemHost) {
    char buf[64], *host_key, dump_path[MAX_PATH], daybuf[64];
    time_t when = activityStats.get_wrap_time()-(86400/2) /* sec */;
    
    host_key = get_string_key(buf, sizeof(buf));
    strftime(daybuf, sizeof(daybuf), "%y/%m/%d", localtime(&when));
    snprintf(dump_path, sizeof(dump_path), "%s/%d/activities/%s/%s@%u",
	     ntop->get_working_dir(), iface->get_id(), daybuf, host_key, vlan_id);
    ntop->fixPath(dump_path);

    if(activityStats.readDump(dump_path))
      ntop->getTrace()->traceEvent(TRACE_INFO, "Read activity stats from %s", dump_path);
  }
}

/* *************************************** */

void GenericHost::dumpStats(bool forceDump) {
  if((localHost || systemHost) || forceDump) {
    /* (Daily) Wrap */
    char buf[64], *host_key;
    time_t when = activityStats.get_wrap_time()-(86400/2) /* sec */;

    host_key = get_string_key(buf, sizeof(buf));

    if(strcmp(host_key, "00:00:00:00:00:00")) {
      char dump_path[MAX_PATH], daybuf[64];

      strftime(daybuf, sizeof(daybuf), "%y/%m/%d", localtime(&when));
      snprintf(dump_path, sizeof(dump_path), "%s/%d/activities/%s",
	       ntop->get_working_dir(), iface->get_id(), daybuf);
      ntop->fixPath(dump_path);
      Utils::mkdir_tree(dump_path);

      snprintf(dump_path, sizeof(dump_path), "%s/%d/activities/%s/%s@%u",
	       ntop->get_working_dir(), iface->get_id(), daybuf, host_key, vlan_id);
      ntop->fixPath(dump_path);
      activityStats.writeDump(dump_path);
      ntop->getTrace()->traceEvent(TRACE_INFO, "Dumping %s", dump_path);
    }
  }
}

/* *************************************** */

void GenericHost::updateActivities() {
  time_t when = iface->getTimeLastPktRcvd();

  if(when != last_activity_update) {
    /* Set a bit every CONST_TREND_TIME_GRANULARITY seconds */
    when -= when % CONST_TREND_TIME_GRANULARITY;
    if(when > activityStats.get_wrap_time()) dumpStats(false);
    activityStats.set(when);
    last_activity_update = when;
  }
}

/* *************************************** */

void GenericHost::incStats(u_int8_t l4_proto, u_int ndpi_proto,
			   u_int64_t sent_packets, u_int64_t sent_bytes, u_int64_t sent_goodput_bytes,
			   u_int64_t rcvd_packets, u_int64_t rcvd_bytes,  u_int64_t rcvd_goodput_bytes) {
  if(sent_packets || rcvd_packets) {
    sent.incStats(sent_packets, sent_bytes), rcvd.incStats(rcvd_packets, rcvd_bytes);

    if((ndpi_proto != NO_NDPI_PROTOCOL) && ndpiStats)
      ndpiStats->incStats(ndpi_proto, sent_packets, sent_bytes, rcvd_packets, rcvd_bytes);

    updateSeen();
  }
}

/* *************************************** */

void GenericHost::resetPeriodicStats() {
  last_bytes_periodic = 0;
}


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

#include "ntop_includes.h"

/* ******************************* */

NtopngLuaContext::NtopngLuaContext() {
  allowed_ifname = user = group = csrf = sqlite_hosts_filter = sqlite_flows_filter = NULL;
  sqlite_filters_loaded = false;
  zmq_context = zmq_subscriber = NULL;
  conn = NULL;
  allowedNets = NULL;
  iface = NULL;
  addr_tree = NULL;
  snmpBatch = NULL;
  memset(snmpAsyncEngine, 0, sizeof(snmpAsyncEngine));
  host = NULL, network = NULL, flow = NULL;
  localuser = false, observationPointId = 0, engine = NULL;
  capabilities = 0;
  memset(&pkt_capture, 0, sizeof(pkt_capture));
  memset(&live_capture, 0, sizeof(live_capture));
  next_reload = deadline = 0, threaded_activity = NULL;
  threaded_activity_stats = NULL;
#if defined(NTOPNG_PRO)
  bin = NULL;
#endif
  getbulkMaxNumRepetitions = 10;
}

/* ******************************* */

NtopngLuaContext::~NtopngLuaContext() {
  if (snmpBatch) delete snmpBatch;

  for (u_int16_t slot_id = 0; slot_id < MAX_NUM_ASYNC_SNMP_ENGINES; slot_id++) {
    if (snmpAsyncEngine[slot_id] != NULL)
      delete snmpAsyncEngine[slot_id];
  }

  if (pkt_capture.end_capture > 0) {
    pkt_capture.end_capture = 0; /* Force stop */
    pthread_join(pkt_capture.captureThreadLoop, NULL);
  }

  if ((iface != NULL) && live_capture.pcaphdr_sent)
    iface->deregisterLiveCapture(this);

  if (addr_tree != NULL)   delete addr_tree;
  if (sqlite_hosts_filter) free(sqlite_hosts_filter);
  if (sqlite_flows_filter) free(sqlite_flows_filter);

#if defined(NTOPNG_PRO)
  if (bin) delete bin;
#endif
}

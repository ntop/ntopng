/*
 *
 * (C) 2019 - ntop.org
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

#ifndef _ALERTS_QUEUE_H_
#define _ALERTS_QUEUE_H_

class NetworkInterface;

/* This class provides a way to send asynchronous alerts from C to Lua.
 * Alerts are processed by Lua in alert_utils.processStoreAlertFromQueue. */
class AlertsQueue {
 private:
  NetworkInterface *iface;

  void pushAlertJson(ndpi_serializer *alert, const char *atype, const char *a_subtype = NULL);

 public:
  AlertsQueue(NetworkInterface *iface);

  void pushOutsideDhcpRangeAlert(u_int8_t* cli_mac, Mac *sender_mac,
				 u_int32_t ip, u_int32_t router_ip, VLANid vlan_id);
  void pushMacIpAssociationChangedAlert(u_int32_t ip, u_int8_t *old_mac, u_int8_t *new_mac, Mac *new_host_mac);
  void pushBroadcastDomainTooLargeAlert(const u_int8_t *src_mac, const u_int8_t *dst_mac,
					u_int32_t spa, u_int32_t tpa, VLANid vlan_id);
  void pushLoginTrace(const char*user, bool authorized);
  void pushNfqFlushedAlert(int queue_len, int queue_len_pct, int queue_dropped);
};

#endif

/*
 *
 * (C) 2014-23 - ntop.org
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

#ifndef _ALERT_FIFO_ITEM_H
#define _ALERT_FIFO_ITEM_H

#include "ntop_includes.h"

class AlertFifoItem {
 public:
  AlertLevel alert_severity;
  AlertCategory alert_category;
  u_int32_t score;
  std::string alert; /* json */

  /* Metadata used for processing the notification */
  struct {
    u_int16_t host_pool;
    u_int16_t vlan_id;
    IpAddress ip;
  } host;

  struct {
    u_int16_t cli_host_pool;
    u_int16_t srv_host_pool;
    u_int16_t vlan_id;
    IpAddress cli_ip;
    IpAddress srv_ip;
    u_int16_t cli_port;
    u_int16_t srv_port;
    u_int8_t protocol;
  } flow;

  AlertFifoItem() {
    alert_severity = alert_level_none;
    alert_category = alert_category_other;
    score = 0;
  }

  AlertFifoItem(const AlertFifoItem *i) {
    alert_severity = i->alert_severity;
    alert_category = i->alert_category;
    score = i->score;
    alert = i->alert;
    host.host_pool = i->host.host_pool;
    host.vlan_id = i->host.vlan_id;
    host.ip.set(&i->host.ip);
    flow.cli_host_pool = i->flow.cli_host_pool;
    flow.srv_host_pool = i->flow.srv_host_pool;
    flow.vlan_id = i->flow.vlan_id;
    flow.cli_ip.set(&i->flow.cli_ip);
    flow.srv_ip.set(&i->flow.srv_ip);
    flow.cli_port = i->flow.cli_port;
    flow.srv_port = i->flow.srv_port;
    flow.protocol = i->flow.protocol;
  }

  ~AlertFifoItem() {}
};

#endif /* _ALERT_FIFO_ITEM_H */

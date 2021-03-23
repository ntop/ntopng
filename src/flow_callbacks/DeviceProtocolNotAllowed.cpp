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

#include "ntop_includes.h"
#include "flow_callbacks_includes.h"

void DeviceProtocolNotAllowed::protocolDetected(Flow *f) {
  if (!f->isDeviceAllowedProtocol()) {
    u_int16_t c_score, s_score;
    const IpAddress *attacker, *victim;

    if (!f->isCliDeviceAllowedProtocol()) {
      c_score = 80;
      s_score = 5;
      attacker = f->get_cli_ip_addr();
      victim = f->get_srv_ip_addr();
    } else {
      c_score = 5;
      s_score = 80;
      attacker = f->get_srv_ip_addr();
      victim = f->get_cli_ip_addr();
    }

    /* TODO
     * char buf[64];
     * attacker->print(buf, sizeof(buf);
     * victim->print(buf, sizeof(buf)
     * set_attacker(attacker)
     * set_victim(victim)
     */

    f->triggerAlertAsync(DeviceProtocolNotAllowedAlert::getClassType(), getSeverity(), c_score, s_score);
  }
}

/* ***************************************************** */

FlowAlert *DeviceProtocolNotAllowed::buildAlert(Flow *f) {
  return new DeviceProtocolNotAllowedAlert(this, f);
}

/* ***************************************************** */

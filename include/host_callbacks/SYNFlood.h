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

#ifndef _SYN_FLOOD_H_
#define _SYN_FLOOD_H_

#include "ntop_includes.h"

class SYNFlood : public FlowHits {
 private:

 public:
  SYNFlood() : FlowHits() {};
  ~SYNFlood() {};

  FlowHitsAlert *allocAlert(Host *h, AlertLevel severity, u_int8_t cli_score, u_int8_t srv_score, u_int16_t hits, u_int64_t threshold, bool attacker) { return new SYNFloodAlert(this, h, severity, cli_score, srv_score, hits, threshold, attacker); };

  void periodicUpdate(Host *h, HostAlert *engaged_alert);

  HostCallbackID getID() const { return host_callback_syn_flood; }
  std::string getName()        const { return(std::string("syn_flood")); }
};

#endif

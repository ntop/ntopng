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

#ifndef _FLOW_HITS_ALERT_H_
#define _FLOW_HITS_ALERT_H_

#include "ntop_includes.h"

class FlowHitsAlert : public HostAlert {
 private:
  u_int64_t hits, hits_threshold;
  bool is_attacker; /* attacker or victim */

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);
  
 public:
  FlowHitsAlert(HostCheck *c, Host *h, risk_percentage cli_pctg, u_int16_t hits, u_int64_t threshold, bool is_attacker);
  ~FlowHitsAlert() {};

  void toggleAttacker(bool _is_attacker) { is_attacker = _is_attacker; }
  void setHits(u_int64_t _hits) { hits = _hits;}
  void setThreshold(u_int64_t _hits_threshold) { hits_threshold = _hits_threshold; }
  inline bool isAttacker() const { return is_attacker; }

  u_int8_t getAlertScore() const { return SCORE_LEVEL_WARNING; };
};

#endif /* _FLOW_HITS_ALERT_H_ */

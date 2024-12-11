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

#ifndef _FLOW_ALERT_H_
#define _FLOW_ALERT_H_

#include "ntop_includes.h"

class FlowAlert {
 private:
  Flow *flow;
  std::string check_name;
  bool cli_attacker, srv_attacker;
  bool cli_victim, srv_victim;
  u_int8_t cli_score, srv_score;
  u_int8_t alert_score;
  char *json_alert;
  
  /*
     Adds to the passed `serializer` (generated with `getAlertSerializer`)
     information specific to this alert
   */
  virtual ndpi_serializer *getAlertJSON(ndpi_serializer *serializer) {
    return serializer;
  }

 public:
  FlowAlert(FlowCheck *c, Flow *f);
  virtual ~FlowAlert();

  inline void setCliAttacker() { cli_attacker = true; }
  inline void setSrvAttacker() { srv_attacker = true; }
  inline void setCliVictim() { cli_victim = true; }
  inline void setSrvVictim() { srv_victim = true; }

  inline bool isCliAttacker() { return cli_attacker; }
  inline bool isCliVictim() { return cli_victim; }

  inline bool isSrvAttacker() { return srv_attacker; }
  inline bool isSrvVictim() { return srv_victim; }

  inline void setCliSrvScores(u_int8_t c, u_int8_t s) {
    cli_score = min_val(c, SCORE_MAX_VALUE); 
    srv_score = min_val(s, SCORE_MAX_VALUE);
    if (cli_score + srv_score > SCORE_MAX_VALUE) srv_score = SCORE_MAX_VALUE - cli_score;
  };
  inline u_int8_t getCliScore() { return cli_score; };
  inline u_int8_t getSrvScore() { return srv_score; };

  virtual FlowAlertType getAlertType() const = 0;
  inline u_int8_t getAlertScore() const { return alert_score; };
  inline void setAlertScore(u_int8_t value) { alert_score = value; };
  
  /* false = alert that requires attention, true = not important (auto ack) */
  virtual bool autoAck() const { return true; };

  inline Flow *getFlow() const { return (flow); }
  inline std::string getCheckName() const { return (check_name); }

  /*
     Generates the JSON alert serializer with base information and per-check
     information gathered with `getAlertJSON`. The returned string should not
     be freed by the caller as it is a reference to an internal string released
     with the alert.
  */
  const char *getSerializedAlert();
};

#endif /* _FLOW_ALERT_H_ */

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

#ifndef _DANGEROUS_HOST_H_
#define _DANGEROUS_HOST_H_

#include "ntop_includes.h"

class DangerousHost : public HostCheck {
private:
  u_int64_t score_threshold;

  HostAlert *allocAlert(HostCheck *c, Host *h, u_int8_t cli_score, u_int8_t srv_score, u_int64_t _score, u_int64_t _consecutive_high_score) {
    DangerousHostAlert *alert = new DangerousHostAlert(c, h, cli_score, srv_score, _score, _consecutive_high_score);

    if(h->getScoreAsClient() > score_threshold)
      alert->setAttacker();
    else
      alert->setVictim();

    return alert;
  };

 public:
  DangerousHost();
  ~DangerousHost() {};

  void periodicUpdate(Host *h, HostAlert *engaged_alert);
  bool loadConfiguration(json_object *config);  

  HostCheckID getID() const { return host_check_dangerous_host; }
  std::string getName()      const { return(std::string("dangerous_host")); }
};

#endif

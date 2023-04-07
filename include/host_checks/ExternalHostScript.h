/*
 *
 * (C) 2013-23 - ntop.org
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

#ifndef _EXTERNAL_HOST_SCRIPT_H_
#define _EXTERNAL_HOST_SCRIPT_H_

#include "ntop_includes.h"

class ExternalHostScript : public HostCheck {
 private:
  bool disabled;

  HostAlert *allocAlert(HostCheck *c, Host *h, risk_percentage cli_pctg,
                        u_int32_t _score, std::string _msg) {
    ExternalHostScriptAlert *alert =
        new ExternalHostScriptAlert(c, h, cli_pctg, _score, _msg);

    if (cli_pctg != CLIENT_NO_RISK_PERCENTAGE) alert->setAttacker();

    return alert;
  };

 public:
  ExternalHostScript();
  ~ExternalHostScript(){};

  void periodicUpdate(Host *h, HostAlert *engaged_alert);
  bool loadConfiguration(json_object *config);

  HostCheckID getID() const { return host_check_external_script; }
  std::string getName() const { return (std::string("external_host_script")); }
};

#endif

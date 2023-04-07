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

#ifndef _EXTERNAL_HOST_SCRIPT_ALERT_H_
#define _EXTERNAL_HOST_SCRIPT_ALERT_H_

#include "ntop_includes.h"

class ExternalHostScriptAlert : public HostAlert {
 private:
  u_int8_t score;
  std::string msg;

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);

 public:
  static HostAlertType getClassType() {
    return {host_alert_external_script, alert_category_security};
  }

  ExternalHostScriptAlert(HostCheck* c, Host* f, risk_percentage cli_pctg,
                          u_int32_t _score, std::string _msg);
  ~ExternalHostScriptAlert(){};

  HostAlertType getAlertType() const { return getClassType(); }
  void setAlertMessage(std::string m) { msg = m; };
  void setAlertScore(u_int8_t v) { score = v; };
  virtual u_int8_t getAlertScore() const { return (score); };
};

#endif /* _EXTERNAL_HOST_SCRIPT_ALERT_H_ */

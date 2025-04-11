/*
 *
 * (C) 2013-25 - ntop.org
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

#ifndef _SCAN_REATIME_ALERT_H_
#define _SCAN_REATIME_ALERT_H_
 
#include "ntop_includes.h"
 
class ScanRealtimeAlert : public HostAlert {
private:
  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);
  std::vector<ScanAlertType> alerts;

public:
  static HostAlertType getClassType() {
    return {host_alert_scan_realtime, alert_category_security};
  }
    
  u_int8_t getAlertScore() const { 
    if (alerts.size()==2)
      return SCORE_LEVEL_SEVERE;
    else if (alerts.size()==3)
      return SCORE_LEVEL_CRITICAL;
    else if (alerts.size()>=4)
      return SCORE_LEVEL_EMERGENCY;
    else return SCORE_LEVEL_ERROR;
  };

  ScanRealtimeAlert(HostCheck* c, Host* h,risk_percentage cli_pctg, std::vector<ScanAlertType> _alerts)
    : HostAlert(c, h, cli_pctg) {
    alerts = _alerts;
  };
  ~ScanRealtimeAlert(){};

  HostAlertType getAlertType() const { return getClassType(); }
};
 
  #endif /* _SCAN_REATIME_ALERT_H_ */
 

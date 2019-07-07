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

#ifndef _ALERTABLE_ENTITY_H_
#define _ALERTABLE_ENTITY_H_

#include "ntop_includes.h"

class NetworkInterface;

class AlertableEntity {
 protected:
  std::map<std::string, std::string> alert_cache;
  std::set<std::string> triggered_alerts;
  
 public:
  AlertableEntity() { ; }

  inline std::string getAlertCachedValue(std::string key) {
    std::map<std::string, std::string>::iterator it = alert_cache.find(key);
    
    return((it != alert_cache.end()) ? it->second : std::string(""));
  }
  
  inline void setAlertCacheValue(std::string key, std::string value) { alert_cache[key] = value; }

  inline void  triggerAlert(std::string key) { triggered_alerts.insert(key);     }
  inline void  releaseAlert(std::string key) { triggered_alerts.erase(key);      }
  inline u_int getNumTriggeredAlerts()       { return(triggered_alerts.size()); }
};

#endif

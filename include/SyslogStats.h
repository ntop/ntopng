/*
 *
 * (C) 2013-20 - ntop.org
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

#ifndef _SYSLOG_STATS_H_
#define _SYSLOG_STATS_H_

#include "ntop_includes.h"

class SyslogStats {
 private:
  u_int32_t num_total_events;
  u_int32_t num_unhandled;
  u_int32_t num_alerts;
  u_int32_t num_host_correlations;
  u_int32_t num_collected_flows;

 public:
  SyslogStats();

  void resetStats();
  void incStats(u_int32_t num_total_events, u_int32_t num_unhandled,
    u_int32_t num_alerts, u_int32_t num_host_correlations, u_int32_t num_collected_flows);
  char* serialize();
  void deserialize(json_object *o);
  json_object* getJSONObject();
  void lua(lua_State* vm);
  void sum(SyslogStats *s) const;
};

#endif /* _SYSLOG_STATS_H_ */

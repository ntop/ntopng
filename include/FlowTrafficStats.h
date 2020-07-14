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

#ifndef _FLOW_TRAFFIC_STATS_H_
#define _FLOW_TRAFFIC_STATS_H_

#include "ntop_includes.h"

class FlowTrafficStats : public PartializableFlowTrafficStats {
 private:
  ndpi_analyze_struct cli2srv_bytes_stats, srv2cli_bytes_stats;

 public:
  FlowTrafficStats();
  FlowTrafficStats(const FlowTrafficStats &fts);

  virtual ~FlowTrafficStats();

  virtual void incStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len);
  virtual void setStats(bool cli2srv_direction, u_int num_pkts, u_int pkt_len, u_int payload_len);

  const ndpi_analyze_struct* get_analize_struct(bool cli2srv_direction) const;
  
};

#endif /* FLOW_TRAFFIC_STATS_H_ */

/*
 *
 * (C) 2020 - ntop.org
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

#ifndef _DYNAMIC_STATS_H_
#define _DYNAMIC_STATS_H_

#include "ntop_includes.h"

/* ******************************* */

class DynamicStats {
 private:
  struct ndpi_analyze_struct *contacted_peer_as_cli, 
                             *contacted_peer_as_srv;
  u_int16_t _max_series_len, actual_num;

public:
  DynamicStats(u_int16_t _max_series_len) {
    actual_num = 0;
    this->_max_series_len = _max_series_len;
    contacted_peer_as_cli = ndpi_alloc_data_analysis(this->_max_series_len);
    contacted_peer_as_srv = ndpi_alloc_data_analysis(this->_max_series_len);
  }
  
  ~DynamicStats() {
    if(contacted_peer_as_cli)
        ndpi_free_data_analysis(contacted_peer_as_cli);
    if(contacted_peer_as_srv)
        ndpi_free_data_analysis(contacted_peer_as_srv);
  }

  void init(u_int16_t _max_series_len) { ndpi_init_data_analysis(contacted_peer_as_cli, _max_series_len); };
  
  /* bool cli_or_srv => cli - true ; srv - false */
  void addElement(const u_int32_t value, bool cli_or_srv) {
    if(contacted_peer_as_srv && contacted_peer_as_cli) {
        if(cli_or_srv) ndpi_data_add_value(contacted_peer_as_cli, value);
        else           ndpi_data_add_value(contacted_peer_as_srv, value); 
        if(actual_num < _max_series_len) actual_num++;
    }
  }

  u_int32_t getCliSlidingEstimate() { return((u_int32_t)ndpi_data_window_average(contacted_peer_as_cli)); };
  u_int32_t getSrvSlidingEstimate() { return((u_int32_t)ndpi_data_window_average(contacted_peer_as_srv)); };
  u_int32_t getCliTotEstimate()     { return((u_int32_t)ndpi_data_average(contacted_peer_as_cli)); };
  u_int32_t getSrvTotEstimate()     { return((u_int32_t)ndpi_data_average(contacted_peer_as_srv)); };

  bool getSlidingWinStatus()        { return(actual_num == _max_series_len); };

  void reset() {
    if(contacted_peer_as_cli)   ndpi_free_data_analysis(contacted_peer_as_cli);
    if(contacted_peer_as_srv)   ndpi_free_data_analysis(contacted_peer_as_srv);
    contacted_peer_as_cli =     ndpi_alloc_data_analysis(_max_series_len);
    contacted_peer_as_srv =     ndpi_alloc_data_analysis(_max_series_len);
  }
};

#endif /* _CARDINALITY_H_ */

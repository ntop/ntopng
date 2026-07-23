/*
 *
 * (C) 2024-26 - ntop.org
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

#ifndef _CH_TS_POINT_H_
#define _CH_TS_POINT_H_

#include "ntop_includes.h"

/*
  Represents a (generic) timeseries point, used by ClickHouse timeseries to implement native dump.
*/
struct CHTSPoint {
  std::string schema_name;
  time_t tstamp;
  std::vector<std::pair<std::string, std::string>> tags;
  std::vector<std::pair<std::string, double>> metrics;
};

#endif /* _CH_TS_POINT_H_ */

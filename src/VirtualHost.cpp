/*
 *
 * (C) 2015-18 - ntop.org
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

#include "ntop_includes.h"

/* ************************************************** */

VirtualHost::VirtualHost(HostHash *_h, char *_name) : GenericHashEntry(NULL) {
  h = _h, name = strdup(_name), last_num_requests = 0, last_diff = 0, trend = trend_stable;
  h->incNumHTTPEntries();
}

/* ************************************************** */

VirtualHost::~VirtualHost() {
  h->decNumHTTPEntries();
  if(name) free(name);
}

/* ************************************************** */

void VirtualHost::update_stats() {
	u_int32_t diff = (u_int32_t)(num_requests.getNumBytes() - last_num_requests);

  trend = (diff > last_diff) ? trend_up : ((diff < last_diff) ? trend_down : trend_stable);
  /*
    ntop->getTrace()->traceEvent(TRACE_WARNING, "%s\t%u [%u][%u]", 
     name, diff, num_requests.getNumBytes(), last_num_requests);
  */
  last_num_requests = num_requests.getNumBytes(), last_diff = diff;
};

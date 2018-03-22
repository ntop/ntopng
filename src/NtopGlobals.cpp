/*
 *
 * (C) 2013-18 - ntop.org
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

/* **************************************** */

NtopGlobals::NtopGlobals() {
  start_time = time(NULL);
  ifMTU = snaplen = 1514;
  file_id = 0;
  trace = new Trace();  
  mutex = new Mutex();
  is_shutdown = shutdown_requested = false, do_decode_tunnels = true;
};

/* **************************************** */

NtopGlobals::~NtopGlobals() {
  delete trace;
  delete mutex;
};


/*
 *
 * (C) 2013-19 - ntop.org
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

/* *************************************** */

ParsedFlow::ParsedFlow() : ParsedFlowCore() {
  memset(&ebpf, 0, sizeof(ebpf));
  additional_fields = NULL;
  http_url = http_site = NULL;
  dns_query = ssl_server_name = NULL;
  bittorrent_hash = NULL;
  memset(&custom_app, 0, sizeof(custom_app));
  additional_fields = json_object_new_object();
}

/* *************************************** */

ParsedFlow::~ParsedFlow() {
  if(additional_fields)
    json_object_put(additional_fields);
}

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

#include "host_alerts_includes.h"

ndpi_serializer* ScanRealtimeAlert::getAlertJSON(ndpi_serializer* serializer) {
    #ifdef NTOPNG_PRO
        if (serializer == NULL) return NULL;
        ndpi_serialize_start_of_list(serializer, "alerts");
        for(ScanAlertType alert : alerts)
            ndpi_serialize_string_uint64(serializer, "alerts_addr", alert);
        ndpi_serialize_end_of_list(serializer);
    #endif
    
    return serializer;
}
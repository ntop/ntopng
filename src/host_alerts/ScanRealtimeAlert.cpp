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
        ndpi_serialize_string_uint64(serializer, "attack_type", attack_type);
        if (attack_type == scan_alert_scan_detention){
            ndpi_serialize_string_uint64(serializer, "value", num_incomplete_flows);
            ndpi_serialize_string_uint64(serializer, "threshold",
                                        num_incomplete_flows_threshold);
            ndpi_serialize_string_boolean(serializer, "is_rx_only", false);
        }
        else if (attack_type == scan_alert_rx_only)
        {
            ndpi_serialize_string_uint64(serializer, "num_server_ports", num_server_ports);
            ndpi_serialize_string_uint64(serializer, "as_server", as_server);
            ndpi_serialize_string_uint64(serializer, "as_server_threshold", as_server_threshold);
            ndpi_serialize_string_boolean(serializer, "is_rx_only", true);

        }
        else if (attack_type == scan_alert_syn ||
                attack_type == scan_alert_fin ||
                attack_type == scan_alert_rst){
            ndpi_serialize_string_boolean(serializer, "is_attacker", attacker);
            ndpi_serialize_string_uint64(serializer, "value", hits);
            ndpi_serialize_string_uint64(serializer, "threshold", sfr_threshold);
        }
    #endif
    
    return serializer;
}
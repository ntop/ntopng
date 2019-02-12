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

ArpStatsMatrixElement::ArpStatsMatrixElement(NetworkInterface *_iface, const u_int8_t _src_mac[6],
         const u_int8_t _dst_mac[6] ): GenericHashEntry(_iface) {

    memcpy(src_mac, _src_mac, 6);
    memcpy(dst_mac, _dst_mac, 6);
    stats.sent_replies = stats.sent_requests = stats.rcvd_replies = stats.rcvd_requests = 0

#ifdef ARP_STATS_MATRIX_ELEMENT_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "ADDED ArpMatrixElement: SourceMac %d - DestinationMac %d",
                  src_mac, dst_mac);
#endif
}

/* *************************************** */

ArpStatsMatrixElement::~ArpStatsMatrixElement(){
#ifdef ARP_STATS_MATRIX_ELEMENT_DEBUG
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "DELETED ArpMatrixElement: SourceMac %d - DestinationMac %d",
                  src_mac, dst_mac);
#endif

}

/* *************************************** */

bool ArpStatsMatrixElement::idle() { /*fun uguale a quella di Mac e Country, vedi meglio*/
    bool rc;

    if((num_uses > 0) || (!iface->is_purge_idle_interface()))
    return(false);

    rc = isIdle(MAX_LOCAL_HOST_IDLE);

#ifdef DEBUG
  if(true) {    /*perché if true!?*/
    char buf[32];

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Is idle %s [uses %u][%s][last: %u][diff: %d]",
				 Utils::formatMac(mac, buf, sizeof(buf)),
				 num_uses,
				 rc ? "Idle" : "Not Idle",
				 last_seen, iface->getTimeLastPktRcvd() - (last_seen+MAX_LOCAL_HOST_IDLE));
  }
#endif

  return(rc);
}

/* *************************************** */

bool ArpStatsMatrixElement::equal(const u_int8_t _src_mac[6], _dst_mac[6]) {
    if(! _src_mac || !_dst_mac)
        return(false);
    if(  memcmp(src_mac, _src_mac, 6) == 0 && memcmp(dst_mac, _dst_mac, 6) == 0  )
        return(true);
    else
        return(false);
}


/* *************************************** */

 u_int32_t key(){ 

   return ( Utils::macHash((u_int8_t*) src_mac) + Utils::macHash((u_int8_t*) dst_mac) );
  }

/* *************************************** */

//TODO: meteodi virtuali
//  virtual void set_to_purge(time_t t)  { will_be_purged = true;  };
//  virtual void housekeep()             { return;                 };
//  virtual char* get_string_key(char *buf, u_int buf_len) { buf[0] = '\0'; return(buf); };



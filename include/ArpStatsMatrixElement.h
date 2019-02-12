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

#ifndef _ARP_STATS_MATRIX_ELEMENT_H_
#define _ARP_STATS_MATRIX_ELEMENT_H_

#include "ntop_includes.h"

class ArpStatsMatrixElement : public GenericHashEntry {
private:

    ArpStats stats;
    u_int8_t src_mac[6];
    u_int8_t dst_mac[6];

public:

    ArpStatsMatrixElement(NetworkInterface *_iface, const u_int8_t _src_mac[6],
    const u_int8_t _dst_mac[6] ); ~ArpStatsMatrixElement();

    inline ArpStats getStats()      {return stats}
    inline Mac* getSourceMac()      {return src_mac}
    inline Mac* getDestinationMac() {return dst_mac}

    void setStats( u_int32_t sent_req, u_int32_t sent_res, u_int32_t rcv_req,u_int32_t rcv_res){
        stats.sent_replies = sent_res;
        stats.sent_requests = sent_req;
        stats.rcvd_replies = rcv_res;
        stats.rcvd_requests = rcv_req;
    }

    inline u_int32_t AddOneSentReplies()        { stats.sent_replies  ++ }
    inline u_int32_t AddOneSentRequests()       { stats.sent_requests ++ }
    inline u_int32_t AddOneReceivedReplies()    { stats.rcvd_replies  ++ }
    inline u_int32_t AddOneReceivedRequests()   { stats.rcvd_requests ++ }

    bool ArpStatsMatrixElement::equal(const u_int8_t _src_mac[6], _dst_mac[6]);

};

#endif /* _ARP_STATS_MATRIX_ELEMENT_H_ */


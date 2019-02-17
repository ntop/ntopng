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

    inline ArpStats getStats()           {return stats;}
    inline u_int8_t* getSourceMac()      {return src_mac;}
    inline u_int8_t* getDestinationMac() {return dst_mac;}

    void setStats( u_int32_t sent_req, u_int32_t sent_res, u_int32_t rcv_req,u_int32_t rcv_res){
        stats.sent.replies = sent_res;
        stats.sent.requests = sent_req;
        stats.rcvd.replies = rcv_res;
        stats.rcvd.requests = rcv_req;
    }

/*    void transposeElement(){
        u_int8_t *a1, *a2 = src_mac, dst_mac;
        u_int8_t *tmp;
        tmp = a1; a1 = a2; a2 = tmp;

        ReqReplyStats t = stats.sent;
        stats.sent = stats.rcvd;
        stats.rcvd = t;


        u_int32_t t = stats.sent_replies;
        stats.sent_replies = stats.rcvd_replies;
        stats.rcvd_replies = t;

        t = stats.sent_requests;
        stats.sent_requests = stats.rcvd_requests;
        stats.rcvd_requests = t;

    }
*/
    inline u_int32_t AddOneSentReplies()        { return ++stats.sent.replies; }
    inline u_int32_t AddOneSentRequests()       { return ++stats.sent.requests; }
    inline u_int32_t AddOneReceivedReplies()    { return ++stats.rcvd.replies; }
    inline u_int32_t AddOneReceivedRequests()   { return ++stats.rcvd.requests; }

    bool equal(const u_int8_t _src_mac[6], const u_int8_t _dst_mac[6]);
    bool idle();
    u_int32_t key();
    void lua(lua_State* vm);

};

#endif /* _ARP_STATS_MATRIX_ELEMENT_H_ */


/*
 *
 * (C) 2013-21 - ntop.org
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

#ifndef _REPLIES_REQUESTS_RATIO_ALERT_H_
#define _REPLIES_REQUESTS_RATIO_ALERT_H_


#include "ntop_includes.h"


class RepliesRequestsRatioAlert : public HostAlert {
 private:
  u_int8_t ratio_threshold;
  u_int32_t requests, replies;
  u_int8_t ratio;
  bool is_sent_rcvd; /* If true, requests are sent and replies are received. If false, requests are received and replies are sent */

  ndpi_serializer* getAlertJSON(ndpi_serializer* serializer);
  
 public:
  RepliesRequestsRatioAlert(HostCheck *c, Host *f, u_int8_t cli_score, u_int8_t srv_score, bool _is_sent_rcvd);
  ~RepliesRequestsRatioAlert() {};
  
  inline void setRepliesRequestsRatios(u_int8_t _ratio_threshold, u_int8_t _ratio, u_int32_t _requests, u_int32_t _replies) {
    ratio_threshold = _ratio_threshold;
    ratio = _ratio, requests = _requests, replies = _replies;
  }

  inline bool isSentReceived() const { return is_sent_rcvd; }
};

#endif /* _REPLIES_REQUESTS_RATIO_ALERT_H_ */

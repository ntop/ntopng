/*
 *
 * (C) 2013-16 - ntop.org
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

#include "activity_filters.h"
#include "ntop_includes.h"

bool activity_filter_fun_none(const activity_filter_config * config,
      activity_filter_status * status, Flow * flow,
      const struct timeval *when,
      bool cli2srv, uint16_t payload_len) {
  return false;
}

bool activity_filter_fun_rolling_mean(const activity_filter_config * config,
      activity_filter_status * status, Flow * flow,
      const struct timeval *when,
      bool cli2srv, uint16_t payload_len) {
  /* TODO implement */
  return false;
}

/*
 * Detects sequences of (client) command -> (server) reply.
 * 
 * Assumes client sends an ACK with no data when receiving multiple command replies.
 */
bool activity_filter_fun_command_sequence(const activity_filter_config * config,
      activity_filter_status * status, Flow * flow,
      const struct timeval *when,
      bool cli2srv, uint16_t payload_len) {
        
  struct timeval last = status->command_sequence.lastPacket;
  bool was_cli2srv = status->command_sequence.cli2srv;
  
  status->command_sequence.lastPacket = *when;
  status->command_sequence.cli2srv = cli2srv;

  if (status->command_sequence.reqSeen) {
    if (cli2srv && payload_len > 0) {
      // Command end
      status->command_sequence.reqSeen = false;
    } else if (Utils::msTimevalDiff((struct timeval*)when, &last) >= config->command_sequence.maxinterval) {
      // Timeout
      status->command_sequence.reqSeen = false;
    } else if (!cli2srv) {
      // Server reply

      if (was_cli2srv && payload_len == 0 && status->command_sequence.respBytes == 0) {
        status->command_sequence.srvWaited = true;
      } else {
        // server data
        status->command_sequence.respBytes += payload_len;
        status->command_sequence.respCount++;
      }
    } // else client ACK
  }

  if (!status->command_sequence.reqSeen && cli2srv && payload_len > 0) {
    // New client command
    status->command_sequence.reqSeen = true;
    status->command_sequence.srvWaited = false;
    status->command_sequence.respBytes = 0;
    status->command_sequence.respCount = 0;
  }
  
  if ((status->command_sequence.srvWaited || !config->command_sequence.mustwait) &&
      (status->command_sequence.respBytes >= config->command_sequence.minbytes) &&
      (status->command_sequence.respCount >= config->command_sequence.minflips)) {
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "CommandDetect filter: wait=%c bytes=%lu flips=%lu\n",
        status->command_sequence.srvWaited ? 'Y' : 'N',
        status->command_sequence.respBytes,
        status->command_sequence.respCount);
    return true;
  }
  return false;
}

bool activity_filter_fun_web(const activity_filter_config * config,
      activity_filter_status * status, Flow * flow,
      const struct timeval *when,
      bool cli2srv, uint16_t payload_len) {
  /* TODO implement */
  return false;
}

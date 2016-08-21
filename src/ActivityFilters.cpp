/*
 *
 * (C) 2013 - ntop.org
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

/* ********************************************************************** */

bool activity_filter_fun_none(const activity_filter_config * config,
			      activity_filter_status * status, Flow * flow,
			      const struct timeval *when,
			      bool cli2srv, uint16_t payload_len) {
  return true;
}

/* ********************************************************************** */

bool activity_filter_fun_rolling_mean(const activity_filter_config * config,
				      activity_filter_status * status, Flow * flow,
				      const struct timeval *when,
				      bool cli2srv, uint16_t payload_len) {
  /* TODO implement */
  return false;
}

/* ********************************************************************** */

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

/* ********************************************************************** */

bool activity_filter_fun_web(const activity_filter_config * config,
			     activity_filter_status * status, Flow * flow,
			     const struct timeval *when,
			     bool cli2srv, uint16_t payload_len) {
  if (status->web.samples < config->web.numsamples) {
    if (status->web.samples > 0 && Utils::msTimevalDiff((struct timeval *)when, &status->web.lastPacket) > config->web.maxinterval) {
      // force skip next time
      status->web.samples = config->web.numsamples + 1;
    } else {
      status->web.lastPacket = *when;
      
      if (payload_len > 0) {
        if (cli2srv)
          status->web.cliBytes += payload_len;
        else
          status->web.srvBytes += payload_len;

        if ( (status->web.samples == 0 && !cli2srv) ||
             (status->web.samples == 1 &&  cli2srv)
           ) {
          // violates  [client req] -> [server resp] -> ... rule, skip
          status->web.samples = config->web.numsamples + 1;
        }

        status->web.samples++;
        if ( (status->web.samples == config->web.numsamples) &&
             (status->web.srvBytes + status->web.cliBytes >= config->web.minbytes) &&
             (!config->web.serverdominant || status->web.srvBytes > status->web.cliBytes)
        ) {
            status->web.detected = true;
        }

        if (status->web.samples >= config->web.numsamples) {
          char buf[32];
          ntop->getTrace()->traceEvent(TRACE_DEBUG, "%c Web filter[%s] url/cert='%s%s' cli=%lu srv=%lu\n",
                status->web.detected ? '*' : ' ',
                flow->get_detected_protocol_name(buf, sizeof(buf)),
                flow->getHTTPURL(), flow->getSSLCertificate(),
                status->web.cliBytes, status->web.srvBytes);
        }
      }
    }
  }
  return status->web.detected;
}

/* ********************************************************************** */

/* This fitler is just for testing purposes. */
bool activity_filter_fun_metrics_test(const activity_filter_config * config,
			     activity_filter_status * status, Flow * flow,
			     const struct timeval *when,
			     bool cli2srv, uint16_t payload_len) {
  u_int32_t srv_bytes, cli_bytes;
  bool rv = false;
  
  if (!payload_len)
    return false;

  if (status->metrics.samples < ACTIVITY_FILTER_METRICS_SAMPLES) {
    status->metrics.sizes[status->metrics.samples] = payload_len;
    status->metrics.times[status->metrics.samples] = *when;
    status->metrics.directions[status->metrics.samples] = cli2srv;
    status->metrics.samples++;
    
    if (status->metrics.samples == ACTIVITY_FILTER_METRICS_SAMPLES) {
      float sizes[ACTIVITY_FILTER_METRICS_SAMPLES];
      float intervals[ACTIVITY_FILTER_METRICS_SAMPLES-1];
      float maxSize = 1;
      float maxInterval = 1;

      // Gather data
      srv_bytes = cli_bytes = 0;
      for (int i=0; i<ACTIVITY_FILTER_METRICS_SAMPLES; i++) {
        sizes[i] = status->metrics.sizes[i];
        if (sizes[i] > maxSize)
          maxSize = sizes[i];

        if (status->metrics.directions[i])
          cli_bytes += status->metrics.sizes[i];
        else
          srv_bytes += status->metrics.sizes[i];

        if (i > 0) {
          intervals[i-1] = Utils::msTimevalDiff(&status->metrics.times[i], &status->metrics.times[i-1]);
          if (intervals[i-1] > maxInterval)
            maxInterval = intervals[i-1];
        }
      }

      // Normalize data
      for (int i=0; i<ACTIVITY_FILTER_METRICS_SAMPLES; i++) {
        sizes[i] /= maxSize;
        if (i>0)
          intervals[i-1] /= maxInterval;
      }

      // Print data
      char buf[32];
      if (status->metrics.directions[0] == 1 && status->metrics.directions[1] == 0 && srv_bytes >= cli_bytes) {
        printf("+ ");
        rv = true;
      } else {
        printf("- ");
      }
      
      printf("FINGERPRINT <%p:%s>[%s%s]::", flow, flow->get_detected_protocol_name(buf, sizeof(buf)), flow->getHTTPURL(), flow->getSSLCertificate());
      for (int i=0; i<ACTIVITY_FILTER_METRICS_SAMPLES; i++) {
        printf(" %c +%u(%.3f) [%.3f]", status->metrics.directions[i] ? 'C' : 'S', status->metrics.sizes[i], sizes[i], i < (ACTIVITY_FILTER_METRICS_SAMPLES - 1) ? intervals[i] : 0);
      }
      printf("\n");
    }
  }
  
  return rv;
}

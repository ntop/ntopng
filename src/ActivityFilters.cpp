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
// #define DEBUG_FILTERS

/* ********************************************************************** */

static bool activity_filter_fun_all(const activity_filter_config * config,
				    activity_filter_status * status, Flow * flow,
				    const struct timeval *when,
				    bool cli2srv, uint16_t payload_len) {
  return config->all.pass;
}

/* ********************************************************************** */

/* Simple Moving Average with optional time bounds */
static bool activity_filter_fun_sma(const activity_filter_config * config,
				    activity_filter_status * status, Flow * flow,
				    const struct timeval *when,
				    bool cli2srv, uint16_t payload_len) {
  float msdiff = Utils::msTimevalDiff((struct timeval*)when, &status->sma.lastPacket);
  uint out = 0;
  
  if( (config->sma.timebound > 0 && status->sma.samples > 0) &&
       (msdiff >= config->sma.timebound) )
    // add empty packets to fill the gap
    for(float x=0; x < msdiff && out < status->sma.samples; x += config->sma.timebound, out++);
  else if(status->sma.samples == ACTIVITY_FILTER_SMA_SAMPLES)
    out = 1;
  else
    out = 0;
  
  for(uint i=0; i<out; i++)
    status->sma.value -= status->sma.sbuf[i];
  status->sma.value = max(status->sma.value, 0.f);

  uint stillin = status->sma.samples - out;
  memmove(status->sma.sbuf, status->sma.sbuf+out, stillin * sizeof(status->sma.sbuf[0]));
  memset(status->sma.sbuf+stillin, 0, out * sizeof(status->sma.sbuf[0]));

  status->sma.samples = min(status->sma.samples+1, (uint)ACTIVITY_FILTER_SMA_SAMPLES);
  status->sma.sbuf[status->sma.samples-1] = payload_len;
  status->sma.value += payload_len;
  status->sma.lastPacket = *when;

  float sma = status->sma.value / status->sma.samples;
  bool rv;

  if( (status->sma.samples >= config->sma.minsamples) &&
       (sma >= config->sma.edge) ) {
    rv = true;
    status->sma.lastActivity = *when;
  } else if( (config->sma.sustain > 0) &&
              (Utils::msTimevalDiff((struct timeval*)when, &status->sma.lastActivity) <= config->sma.sustain) ) {
    rv = true;
  } else {
    rv = false;
  }

#ifdef DEBUG_FILTERS
  char buf[32];
  char * t = ctime((time_t*)&when->tv_sec); t[strlen(t)-1] = '\0';
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%c %s [%s] <%p %s%s> SMA[%u] = %.2f %u\n",
			       rv ? '*' : ' ', t,
			       flow->get_detected_protocol_name(buf, sizeof(buf)), flow,
			       flow->getHTTPURL(), flow->getSSLCertificate(),
			       status->sma.samples, sma, payload_len);
#endif
  return rv;
}

/* ********************************************************************** */

/* Weighted Moving Average scaling with inter-packed-delay seconds and optional aggregation */
static bool activity_filter_fun_wma(const activity_filter_config * config,
				    activity_filter_status * status, Flow * flow,
				    const struct timeval *when,
				    bool cli2srv, uint16_t payload_len) {
  // scale value on seconds difference
  float coeff = 1.f;
  float secdiff = -1;

  if(config->wma.timescale > 0 && status->wma.samples > 0) {
    secdiff = Utils::msTimevalDiff((struct timeval*)when, &status->wma.lastPacket) / 1000.f;
    coeff = 1.f / max(config->wma.timescale * secdiff, 1.f);
  }

  if(config->wma.aggrsecs && secdiff >= 0 && secdiff <= config->wma.aggrsecs && status->wma.samples == ACTIVITY_FILTER_WMA_SAMPLES) {
    // aggregation
    status->wma.sbuf[status->wma.samples-1] += payload_len;
    status->wma.weights[status->wma.samples-1] += coeff;
  } else {  
    if(status->wma.samples == ACTIVITY_FILTER_WMA_SAMPLES) {
      status->wma.value = max(status->wma.value - status->wma.sbuf[0] * status->wma.weights[0], 0.f);
      status->wma.wsum = max(status->wma.wsum - status->wma.weights[0], 1.f);
      memmove(status->wma.sbuf, status->wma.sbuf+1, (ACTIVITY_FILTER_WMA_SAMPLES-1) * sizeof(status->wma.sbuf[0]));
      memmove(status->wma.weights, status->wma.weights+1, (ACTIVITY_FILTER_WMA_SAMPLES-1) * sizeof(status->wma.weights[0]));
    }
    
    status->wma.samples = min(status->wma.samples+1, (uint)ACTIVITY_FILTER_WMA_SAMPLES);
    status->wma.sbuf[status->wma.samples-1] = payload_len;
    status->wma.weights[status->wma.samples-1] = coeff;
  }

  status->wma.value += payload_len * coeff;
  status->wma.wsum += coeff;
  
  status->wma.lastPacket = *when;
  float wma = status->wma.value / status->wma.wsum;
  bool rv = false;

  if( (status->wma.samples >= config->wma.minsamples) &&
       (wma >= config->wma.edge)
       ) rv = true;

#ifdef DEBUG_FILTERS
  char buf[32];
  char * t = ctime((time_t*)&when->tv_sec); t[strlen(t)-1] = '\0';
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%c %s [%s] <%p %s%s> WMA[%u] = %.2f (%.2f) %u\n",
			       rv ? '*' : ' ', t,
			       flow->get_detected_protocol_name(buf, sizeof(buf)), flow,
			       flow->getHTTPURL(), flow->getSSLCertificate(),
			       status->wma.samples, wma, status->wma.wsum, payload_len);
#endif
  return rv;
}

/* ********************************************************************** */

/*
 * Detects sequences of (client) command -> (server) reply.
 * 
 * Assumes client sends an ACK with no data when receiving multiple command replies.
 */
static bool activity_filter_fun_command_sequence(const activity_filter_config * config,
						 activity_filter_status * status, Flow * flow,
						 const struct timeval *when,
						 bool cli2srv, uint16_t payload_len) {
        
  struct timeval last = status->command_sequence.lastPacket;
  bool was_cli2srv = status->command_sequence.cli2srv;
  
  status->command_sequence.lastPacket = *when;
  status->command_sequence.cli2srv = cli2srv;

  if(status->command_sequence.reqSeen) {
    if(cli2srv && payload_len > 0) {
      // Command end
      status->command_sequence.reqSeen = false;
    } else if(Utils::msTimevalDiff((struct timeval*)when, &last) >= config->command_sequence.maxinterval) {
      // Timeout
      status->command_sequence.reqSeen = false;
      status->command_sequence.numCommands = 0;
    } else if(!cli2srv) {
      // Server reply

      if(was_cli2srv && payload_len == 0 && status->command_sequence.respBytes == 0) {
        status->command_sequence.srvWaited = true;
      } else {
        // server data
        status->command_sequence.respBytes += payload_len;
        status->command_sequence.respCount++;
      }
    } // else client ACK
  }

  if(!status->command_sequence.reqSeen && cli2srv && payload_len > 0) {
    // New client command
    if(status->command_sequence.respCount > 0)
      status->command_sequence.numCommands += 1;
    status->command_sequence.reqSeen = true;
    status->command_sequence.srvWaited = false;
    status->command_sequence.respBytes = 0;
    status->command_sequence.respCount = 0;
  }
  
  if((status->command_sequence.srvWaited || !config->command_sequence.mustwait) &&
      (status->command_sequence.respBytes >= config->command_sequence.minbytes) &&
      (status->command_sequence.numCommands >= config->command_sequence.mincommands) &&
      (status->command_sequence.respCount >= config->command_sequence.minflips)) {
#ifdef DEBUG_FILTERS
    char buf[32];
    ntop->getTrace()->traceEvent(TRACE_DEBUG, "* CommandDetect filter[%s]: %d wait=%c bytes=%lu flips=%lu dt=%f\n",
				 flow->get_detected_protocol_name(buf, sizeof(buf)),
				 status->command_sequence.numCommands,
				 status->command_sequence.srvWaited ? 'Y' : 'N',
				 status->command_sequence.respBytes,
				 status->command_sequence.respCount,
				 Utils::msTimevalDiff((struct timeval*)when, &last));
#endif
    return true;
  }
  return false;
}

/* ********************************************************************** */

static bool activity_filter_fun_web(const activity_filter_config * config,
				    activity_filter_status * status, Flow * flow,
				    const struct timeval *when,
				    bool cli2srv, uint16_t payload_len) {
  if(status->web.samples < config->web.numsamples) {
    if(status->web.samples > 0 && Utils::msTimevalDiff((struct timeval *)when, &status->web.lastPacket) > config->web.maxinterval) {
      // force skip next time
      status->web.samples = config->web.numsamples + 1;
    } else {
      status->web.lastPacket = *when;
      
      if(payload_len > 0) {
        if(cli2srv)
          status->web.cliBytes += payload_len;
        else
          status->web.srvBytes += payload_len;

        if( (status->web.samples == 0 && !cli2srv) ||
             (status->web.samples == 1 &&  cli2srv)
	     ) {
          // violates  [client req] -> [server resp] -> ... rule, skip
          status->web.samples = config->web.numsamples + 1;
        }

        status->web.samples++;
        if( (status->web.samples == config->web.numsamples) &&
             (status->web.srvBytes + status->web.cliBytes >= config->web.minbytes) &&
             (!config->web.serverdominant || status->web.srvBytes > status->web.cliBytes)
	     ) {
	  status->web.detected = true;
	  UserActivityID uaid;
	  if(config->web.forceWebProfile && (!flow->getActivityId(&uaid) || uaid == user_activity_other))
	    flow->setActivityId(user_activity_web);
        }
#ifdef DEBUG_FILTERS
        if(status->web.samples >= config->web.numsamples) {
          char buf[32];
          ntop->getTrace()->traceEvent(TRACE_DEBUG, "%c Web filter[%s] url/cert='%s%s' cli=%lu srv=%lu\n",
				       status->web.detected ? '*' : ' ',
				       flow->get_detected_protocol_name(buf, sizeof(buf)),
				       flow->getHTTPURL(), flow->getSSLCertificate(),
				       status->web.cliBytes, status->web.srvBytes);
        }
#endif
      }
    }
  }
  return status->web.detected;
}

/* ********************************************************************** */

static bool activity_filter_fun_ratio(const activity_filter_config * config,
				      activity_filter_status * status, Flow * flow,
				      const struct timeval *when,
				      bool cli2srv, uint16_t payload_len) {
  if(status->ratio.samples < config->ratio.numsamples) {
    if(payload_len > 0) {
      if(cli2srv)
        status->ratio.cliBytes += payload_len;
      else
        status->ratio.srvBytes += payload_len;
        
      status->ratio.samples++;

      if(status->ratio.samples == config->ratio.numsamples) {
        float n,d,r;
        
        if(config->ratio.clisrv_ratio > 0) {
          n = status->ratio.cliBytes;
          d = status->ratio.srvBytes;
        } else {
          n = status->ratio.srvBytes;
          d = status->ratio.cliBytes;
        }
        r = n / d;

        if(! d)
          status->ratio.detected = true;
        else
          status->ratio.detected = n + d >= config->ratio.minbytes && r >= fabsf(config->ratio.clisrv_ratio);
#ifdef DEBUG_FILTERS
        char buf[32];
        ntop->getTrace()->traceEvent(TRACE_DEBUG, "%c Ratio filter[%s] url/cert='%s%s' cli=%lu srv=%lu : %.3f\n",
				     status->ratio.detected ? '*' : ' ',
				     flow->get_detected_protocol_name(buf, sizeof(buf)),
				     flow->getHTTPURL(), flow->getSSLCertificate(),
				     status->ratio.cliBytes, status->ratio.srvBytes, r);
#endif
      }
    }
  }
  return status->ratio.detected;
}

/* ********************************************************************** */

static bool activity_filter_fun_interflow(const activity_filter_config * config,
					  activity_filter_status * status, Flow * flow,
					  const struct timeval *when,
					  bool cli2srv, uint16_t payload_len) {
  // Assert local client host begins connection 
  Host * host = flow->get_cli_host();
  int f_count = 0;
  u_int32_t f_pkts = 0;
  time_t max_duration = 0;
  InterFlowActivityProtos proto;
  bool rv = false;

  switch(flow->get_detected_protocol().app_protocol) {
  case NDPI_PROTOCOL_FACEBOOK:
    proto = ifa_facebook_stats;
    break;
  case NDPI_PROTOCOL_TWITTER:
    proto = ifa_twitter_stats;
    break;
  default:
    char buf[32];
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Interflow filter undefined for protocol %s\n", flow->get_detected_protocol_name(buf, sizeof(buf)));
    return false;
  }

  if(config->interflow.sslonly && !flow->isSSLProto())
    return false;

  host->incIfaPackets(proto, flow, when->tv_sec);
  host->getIfaStats(proto, when->tv_sec, &f_count, &f_pkts, &max_duration);

  if(f_pkts >= config->interflow.minpkts &&
      ((config->interflow.minduration >= 0 && max_duration >= config->interflow.minduration) ||
       (config->interflow.minflows >= 0 && f_count >= config->interflow.minflows)))
    rv = true;
#ifdef DEBUG_FILTERS
  char buf[32];
  ntop->getTrace()->traceEvent(TRACE_DEBUG, "%c Interflow filter[%s] url/cert='%s%s' concurrent pkts=%u/%d - flows=%d/%d, dur=%lu/%ds\n",
			       rv ? '*' : ' ',
			       flow->get_detected_protocol_name(buf, sizeof(buf)),
			       flow->getHTTPURL(), flow->getSSLCertificate(),
			       f_pkts, config->interflow.minpkts,
			       f_count, config->interflow.minflows >= 0 ? config->interflow.minflows : 0,
			       max_duration, config->interflow.minduration >= 0 ? config->interflow.minduration : 0);
#endif
  return rv;
}

/* ********************************************************************** */

/* This filter is just for testing purposes. */
static bool activity_filter_fun_metrics_test(const activity_filter_config * config,
					     activity_filter_status * status, Flow * flow,
					     const struct timeval *when,
					     bool cli2srv, uint16_t payload_len) {
  u_int32_t srv_bytes, cli_bytes;
  bool rv = false;
  
  if(!payload_len)
    return false;

  if(status->metrics.samples < ACTIVITY_FILTER_METRICS_SAMPLES) {
    status->metrics.sizes[status->metrics.samples] = payload_len;
    status->metrics.times[status->metrics.samples] = *when;
    status->metrics.directions[status->metrics.samples] = cli2srv;
    status->metrics.samples++;
    
    if(status->metrics.samples == ACTIVITY_FILTER_METRICS_SAMPLES) {
      float sizes[ACTIVITY_FILTER_METRICS_SAMPLES];
      float intervals[ACTIVITY_FILTER_METRICS_SAMPLES-1];
      float maxSize = 1;
      float maxInterval = 1;

      // Gather data
      srv_bytes = cli_bytes = 0;
      for(int i=0; i<ACTIVITY_FILTER_METRICS_SAMPLES; i++) {
        sizes[i] = status->metrics.sizes[i];
        if(sizes[i] > maxSize)
          maxSize = sizes[i];

        if(status->metrics.directions[i])
          cli_bytes += status->metrics.sizes[i];
        else
          srv_bytes += status->metrics.sizes[i];

        if(i > 0) {
          intervals[i-1] = Utils::msTimevalDiff(&status->metrics.times[i], &status->metrics.times[i-1]);
          if(intervals[i-1] > maxInterval)
            maxInterval = intervals[i-1];
        }
      }

      // Normalize data
      for(int i=0; i<ACTIVITY_FILTER_METRICS_SAMPLES; i++) {
        sizes[i] /= maxSize;
        if(i>0)
          intervals[i-1] /= maxInterval;
      }

      // Print data
      char buf[32];
      if(status->metrics.directions[0] == 1 && status->metrics.directions[1] == 0 && srv_bytes >= cli_bytes) {
        printf("+ ");
        rv = true;
      } else {
        printf("- ");
      }
      
      printf("FINGERPRINT <%p:%s>[%s%s]::", flow, flow->get_detected_protocol_name(buf, sizeof(buf)), flow->getHTTPURL(), flow->getSSLCertificate());

      for(int i=0; i<ACTIVITY_FILTER_METRICS_SAMPLES; i++) {
        printf(" %c +%u(%.3f) [%.3f]", status->metrics.directions[i] ? 'C' : 'S',
	       status->metrics.sizes[i], sizes[i], i < (ACTIVITY_FILTER_METRICS_SAMPLES - 1) ? intervals[i] : 0);
      }
      printf("\n");
    }
  }
  
  return rv;
}

/* ********************************************************************** */

activity_filter_t* activity_filter_funcs[] = {
  activity_filter_fun_all,
  activity_filter_fun_sma,
  activity_filter_fun_wma,
  activity_filter_fun_command_sequence,
  activity_filter_fun_web,
  activity_filter_fun_ratio,
  activity_filter_fun_interflow,
  activity_filter_fun_metrics_test,
};

COMPILE_TIME_ASSERT (COUNT_OF(activity_filter_funcs) == ActivityFiltersN);

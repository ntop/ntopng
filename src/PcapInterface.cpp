/*
 *
 * (C) 2013-24 - ntop.org
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
xo */

#include "ntop_includes.h"

#ifdef __APPLE__
#include <uuid/uuid.h>
#endif

//#define DEBUG_POLLING

#ifndef HAVE_NEDGE

/* **************************************************** */

PcapInterface::PcapInterface(const char *name, u_int8_t ifIdx,
                             bool _delete_pcap_when_done)
  : NetworkInterface(name) {
  char pcap_error_buffer[PCAP_ERRBUF_SIZE];
  struct stat buf;

  if(trace_new_delete) ntop->getTrace()->traceEvent(TRACE_NORMAL, "[new] %s", __FILE__);
  delete_pcap_when_done = _delete_pcap_when_done;
  memset(pcap_handle, 0, sizeof(pcap_handle));
  memset(pcap_ifaces, 0, sizeof(pcap_ifaces));
  memset(ifname_indexes, 0, sizeof(ifname_indexes));
  num_ifaces = 0, pcap_list = NULL;
  memset(&last_pcap_stat, 0, sizeof(last_pcap_stat));
  emulate_traffic_directions = false;
  read_pkts_from_pcap_dump = read_pkts_from_pcap_dump_done = false,
    read_from_stdin_pipe = false;

  firstPktTS.tv_sec = 0;
  pcap_path = NULL;
  iface_datalink[0] = DLT_EN10MB; /* default */

  if ((stat(name, &buf) == 0) || (name[0] == '-') ||
      !strncmp(name, "stdin", 5)) {
    /*
      The file exists so we need to check if it's a
      text file or a pcap file
    */

    if (strcmp(name, "-") == 0 || !strncmp(name, "stdin", 5)) {
      /* stdin */
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from stdin...");
      pcap_error_buffer[0] = '\0';
      pcap_handle[0] = pcap_fopen_offline(stdin, pcap_error_buffer);
      iface_datalink[0] = pcap_datalink(pcap_handle[0]);
      read_pkts_from_pcap_dump = false;
      is_traffic_mirrored = true;
      emulate_traffic_directions = true;
      read_from_stdin_pipe = true;
      num_ifaces = 1;
    } else if ((pcap_handle[0] = pcap_open_offline(ifname, pcap_error_buffer)) != NULL) {
      char *slash = strrchr(ifname, '/');

      pcap_path = strdup(ifname);
      if (slash) {
        char *old = ifname;
        ifname = strdup(&slash[1]);
        free(old);
      }

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from pcap file %s...", ifname);
      read_pkts_from_pcap_dump = true,
	purge_idle_flows_hosts = ntop->getPrefs()->purgeHostsFlowsOnPcapFiles();
      iface_datalink[0] = pcap_datalink(pcap_handle[0]);
      num_ifaces = 1;
    } else {
      /* Trying to open a playlist */
      if ((pcap_list = fopen(name, "r")) != NULL) {
        read_pkts_from_pcap_dump = true;
      } else {
        ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open file %s", name);
        exit(0);
      }
    }
  } else {
    char dev_names[64], *dev;

    snprintf(dev_names, sizeof(dev_names), "%s", ifname);
    dev = strtok(dev_names, ",");

    while(dev != NULL) {
      if(num_ifaces == MAX_NUM_PCAP_INTERFACES) {
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Too many interfaces (%d) in %s: skipping", num_ifaces, ifname);
	break;
      }

      pcap_handle[num_ifaces] = pcap_open_live(dev, ntop->getGlobals()->getSnaplen(dev),
						ntop->getPrefs()->use_promiscuous(),
						1000 /* 1 sec */, pcap_error_buffer);

      if(pcap_handle[num_ifaces] != NULL) {
	iface_datalink[num_ifaces] = pcap_datalink(pcap_handle[num_ifaces]);
	ifname_indexes[num_ifaces] = if_nametoindex(dev);
	pcap_ifaces[num_ifaces]    = strdup(dev);

	if(pcap_ifaces[num_ifaces] == NULL) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "Not enough memory");
	  break;
	}

	/* This is necessay as with multiple comma separated interfaces we need to take the max MTU */
	ifMTU = ndpi_max(ifMTU, Utils::getIfMTU(pcap_ifaces[num_ifaces]));

	pcap_path = NULL;
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from %s [ifId: %d]",
				     dev, ifIdx);
	read_pkts_from_pcap_dump = false;

	Utils::readMac(dev, ifMac);

#ifndef WIN32
	if (pcap_setdirection(pcap_handle[num_ifaces], ntop->getPrefs()->getCaptureDirection()) != 0)
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set packet capture direction");

	if(!isTrafficMirrored()) {
	  if (Utils::readInterfaceStats(dev, &prev_stats_in, &prev_stats_out))
	    emulate_traffic_directions = true;
	}
#endif

	num_ifaces++;
      } else
	throw errno;

      dev = strtok(NULL, ",");
    } /* while */
  }

  set_datalink(iface_datalink[0]);

  if (read_pkts_from_pcap_dump) {
    /* Used to cleanup data during next ntopng startup */
    char id_str[8];
    snprintf(id_str, sizeof(id_str), "%d", get_id());

    ntop->getRedis()->hashSet(PCAP_DUMP_INTERFACES_DELETE_HASH, id_str, get_name());
  }

  if (ntop->getPrefs()->are_ixia_timestamps_enabled())
    ntop->getTrace()->traceEvent(TRACE_WARNING,
				 "Hardware timestamps are supported only on PF_RING capture interfaces");
}

/* **************************************************** */

PcapInterface::~PcapInterface() {
  for(u_int8_t i=0; i < get_num_ifaces(); i++) {
    if (pcap_handle[i]) {
      pcap_close(pcap_handle[i]);
      pcap_handle[i] = NULL;
    }

    if (pcap_ifaces[i])
      free(pcap_ifaces[i]);
  }

  if (pcap_path != NULL) {
    if (delete_pcap_when_done) unlink(pcap_path);
    free(pcap_path);
  }

  if (getIfType() == interface_type_PCAP_DUMP) {
    /* Cleanup any possible leftover file */
    cleanupPcapDumpDir();
  }
}

/* **************************************************** */

void PcapInterface::cleanupPcapDumpDir() {
  char base_dir[MAX_PATH];

  if (snprintf(base_dir, sizeof(base_dir), "%s/%d", ntop->get_working_dir(),
               get_id()) < (int)sizeof(base_dir)) {
    ntop->fixPath(base_dir);
    Utils::remove_recursively(base_dir);
  }
}

/* **************************************************** */

/*
  Account flow traffic in the network interface
*/
static bool idle_flow_account(GenericHashEntry *h, void *user_data, bool *matched) {
  Flow *f = (Flow*)h;
  
  f->accountFlowTraffic();

  return(false);
}

/* **************************************************** */

static void *packetPollLoop(void *ptr) {
  PcapInterface *iface = (PcapInterface *)ptr;
  FILE *pcap_list = iface->get_pcap_list();
  int fds[MAX_NUM_PCAP_INTERFACES] = { -1 };

  /* Wait until the initialization completes */
  while (iface->isStartingUp()) sleep(1);

  /* Test Script (Pre Analysis) */
  if (ntop->getPrefs()->get_test_pre_script_path()) {
    const char *test_pre_script_path =
        ntop->getPrefs()->get_test_pre_script_path();

    /* Wait for the HTTP server to be able to serve requests
     * from the pre script, if any */
    while (!ntop->get_HTTPserver()->accepts_requests() &&
           !ntop->getGlobals()->isShutdown())
      sleep(1);

    /* Execute as Bash script */
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Running Pre Script '%s'",
                                 test_pre_script_path);
    Utils::exec(test_pre_script_path);

    /* Allow check configs to be re-read */
    sleep(ntop->getPrefs()->get_housekeeping_frequency()*2);

    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Processing pcap file");
  }

  do {
    if (pcap_list != NULL) {
      char path[256], *fname;
      pcap_t *file_pcap_handle;

      while ((fname = fgets(path, sizeof(path), pcap_list)) != NULL) {
        char pcap_error_buffer[PCAP_ERRBUF_SIZE];
        int l = (int)strlen(path) - 1;

        if ((l <= 1) || (path[0] == '#')) continue;
        path[l--] = '\0';

        /* Remove trailer white spaces */
        while ((l > 0) && (path[l] == ' ')) path[l--] = '\0';

        while (l > 0) {
          if (!isascii(path[l--])) {
            /* This looks like a bad file */
            fname = NULL;
            break;
          }
        }

        if (fname != NULL) {
          if ((file_pcap_handle = pcap_open_offline(path, pcap_error_buffer)) ==  NULL) {
            ntop->getTrace()->traceEvent(TRACE_ERROR,
                                         "Unable to open file '%s': %s", path,
                                         pcap_error_buffer);
          } else {
            ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from pcap file %s", path);
            iface->set_pcap_handle(file_pcap_handle, 0);
            break;
          }
        } else
          break;
      }

      if (fname == NULL) {
        ntop->getTrace()->traceEvent(TRACE_NORMAL, "No more pcap files to read");
        fclose(pcap_list);
        break;
      } else
        iface->set_datalink(pcap_datalink(file_pcap_handle));
    }

    /* Wait until the interface is active */
    while (iface->idle()) {
      iface->purgeIdle(time(NULL));
      sleep(1);
    }

#ifndef WIN32
    for(u_int8_t i=0; i < iface->get_num_ifaces(); i++) {
      pcap_t *pd = iface->get_pcap_handle(i);

      fds[i] = pcap_get_selectable_fd(pd);

#if defined(__APPLE__) || defined(__FreeBSD__)
      if(!iface->read_from_pcap_dump() && !iface->read_from_stdin()) {
	char pcap_error_buffer[PCAP_ERRBUF_SIZE];

	if(pcap_setnonblock(pd, 1, pcap_error_buffer))
	  ntop->getTrace()->traceEvent(TRACE_ERROR,
				       "Unable to enable non blocking mode on %s: %s",
				       iface->getPcapIfaceName(i),
				       pcap_error_buffer);
      }
#endif
    }
#endif

    while (iface->isRunning() && (!ntop->getGlobals()->isShutdown())) {
	int max_fd = 0;
#ifndef WIN32
	fd_set rset;
	struct timeval tv;
	bool do_break = false;
#ifdef DEBUG_POLLING
	bool found = false;
#endif

	FD_ZERO(&rset);

	for(u_int8_t i=0; i < iface->get_num_ifaces(); i++) {
	  FD_SET(fds[i], &rset);

	  if(fds[i] > max_fd) max_fd = fds[i];
	}

#if defined(__APPLE__) || defined(__FreeBSD__)
	/*
	  On some, but not all, platforms, if a packet buffer timeout was specified,
	  the wait will terminate after the packet buffer timeout expires; applications
	  should be prepared for this, as it happens on some platforms, but should not
	  rely on it, as it does not happen on other platforms. Note that the wait might,
	  or might not, terminate even if no packets are available; applications should
	  be prepared for this to happen, but must not rely on it happening.

	  A handle can be put into ``non-blocking mode'', so that those routines will,
	  rather than blocking, return an indication that no packets are available to read.
	  Call pcap_setnonblock() to put a handle into non-blocking mode or to take it out
	  of non-blocking mode; call pcap_getnonblock() to determine whether a
	  handle is in non-blocking mode.
	*/
	tv.tv_sec = 0, tv.tv_usec = 10000 /* it must be < pcap_open_live() timeout */;
#else
	tv.tv_sec = 1, tv.tv_usec = 0;
#endif

	if(select(max_fd + 1, &rset, NULL, NULL, &tv) == 0) {
#ifdef DEBUG_POLLING
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "No packet to process");
#endif

	  for(u_int8_t i=0; i < iface->get_num_ifaces(); i++) {
	    if(!iface->read_from_stdin() &&
               !Utils::nwInterfaceExists(iface->getPcapIfaceName(i))) {
	      ntop->getTrace()->traceEvent(TRACE_WARNING,
					   "Network Interface %s (id %d) disappeared (is it is down ?)",
					   iface->getPcapIfaceName(i), i);
	      iface->reopen(i); /* Try to reopen the interface that disappeared */
	    }

	    iface->purgeIdle(time(NULL));
	  } /* for */

#if !(defined(__APPLE__) || defined(__FreeBSD__))
	  continue;
#endif
	}

	if(iface->idle())
	  continue;

	for(u_int8_t i=0; i < iface->get_num_ifaces(); i++) {
#if !(defined(__APPLE__) || defined(__FreeBSD__))
	  if(FD_ISSET(fds[i], &rset))
#endif
	    {
#ifdef DEBUG_POLLING
	    ntop->getTrace()->traceEvent(TRACE_WARNING, "processNextPacket(%d)", i);
#endif

	    if(iface->processNextPacket(iface->get_pcap_handle(i),
					iface->get_ifindex(i),
					iface->get_ifdatalink(i)) == false) {
	      do_break = true;
	      break;
	    }
#ifdef DEBUG_POLLING
	    found = true;
#endif
	  }
	}

#ifdef DEBUG_POLLING
	if(!found)
	  ntop->getTrace()->traceEvent(TRACE_WARNING, "**** NO packet");
#endif
	if(do_break)
	  break;
#else
	if(iface->processNextPacket(iface->get_pcap_handle(0),
				     iface->get_ifindex(0),
				     iface->get_ifdatalink(0)) == false)
	  break;
#endif
    } /* while */

  } while (pcap_list != NULL);

  if(iface->read_from_pcap_dump()) {
    FlowHash *fh = iface->get_flows_hash();
    u_int32_t begin_slot = 0;
    
    iface->set_read_from_pcap_dump_done();

    fh->walk(&begin_slot, true /* walk_all */, idle_flow_account, NULL /* user_data */);
  }
  
  /* Do two full scans to make sure all stats are updated */
  for (int i = 0; i < 2; i++)
    iface->purgeIdle(time(NULL), false, true /* Full scan */);

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminated packet polling for %s",
                               iface->get_description());

  return (NULL);
}

/* **************************************************** */

void PcapInterface::startPacketPolling() {
  pthread_create(&pollLoop, NULL, packetPollLoop, (void *)this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

u_int32_t PcapInterface::getNumDroppedPackets() {
#ifndef WIN32
  u_int32_t tot = 0;

  for(u_int8_t i=0; i < get_num_ifaces(); i++) {
    /* It seems this leads to crashes on Windows */
    struct pcap_stat pcapStat;

    if(pcap_handle[i] && (pcap_stats(pcap_handle[i], &pcapStat) >= 0)) {
      tot += pcapStat.ps_drop;
#ifdef DEBUG_POLLING
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "[id: %u][pkts: %u][drops: %u]", i, pcapStat.ps_recv, pcapStat.ps_drop);
#endif
    }
  }

  return(tot);
#endif

  return 0;
}

/* **************************************************** */

bool PcapInterface::set_packet_filter(char *filter) {
  for(u_int8_t i=0; i < get_num_ifaces(); i++) {
    struct bpf_program fcode;
    struct in_addr netmask;
    int rc;

    if (!pcap_handle[i]) return (false);

    netmask.s_addr = htonl(0xFFFFFF00);

    rc = pcap_compile(pcap_handle[i], &fcode, filter, 1, netmask.s_addr);

    if (rc < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to compile %s filter %s. Filter ignored.",
				   ifname, filter);
      return (false);
    }

    rc = pcap_setfilter(pcap_handle[i], &fcode);

    pcap_freecode(&fcode);

    if (rc < 0) {
      ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set on %s filter %s. Filter ignored.",
				   ifname, filter);
      return (false);
    }
  } /* for */

  ntop->getTrace()->traceEvent(TRACE_NORMAL,
			       "Packet capture filter on %s set to \"%s\"",
			       ifname, filter);

  /* can't get consistent stats while bpf is set */
  emulate_traffic_directions = false;

  return (true);
}

/* **************************************************** */

/* Computes the counter delta handling wrapping on 32 bit platforms */
static u_int64_t getCounterInc(u_int64_t old_v, u_int64_t new_v) {
  /* Assume wrapping only occurs on 32 bit platforms (e.g. armv7l raspbian) */
  const u_int32_t max_val = (u_int32_t)-1;

  if (new_v >= old_v)
    return (new_v - old_v);
  else {
    /* Counter wrapped */
    if (max_val >= old_v)
      return ((max_val - old_v) + new_v);
    else
      /* this should never occur */
      return (new_v);
  }
}

/* **************************************************** */

/* This method is only executed by the periodic script second.lua
 * Note: this is required as libpcap does not provide packets/bytes
 * statistics per direction. Make sure ethStats are not increased
 * by the packet processing function when this is in place. */
void PcapInterface::updateDirectionStats() {
  if(emulate_traffic_directions) {
    ProtoStats current_stats_in, current_stats_out;
    bool ret = true;

    for(u_int8_t i=0; i < get_num_ifaces(); i++) {
      if (pcap_ifaces[i]) {
        ret &= Utils::readInterfaceStats(pcap_ifaces[i], &current_stats_in, &current_stats_out);
      }
    }

    if(ret) {
      pcap_direction_t capture_dir = ntop->getPrefs()->getCaptureDirection();

      /* grsec check, the new ntopng user may not able to read the stats anymore */
      if ((prev_stats_in.getPkts() || prev_stats_out.getPkts())
	  && (!(current_stats_in.getPkts() || current_stats_out.getPkts()))) {
	ntop->getTrace()->traceEvent(TRACE_WARNING,
				     "Cannot read interface stats after user "
				     "change (grsec kernel hardening in place?)");
	emulate_traffic_directions = false;
      } else {
	if ((capture_dir == PCAP_D_INOUT) || (capture_dir == PCAP_D_IN)) {
	  ethStats.incNumPackets(true, getCounterInc(prev_stats_in.getPkts(), current_stats_in.getPkts()));
	  ethStats.incNumBytes(true, getCounterInc(prev_stats_in.getBytes(),  current_stats_in.getBytes()));
	}

	if ((capture_dir == PCAP_D_INOUT) || (capture_dir == PCAP_D_OUT)) {
	  ethStats.incNumPackets(false, getCounterInc(prev_stats_out.getPkts(), current_stats_out.getPkts()));
	  ethStats.incNumBytes(false, getCounterInc(prev_stats_out.getBytes(),  current_stats_out.getBytes()));
	}

	prev_stats_in = current_stats_in, prev_stats_out = current_stats_out;
      }
    }
  }
}

/* **************************************************** */

bool PcapInterface::reproducePcapOriginalSpeed() const {
  return (read_pkts_from_pcap_dump
	  && ntop->getPrefs()->reproduceOriginalSpeed());
}

/* **************************************************** */

bool PcapInterface::reopen(u_int8_t iface_id) {
  pcap_close(pcap_handle[iface_id]);

  Utils::gainWriteCapabilities();

  while(!ntop->getGlobals()->isShutdown()) {
    char pcap_error_buffer[PCAP_ERRBUF_SIZE];

    ntop->getTrace()->traceEvent(TRACE_INFO, "Trying to open %s", pcap_ifaces[iface_id]);

    pcap_handle[iface_id] = pcap_open_live(pcap_ifaces[iface_id], ntop->getGlobals()->getSnaplen(pcap_ifaces[iface_id]),
				 ntop->getPrefs()->use_promiscuous(),
				 1000 /* 1 sec */, pcap_error_buffer);

    if(pcap_handle[iface_id]) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Interface %s is back", pcap_ifaces[iface_id]);
      Utils::dropWriteCapabilities();
      return(true);
    } else
      ntop->getTrace()->traceEvent(TRACE_INFO, "Unable to open %s: %s",
				   pcap_ifaces[iface_id], pcap_error_buffer);

    sleep(1);
  }

  Utils::dropWriteCapabilities();

  return(false);
}

/* **************************************************** */

void PcapInterface::sendTermination() {
  for(u_int8_t i=0; i < get_num_ifaces(); i++) {
    if(pcap_handle[i])
      pcap_breakloop(pcap_handle[i]);
  }
}

/* **************************************************** */

#ifdef TRACE
static u_int32_t num_pkts = 0;
#endif

bool PcapInterface::processNextPacket(pcap_t *pd, int32_t if_index, int datalink_type) {
  const u_char *pkt;
  struct pcap_pkthdr *hdr;
  int rc;

  if ((rc = pcap_next_ex(pd, &hdr, &pkt)) > 0) {
    if(ntop->getPrefs()->doReforgeTimestamps())
      gettimeofday(&hdr->ts, NULL);

    if (reproducePcapOriginalSpeed()) {
      struct timeval now;

      gettimeofday(&now, NULL);

      if (firstPktTS.tv_sec == 0) {
	startTS = now;
	firstPktTS = hdr->ts;
      } else {
	u_int32_t packetTimeDelta    = Utils::msTimevalDiff(&hdr->ts, &firstPktTS);
	u_int32_t fromStartTimeDelta = Utils::msTimevalDiff(&now, &startTS);

	if (packetTimeDelta > fromStartTimeDelta) {
	  u_int32_t sleepMs = packetTimeDelta - fromStartTimeDelta;

	  ntop->getTrace()->traceEvent(TRACE_DEBUG, "Sleeping %.3f sec",
				       ((float)(sleepMs)) / 1000);

	  _usleep(sleepMs * 1000);

	  /* Recompute after sleep */
	  gettimeofday(&now, NULL);
	}
      }

      hdr->ts = now;
    }

    if((pkt != NULL) && (hdr->caplen > 0)) {
      u_int16_t p;
      Host *srcHost = NULL, *dstHost = NULL;
      Flow *flow = NULL;

#ifdef WIN32
      /*
	For some unknown reason, on Windows winpcap
	gets crazy with specific packets and so ntopng
	crashes. Copying the packet memory onto a local buffer
	prevents that, as specified in
	https://github.com/ntop/ntopng/issues/194
      */
      u_char pkt_copy[1600];
      struct pcap_pkthdr hdr_copy;

      memcpy(&hdr_copy, hdr, sizeof(hdr_copy));
      hdr_copy.len = min(hdr->len, sizeof(pkt_copy) - 1);
      hdr_copy.caplen = min(hdr_copy.len, hdr_copy.caplen);
      memcpy(pkt_copy, pkt, hdr_copy.len);
      dissectPacket(if_index,
		    DUMMY_BRIDGE_INTERFACE_ID, datalink_type,
		    true /* ingress - TODO: see if we pass the real
			    packet direction */
		    ,
		    NULL, &hdr_copy, (const u_char *)pkt_copy, &p,
		    &srcHost, &dstHost, &flow);
#else
      hdr->caplen = min_val(hdr->caplen, getMTU());

      dissectPacket(if_index,
		    DUMMY_BRIDGE_INTERFACE_ID, datalink_type,
		    true /* ingress - TODO: see if we pass the real
			    packet direction */
		    ,
		    NULL, hdr, pkt, &p, &srcHost, &dstHost, &flow);
#endif
    } else {
      incStats(true /* ingressPacket */, hdr->ts.tv_sec,
	       0, NDPI_PROTOCOL_UNKNOWN,
	       NDPI_PROTOCOL_CATEGORY_UNSPECIFIED,
	       0, hdr->len, 1);
    }
  } else if (rc < 0) {
    if (read_from_pcap_dump())
      return(false);
  } else {
    /* No packet received before the timeout */
    purgeIdle(time(NULL));
  }

#ifdef TRACE
  if(++num_pkts != ethStats.getNumPackets())
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Received %u / processed %u", num_pkts,  ethStats.getNumPackets());
#endif
  
  return(true);
}

#endif

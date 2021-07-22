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

#include "ntop_includes.h"

#ifdef __APPLE__
#include <uuid/uuid.h>
#endif

#ifndef HAVE_NEDGE

/* **************************************************** */

PcapInterface::PcapInterface(const char *name, u_int8_t ifIdx) : NetworkInterface(name) {
  char pcap_error_buffer[PCAP_ERRBUF_SIZE];
  struct stat buf;

  pcap_handle = NULL, pcap_list = NULL;
  memset(&last_pcap_stat, 0, sizeof(last_pcap_stat));
  emulate_traffic_directions = false;
  read_pkts_from_pcap_dump = read_pkts_from_pcap_dump_done = false;

  if((stat(name, &buf) == 0) || (name[0] == '-') || !strncmp(name, "stdin", 5)) {
    /*
      The file exists so we need to check if it's a
      text file or a pcap file
    */

    if(strcmp(name, "-") == 0 || !strncmp(name, "stdin", 5)) {
      /* stdin */
      pcap_handle = pcap_fopen_offline(stdin, pcap_error_buffer);
      pcap_datalink_type = pcap_datalink(pcap_handle);
      read_pkts_from_pcap_dump = false;
    } else if((pcap_handle = pcap_open_offline(ifname, pcap_error_buffer)) != NULL) {
      char *slash = strrchr(ifname, '/');

      if(slash) {
	char *old = ifname;
	ifname = strdup(&slash[1]);
	free(old);
      }

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from pcap file %s...", ifname);
      read_pkts_from_pcap_dump = true, purge_idle_flows_hosts = ntop->getPrefs()->purgeHostsFlowsOnPcapFiles();
      pcap_datalink_type = pcap_datalink(pcap_handle);
    } else {
      /* Trying to open a playlist */
      if((pcap_list = fopen(name, "r")) != NULL) {
	read_pkts_from_pcap_dump = true;
      }	else {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open file %s", name);
	exit(0);
      }
    }
  } else {
    pcap_handle = pcap_open_live(ifname, ntop->getGlobals()->getSnaplen(ifname),
				 ntop->getPrefs()->use_promiscuous(),
				 1000 /* 1 sec */, pcap_error_buffer);

    if(pcap_handle) {
      char *bl = strrchr(ifname,
#ifdef WIN32
			 '\\'
#else
			 '/'
#endif
			 );

      if(bl != NULL) {
	char *tmp = ifname;
	ifname = strdup(&bl[1]);
	free(tmp);
      }

      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from %s [id: %d]",
          ntop->getPrefs()->get_if_descr(ifIdx), ifIdx);
      read_pkts_from_pcap_dump = false;
      pcap_datalink_type = pcap_datalink(pcap_handle);

      Utils::readMac(ifname, ifMac);

#ifndef WIN32
      if(pcap_setdirection(pcap_handle, ntop->getPrefs()->getCaptureDirection()) != 0)
	ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set packet capture direction");

      if(Utils::readInterfaceStats(ifname, &prev_stats_in, &prev_stats_out))
	emulate_traffic_directions = true;
#endif
    } else
      throw errno;
  }

  if(read_pkts_from_pcap_dump) {
    /* Used to cleanup data during next ntopng startup */
    char id_str[8];
    snprintf(id_str, sizeof(id_str), "%d", get_id());

    ntop->getRedis()->hashSet(PCAP_DUMP_INTERFACES_DELETE_HASH, id_str, get_name());
  }

  if(ntop->getPrefs()->are_ixia_timestamps_enabled())
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Hardware timestamps are supported only on PF_RING capture interfaces");
}

/* **************************************************** */

PcapInterface::~PcapInterface() {
  if(pcap_handle) {
    pcap_close(pcap_handle);
    pcap_handle = NULL;
  }

  if(getIfType() == interface_type_PCAP_DUMP) {
    /* Cleanup any possible leftover file */
    cleanupPcapDumpDir();
  }
}

/* **************************************************** */

void PcapInterface::cleanupPcapDumpDir() {
  char base_dir[MAX_PATH];

  if(snprintf(base_dir, sizeof(base_dir), "%s/%d", ntop->get_working_dir(), get_id()) < (int)sizeof(base_dir)) {
    ntop->fixPath(base_dir);

    if(!ntop->getPrefs()->do_dump_flows_on_nindex()) {
      // Simple cleanup, remove everything
      Utils::remove_recursively(base_dir);
    } else {
      // Specific clenaup, avoid removing flows
      char sub_dir[MAX_PATH];
      DIR *d = opendir(base_dir);

      if(d) {
	while (1) {
	  struct dirent *entry;
	  const char *d_name;

	  entry = readdir(d);
	  if(!entry) break;

	  d_name = entry->d_name;

	  if((strcmp(d_name, "..") != 0) &&
	     (strcmp(d_name, ".") != 0) &&
	     (strcmp(d_name, "flows") != 0)) {
	    if(snprintf(sub_dir, sizeof(base_dir), "%s/%s", base_dir, d_name) < (int)sizeof(base_dir)) {
	      ntop->fixPath(sub_dir);
	      Utils::remove_recursively(sub_dir);
	    }
	  }
	}

	closedir(d);
      }
    }
  }
}

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  PcapInterface *iface = (PcapInterface*)ptr;
  pcap_t *pd;
  FILE *pcap_list = iface->get_pcap_list();
  struct timeval startTS, firstPktTS;
  int fd = -1;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

  /* Test Script (Pre Analysis) */ 
  if(ntop->getPrefs()->get_test_pre_script_path()) {
    const char *test_pre_script_path = ntop->getPrefs()->get_test_pre_script_path();

    /* Wait for the HTTP server to be able to serve requests
     * from the pre script, if any */
    while (!ntop->get_HTTPserver()->accepts_requests()
	   && !ntop->getGlobals()->isShutdown())
      sleep(1);

    /* Execute as Bash script */      
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Running Pre Script '%s'", test_pre_script_path);
    Utils::exec(test_pre_script_path);
  }

  do {
    if(pcap_list != NULL) {
      char path[256], *fname;
      pcap_t *pcap_handle;

      while((fname = fgets(path, sizeof(path), pcap_list)) != NULL) {
	char pcap_error_buffer[PCAP_ERRBUF_SIZE];
	int l = (int)strlen(path)-1;

	if((l <= 1) || (path[0] == '#')) continue;
	path[l--] = '\0';

	/* Remove trailer white spaces */
	while((l > 0) && (path[l] == ' ')) path[l--] = '\0';

	while(l > 0) {
	  if(!isascii(path[l--])) {
	    /* This looks like a bad file */
	    fname = NULL;
	    break;
	  }
	}

	if(fname != NULL) {
	  if((pcap_handle = pcap_open_offline(path, pcap_error_buffer)) == NULL) {
	    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open file '%s': %s",
					 path, pcap_error_buffer);
	  } else {
	    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from pcap file %s", path);
	    iface->set_pcap_handle(pcap_handle);
	    break;
	  }
	} else
	  break;
      }

      if(fname == NULL) {
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "No more pcap files to read");
	fclose(pcap_list);
	break;
      } else
	iface->set_datalink(pcap_datalink(pcap_handle));
    }

    pd = iface->get_pcap_handle();

#ifdef __linux__
    fd = pcap_get_selectable_fd(pd);
#endif

    firstPktTS.tv_sec = 0;

    while((pd != NULL)
	  && iface->isRunning()
	  && (!ntop->getGlobals()->isShutdown())) {
      const u_char *pkt;
      struct pcap_pkthdr *hdr;
      int rc;

      while(iface->idle()) { iface->purgeIdle(time(NULL)); sleep(1); }

      if(fd > 0) {
	fd_set rset;
	struct timeval tv;

	FD_ZERO(&rset);
	FD_SET(fd, &rset);

	tv.tv_sec = 1, tv.tv_usec = 0;
	if(select(fd + 1, &rset, NULL, NULL, &tv) == 0) {
	  iface->purgeIdle(time(NULL));
	  continue;
	}
      }
      
      if((rc = pcap_next_ex(pd, &hdr, &pkt)) > 0) {
	if(iface->reproducePcapOriginalSpeed()) {
	  struct timeval now;

	  gettimeofday(&now, NULL);

	  if(firstPktTS.tv_sec == 0) {
            startTS = now;
            firstPktTS = hdr->ts;
          } else {
            u_int32_t packetTimeDelta = Utils::msTimevalDiff(&hdr->ts, &firstPktTS);
            u_int32_t fromStartTimeDelta = Utils::msTimevalDiff(&now, &startTS);

            if (packetTimeDelta > fromStartTimeDelta) {
              u_int32_t sleepMs = packetTimeDelta - fromStartTimeDelta;

	      ntop->getTrace()->traceEvent(TRACE_DEBUG, "Sleeping %.3f sec", ((float)(sleepMs))/1000);

	      _usleep(sleepMs*1000);

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
	  iface->dissectPacket(DUMMY_BRIDGE_INTERFACE_ID,
			       true /* ingress - TODO: see if we pass the real packet direction */,
			       NULL, &hdr_copy, (const u_char*)pkt_copy, &p, &srcHost, &dstHost, &flow);
#else
	  hdr->caplen = min_val(hdr->caplen, iface->getMTU());
	  iface->dissectPacket(DUMMY_BRIDGE_INTERFACE_ID,
			       true /* ingress - TODO: see if we pass the real packet direction */,
			       NULL, hdr, pkt, &p, &srcHost, &dstHost, &flow);
#endif
	}
      } else if(rc < 0) {
	if(iface->read_from_pcap_dump())
	  break;
      } else {
	/* No packet received before the timeout */
	iface->purgeIdle(time(NULL));
      }
    } /* while */
  } while(pcap_list != NULL);

  /* Do two full scans to make sure all stats are updated */
  for(int i = 0; i < 2; i++)
    iface->purgeIdle(time(NULL), false, true /* Full scan */);
 
  if(iface->read_from_pcap_dump() && !iface->reproducePcapOriginalSpeed()) {
    iface->set_read_from_pcap_dump_done();
  }

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminated packet polling for %s",
			       iface->get_description());

  return(NULL);
}

/* **************************************************** */

void PcapInterface::startPacketPolling() {
  if(reproducePcapOriginalSpeed()) {
    /* Enable purge */
    purge_idle_flows_hosts = true;
  }

  pthread_create(&pollLoop, NULL, packetPollLoop, (void*)this);
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

u_int32_t PcapInterface::getNumDroppedPackets() {
#ifndef WIN32
  /* It seems this leads to crashes on Windows */
  struct pcap_stat pcapStat;

  if(pcap_handle && (pcap_stats(pcap_handle, &pcapStat) >= 0)) {
    return(pcapStat.ps_drop);
  } else
#endif
    return 0;
}

/* **************************************************** */

bool PcapInterface::set_packet_filter(char *filter) {
  struct bpf_program fcode;
  struct in_addr netmask;

  if(!pcap_handle) return(false);

  netmask.s_addr = htonl(0xFFFFFF00);

  if((pcap_compile(pcap_handle, &fcode, filter, 1, netmask.s_addr) < 0)
     || (pcap_setfilter(pcap_handle, &fcode) < 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set on %s filter %s. Filter ignored.", ifname, filter);
    return(false);
  } else {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Packet capture filter on %s set to \"%s\"", ifname, filter);
    /* can't get consistent stats while bpf is set */
    emulate_traffic_directions = false;
    return(true);
  }
};

/* **************************************************** */

/* Computes the counter delta handling wrapping on 32 bit platforms */
static u_int64_t getCounterInc(u_int64_t old_v, u_int64_t new_v) {
  /* Assume wrapping only occurs on 32 bit platforms (e.g. armv7l raspbian) */
  const u_int32_t max_val = (u_int32_t)-1;

  if(new_v >= old_v)
    return(new_v - old_v);
  else {
    /* Counter wrapped */
    if(max_val >= old_v)
      return((max_val - old_v) + new_v);
    else
      /* this should never occur */
      return(new_v);
  }
}

/* **************************************************** */

/* This method is only executed by the periodic script second.lua
 * Note: this is required as libpcap does not provide packets/bytes
 * statistics per direction. Make sure ethStats are not increased
 * by the packet processing function when this is in place. */
void PcapInterface::updateDirectionStats() {
  ProtoStats current_stats_in, current_stats_out;

  if(emulate_traffic_directions &&
     Utils::readInterfaceStats(ifname, &current_stats_in, &current_stats_out)) {
    pcap_direction_t capture_dir = ntop->getPrefs()->getCaptureDirection();

    /* grsec check, the new ntopng user may not able to read the stats anymore */
    if((prev_stats_in.getPkts() || prev_stats_out.getPkts()) &&
      !(current_stats_in.getPkts() || current_stats_out.getPkts())) {
      ntop->getTrace()->traceEvent(TRACE_WARNING, "Cannot read interface stats after user change (grsec kernel hardening in place?)");
      emulate_traffic_directions = false;
    } else {
      if((capture_dir == PCAP_D_INOUT) || (capture_dir == PCAP_D_IN)) {
	ethStats.incNumPackets(true, getCounterInc(prev_stats_in.getPkts(), current_stats_in.getPkts()));
	ethStats.incNumBytes(true, getCounterInc(prev_stats_in.getBytes(), current_stats_in.getBytes()));
      }

      if((capture_dir == PCAP_D_INOUT) || (capture_dir == PCAP_D_OUT)) {
	ethStats.incNumPackets(false, getCounterInc(prev_stats_out.getPkts(), current_stats_out.getPkts()));
	ethStats.incNumBytes(false, getCounterInc(prev_stats_out.getBytes(), current_stats_out.getBytes()));
      }

      prev_stats_in = current_stats_in;
      prev_stats_out = current_stats_out;
    }
  }
}

/* **************************************************** */

bool PcapInterface::reproducePcapOriginalSpeed() const {
  return(read_pkts_from_pcap_dump && ntop->getPrefs()->reproduceOriginalSpeed());
}

#endif

/*
 *
 * (C) 2013-18 - ntop.org
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

PcapInterface::PcapInterface(const char *name) : NetworkInterface(name) {
  char pcap_error_buffer[PCAP_ERRBUF_SIZE];
  struct stat buf;

  pcap_handle = NULL, pcap_list = NULL;
  memset(&last_pcap_stat, 0, sizeof(last_pcap_stat));
  
  if((stat(name, &buf) == 0) || (name[0] == '-') || !strncmp(name, "stdin", 5)) {
    /*
      The file exists so we need to check if it's a 
      text file or a pcap file
    */

    if(strcmp(name, "-") == 0 || !strncmp(name, "stdin", 5)) {
      /* stdin */
      pcap_handle = pcap_fopen_offline(stdin, pcap_error_buffer);
      pcap_datalink_type = DLT_EN10MB;
    } else if((pcap_handle = pcap_open_offline(ifname, pcap_error_buffer)) == NULL) {
      if((pcap_list = fopen(name, "r")) == NULL) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open file %s", name);
	exit(0);
      }	else
	read_pkts_from_pcap_dump = true;
    } else {
      char *slash = strrchr(ifname, '/');

      if(slash) {
	char *old = ifname;
	ifname = strdup(&slash[1]);
	free(old);
      }

      /* Re-reading prefs as name has changed */
      loadDumpPrefs();
      
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from pcap file %s...", ifname);
      read_pkts_from_pcap_dump = true, purge_idle_flows_hosts = false;      
      pcap_datalink_type = pcap_datalink(pcap_handle);
    }
  } else {
    pcap_handle = pcap_open_live(ifname, ntop->getGlobals()->getSnaplen(),
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
      
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from interface %s...", ifname);
      read_pkts_from_pcap_dump = false;
      pcap_datalink_type = pcap_datalink(pcap_handle);

#ifndef WIN32
      if(pcap_setdirection(pcap_handle, ntop->getPrefs()->getCaptureDirection()) != 0)
		ntop->getTrace()->traceEvent(TRACE_WARNING, "Unable to set packet capture direction");
#endif
    } else
      throw errno;
  }
  
  if(ntop->getPrefs()->are_ixia_timestamps_enabled())
    ntop->getTrace()->traceEvent(TRACE_WARNING, "Hardware timestamps are supported only on PF_RING capture interfaces");
}

/* **************************************************** */

PcapInterface::~PcapInterface() {
  shutdown();

  if(pcap_handle) {
    pcap_close(pcap_handle);
    pcap_handle = NULL;
  }
}

/* **************************************************** */

static void* packetPollLoop(void* ptr) {
  PcapInterface *iface = (PcapInterface*)ptr;
  pcap_t *pd;
  FILE *pcap_list = iface->get_pcap_list();
  int fd = -1;

  /* Wait until the initialization completes */
  while(!iface->isRunning()) sleep(1);

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

	if((pcap_handle = pcap_open_offline(path, pcap_error_buffer)) == NULL) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open file '%s': %s", 
				       path, pcap_error_buffer);
	} else {
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from pcap file %s", path);
	  iface->set_pcap_handle(pcap_handle);
	  break;
	}
      }

      if(fname == NULL) {
	ntop->getTrace()->traceEvent(TRACE_NORMAL, "No more pcap files to read");
	fclose(pcap_list);
	return(NULL);
      } else
	iface->set_datalink(pcap_datalink(pcap_handle));
    }

    pd = iface->get_pcap_handle();

#ifdef __linux__
    fd = pcap_get_selectable_fd(pd);
#endif

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

  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Terminated packet polling for %s", iface->get_name());

  if(ntop->getPrefs()->shutdownWhenDone())
    ntop->getGlobals()->shutdown();

  return(NULL);
}

/* **************************************************** */

void PcapInterface::startPacketPolling() { 
  pthread_create(&pollLoop, NULL, packetPollLoop, (void*)this);  
  pollLoopCreated = true;
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

void PcapInterface::shutdown() {
  if(running) {
    void *res;

    NetworkInterface::shutdown();
#ifndef WIN32
    pthread_kill(pollLoop, SIGTERM);
#endif
    pthread_join(pollLoop, &res);
  }
}

/* **************************************************** */

u_int32_t PcapInterface::getNumDroppedPackets() {
  struct pcap_stat pcapStat;

  if(pcap_handle && (pcap_stats(pcap_handle, &pcapStat) >= 0)) {
    return(pcapStat.ps_drop);
  } else
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
    return(true);
  }
};

#endif

/*
 *
 * (C) 2013-15 - ntop.org
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

/* **************************************************** */

PcapInterface::PcapInterface(const char *name) : NetworkInterface(name) {
  char pcap_error_buffer[PCAP_ERRBUF_SIZE];
  struct stat buf;

  pcap_handle = NULL, pcap_list = NULL;

  if(stat(name, &buf) == 0) {
    /*
      The file exists so we need to check if it's a 
      text file or a pcap file
    */

    if((pcap_handle = pcap_open_offline(ifname, pcap_error_buffer)) == NULL) {
      if((pcap_list = fopen(name, "r")) == NULL) {
	ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open file %s", name);
	_exit(0);
      } else
	read_pkts_from_pcap_dump = true;
    } else {
      char *slash = strrchr(ifname, '/');

      if(slash) {
	char *old = ifname;
	ifname = strdup(&slash[1]);
	free(old);
      }
      
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packets from pcap file %s...", ifname);
      read_pkts_from_pcap_dump = true, purge_idle_flows_hosts = false;      
      pcap_datalink_type = pcap_datalink(pcap_handle);
    }
  } else {
    pcap_handle = pcap_open_live(ifname, ntop->getGlobals()->getSnaplen(),
				 ntop->getPrefs()->use_promiscuous(),
				 500, pcap_error_buffer);  

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
    }
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
  pcap_t  *pd;
  FILE *pcap_list = iface->get_pcap_list();

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
	  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Reading packes from pcap file %s", path);
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
    
    while((pd != NULL) 
	  && iface->isRunning() 
	  && (!ntop->getGlobals()->isShutdown())) {
      const u_char *pkt;
      struct pcap_pkthdr hdr;

      while(iface->idle()) { iface->purgeIdle(time(NULL)); sleep(1); }

      if((pkt = pcap_next(pd, &hdr)) != NULL) {
	if((hdr.caplen > 0) && (hdr.len > 0)) {
	  int egress_shaper_id;
	  iface->packet_dissector(&hdr, pkt, &egress_shaper_id);
	}
      } else {
	if(iface->read_from_pcap_dump())
	  break;

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
  NetworkInterface::startPacketPolling();
}

/* **************************************************** */

void PcapInterface::shutdown() {
  if(running) {
    void *res;

    NetworkInterface::shutdown();
    if(pcap_handle) pcap_breakloop(pcap_handle);
    pthread_join(pollLoop, &res);
  }
}

/* **************************************************** */

u_int PcapInterface::getNumDroppedPackets() {
  struct pcap_stat pcapStat;

  if(pcap_handle && (pcap_stats(pcap_handle, &pcapStat) >= 0)) {
    return(pcapStat.ps_drop);
  } else
    return(0);
}

/* **************************************************** */

bool PcapInterface::set_packet_filter(char *filter) {
  struct bpf_program fcode;
  struct in_addr netmask;

  if(!pcap_handle) return(false);

  netmask.s_addr = htonl(0xFFFFFF00);

  if((pcap_compile(pcap_handle, &fcode, filter, 1, netmask.s_addr) < 0)
     || (pcap_setfilter(pcap_handle, &fcode) < 0)) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to set filter %s. Filter ignored.\n", filter);
    return(false);
  } else {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "Packet capture filter set to \"%s\"", filter);
    return(true);
  }
};

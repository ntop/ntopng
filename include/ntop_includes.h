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

#ifndef _NTOP_H_
#define _NTOP_H_

#include "config.h"

#ifdef __FreeBSD
#define _XOPEN_SOURCE
#endif

#include <stdio.h>
#include <stdarg.h>

#ifdef WIN32
#include "ntop_win32.h"
#else
#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <pthread.h>
#include <sys/wait.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <poll.h>

#if defined(__OpenBSD__)
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <net/if.h>
#include <net/if_arp.h>
#include <netinet/if_ether.h>
#include <netinet/in_systm.h>
#else
#include <net/ethernet.h>
#endif

#include <netinet/ip.h>
#include <netinet/ip6.h>
#include <netinet/tcp.h>
#include <netinet/udp.h>
#include <netinet/ip_icmp.h>
#include <unistd.h>
#include <netdb.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <syslog.h>
#include <netdb.h>
#include <dirent.h>
#include <pwd.h>
#endif

#ifdef linux
#define __FAVOR_BSD
#endif

#include <stdlib.h>
#include <errno.h>
#include <signal.h>
#include <ctype.h>
#include <fcntl.h>
#include <getopt.h>
#include <string.h>
#include <math.h>
#include <sys/stat.h>
#include <zmq.h>
#include <assert.h>
#ifdef linux
#include <linux/ethtool.h> // ethtool
#include <linux/sockios.h> // sockios
#endif

#ifdef __APPLE__
#include <uuid/uuid.h>
#endif

extern "C" {
#include "pcap.h"
#include "ndpi_main.h"
#include "luajit.h"
#include "lauxlib.h"
#include "lualib.h"
#ifdef HAVE_PF_RING
#include "pfring.h"
#include "pfring_zc.h"
#endif
#ifdef HAVE_NETFILTER
#include <linux/types.h>
#include <linux/netfilter.h> /* for NF_ACCEPT */
#include <libnfnetlink/libnfnetlink.h>
#include <libnetfilter_queue/libnetfilter_queue.h>
#endif
#include "json.h"
#include <sqlite3.h>
#include "hiredis.h"
};

#include <mysql.h>
#include <errmsg.h>

#include <fstream>
#include <map>
#include <vector>
#include <list>
#include <iostream>
#include <string>
#include <sstream>

using namespace std;

#include "mongoose.h"
#include "ntop_defines.h"
#include "ntop_typedefs.h"
#include "patricia.h"
#include "Trace.h"
#include "NtopGlobals.h"
#ifdef NTOPNG_PRO
#include "CountMinSketch.h"
#include "Profile.h"
#include "Profiles.h"
#endif
#include "Prefs.h"
#include "Mutex.h"
#include "IpAddress.h"
#include "Utils.h"
#include "ActivityStats.h"
#include "nDPIStats.h"
#include "DnsStats.h"
#include "TrafficStats.h"
#include "PacketStats.h"
#include "ProtoStats.h"
#include "EthStats.h"
#include "LocalTrafficStats.h"
#include "PacketDumperGeneric.h"
#include "PacketDumper.h"
#include "PacketDumperTuntap.h"
#include "GenericHashEntry.h"
#include "AlertCounter.h"
#include "GenericHost.h"
#include "GenericHash.h"
#include "VirtualHost.h"
#include "VirtualHostHash.h"
#include "HTTPStats.h"
#include "Redis.h"
#include "StatsManager.h"
#include "FlowsManager.h"
#include "DB.h"
#include "MySQLDB.h"
#include "NetworkInterfaceView.h"
#include "NetworkInterface.h"
#include "PcapInterface.h"
#ifdef HAVE_PF_RING
#include "PF_RINGInterface.h"
#endif
#ifdef HAVE_NETFILTER
#include "NetfilterInterface.h"
#endif
#ifdef NTOPNG_PRO
#include "NtopPro.h"
#include "PacketBridge.h"
#include "TrafficShaper.h"
#include "L7Policer.h"
#include "LuaHandler.h"
#include "NagiosManager.h"
#include "FlowChecker.h"
#endif
#include "ParserInterface.h"
#include "CollectorInterface.h"
#include "ExportInterface.h"
#include "Geolocation.h"
#include "GenericHost.h"
#include "Host.h"
#include "Flow.h"
#include "FlowHash.h"
#include "HostHash.h"
#include "PeriodicActivities.h"
#include "Lua.h"
#include "AddressTree.h"
#include "AddressResolution.h"
#include "Categorization.h"
#include "HTTPBL.h"
#include "HTTPserver.h"
#include "RuntimePrefs.h"
#include "Ntop.h"


#ifdef WIN32
extern "C" {
  const char *strcasestr(const char *haystack, const char *needle);
  int strncasecmp(const char *s1, const char *s2, unsigned int n);
};
#endif


#endif /* _NTOP_H_ */

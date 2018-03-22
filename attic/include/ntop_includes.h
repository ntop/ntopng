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

#ifndef _NTOP_H_
#define _NTOP_H_

#include "config.h"

#if defined (__FreeBSD) || defined(__FreeBSD__)
#define _XOPEN_SOURCE
#define _WITH_GETLINE
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
#if defined(linux)
#include <linux/ethtool.h> // ethtool
#include <linux/sockios.h> // sockios
#elif defined(__FreeBSD__)
#include <net/if_dl.h>
#include <ifaddrs.h>
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
#ifdef HAVE_LDAP
#include <ldap.h>
#endif
#ifdef HAVE_ZLIB
#include <zlib.h>
#endif

#include "third-party/uthash.h"
#include <mysql.h>
#include <errmsg.h>
};

#include <fstream>
#include <map>
#include <vector>
#include <list>
#include <iostream>
#include <string>
#include <sstream>

using namespace std;

#include "mongoose.h"
#include "patricia.h"
#include "ntop_defines.h"
#include "AddressTree.h"
#include "AddressList.h"
#include "IpAddress.h"
#include "ntop_typedefs.h"
#include "Trace.h"
#include "NtopGlobals.h"
#include "Profile.h"
#include "Profiles.h"
#include "TrafficStats.h"
#include "nDPIStats.h"
#include "GenericTrafficElement.h"
#ifdef NTOPNG_PRO
#include "CountMinSketch.h"
#include "FlowProfile.h"
#include "FlowProfiles.h"
#include "CounterTrend.h"
#include "LRUMacIP.h"
#include "FlowInterfacesStats.h"
#include "HostPoolStats.h"
#ifdef HAVE_LDAP
#include "LdapAuthenticator.h"
#endif
#ifdef HAVE_KAFKA
#include "KafkaManager.h"
#endif
#endif
#include "FrequentStringItems.h"
#include "FrequentNumericItems.h"
#include "HostPools.h"
#include "Prefs.h"
#include "Mutex.h"
#include "Utils.h"
#include "ActivityStats.h"
#include "DnsStats.h"
#include "NetworkStats.h"
#include "ICMPstats.h"
#include "Grouper.h"
#include "PacketStats.h"
#include "ProtoStats.h"
#include "TcpPacketStats.h"
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
#include "HTTPstats.h"
#include "Redis.h"
#include "ElasticSearch.h"
#include "Logstash.h"
#include "StoreManager.h"
#include "StatsManager.h"
#include "AlertsManager.h"
#include "DB.h"
#include "MySQLDB.h"
#include "TcpFlowStats.h"
#include "InterfaceStatsHash.h"
#include "NetworkInterface.h"
#include "PcapInterface.h"
#include "ViewInterface.h"
#ifdef HAVE_PF_RING
#include "PF_RINGInterface.h"
#endif
#ifdef NTOPNG_PRO
#include "NtopPro.h"
#ifndef WIN32
#include "PacketBridge.h"
#endif
#include "TrafficShaper.h"
#include "L7Policer.h"
#include "BatchedMySQLDB.h"
#include "BatchedMySQLDBEntry.h"
#include "SPSCQueue.h"
#include "LuaHandler.h"
#ifndef WIN32
#include "NagiosManager.h"
#endif
#include "FlowChecker.h"
#include "FrequentStringItems.h"
#include "FrequentNumericItems.h"
#ifdef HAVE_NETFILTER
#include "NetfilterInterface.h"
#endif
#endif
#if defined(__FreeBSD__) || defined(__NetBSD__) || defined(__OpenBSD__) || defined(__APPLE__)
#include "DivertInterface.h"
#endif
#include "ParserInterface.h"
#include "CollectorInterface.h"
#include "ZCCollectorInterface.h"
#include "DummyInterface.h"
#include "ExportInterface.h"
#include "Geolocation.h"
#include "Flashstart.h"
#include "GenericHost.h"
#include "CategoryStats.h"
#include "Vlan.h"
#include "AutonomousSystem.h"
#include "Mac.h"
#include "Host.h"
#include "Flow.h"
#include "FlowHash.h"
#include "MacHash.h"
#include "VlanHash.h"
#include "AutonomousSystemHash.h"
#include "HostHash.h"
#ifdef NTOPNG_PRO
#include "AggregatedFlow.h"
#include "AggregatedFlowHash.h"
#endif
#include "PeriodicActivities.h"
#include "Lua.h"
#include "MacManufacturers.h"
#include "AddressResolution.h"
#include "HTTPBL.h"
#include "HTTPserver.h"
#include "RuntimePrefs.h"
#include "Paginator.h"
#include "Ntop.h"


#ifdef WIN32
extern "C" {
  const char *strcasestr(const char *haystack, const char *needle);
  int strncasecmp(const char *s1, const char *s2, unsigned int n);
};
#endif


#endif /* _NTOP_H_ */

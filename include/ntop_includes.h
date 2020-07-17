/*
 *
 * (C) 2013-20 - ntop.org
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
#include <netinet/icmp6.h>
#include <unistd.h>
#include <netdb.h>
#include <sys/ioctl.h>
#include <net/if.h>
#include <syslog.h>
#include <netdb.h>
#include <dirent.h>
#include <pwd.h>
#include <sys/select.h>
#endif

#ifdef __linux__
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
#include <fcntl.h>
#ifndef WIN32
#include <grp.h>
#endif
#ifdef HAVE_TEST_MODE
#include <libgen.h>
#endif
#if defined(linux)
#include <linux/ethtool.h> // ethtool
#include <linux/sockios.h> // sockios
#include <ifaddrs.h>
#elif defined(__FreeBSD__) || defined(__APPLE__)
#include <net/if_dl.h>
#include <ifaddrs.h>
#endif
#ifdef __APPLE__
#include <uuid/uuid.h>
#endif

extern "C" {
#include "pcap.h"

#ifndef __linux__
#include <pcap/bpf.h> /* Used for bpf_filter() */
#endif

#include "ndpi_api.h"
#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#ifdef HAVE_PF_RING
#include "pfring.h"
#include "pfring_zc.h"
#endif
#ifdef HAVE_NEDGE
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

#ifdef WIN32
/* 
See
https://translate.google.co.uk/translate?sl=auto&tl=en&u=http%3A%2F%2Fbugsfixed.blogspot.com%2F2017%2F05%2Fvcpkg.html
*/
#define CURL_STATICLIB
#endif
#include <curl/curl.h>

#ifdef WIN32
#pragma comment(lib, "crypt32.lib")
#pragma comment(lib, "wldap32.lib") 
#endif

#include "third-party/uthash.h"

#ifdef HAVE_MYSQL
#include <mysql.h>
#include <errmsg.h>
#endif

#ifdef HAVE_MAXMINDDB
#include <maxminddb.h>
#endif

#ifdef HAVE_LIBCAP
#include <sys/capability.h>
#include <sys/prctl.h>
#endif
};

#include <fstream>
#include <map>
#include <set>
#include <algorithm>
#include <vector>
#include <list>
#include <iostream>
#include <string>
#include <sstream>
#include <queue>
#include <typeinfo>

using namespace std;

#include "mongoose.h"
#include "patricia.h"
#include "ntop_defines.h"
#include "Mutex.h"
#include "RwLock.h"
#include "Bitmask.h"
#include "Bloom.h"
#include "MonitoredMetric.h"
#include "MonitoredCounter.h"
#include "MonitoredGauge.h"
#include "MDNS.h"
#include "AddressTree.h"
#include "VlanAddressTree.h"
#include "AddressList.h"
#include "BroadcastDomains.h"
#include "Cardinality.h"
#include "IpAddress.h"
#include "Ping.h"
#include "ContinuousPingStats.h"
#include "ContinuousPing.h"
#include "TrafficStats.h"
#include "TcpPacketStats.h"
#include "DSCPStats.h"
#include "ntop_typedefs.h"
#include "Alert.h"
#include "AlertableEntity.h"
#include "Trace.h"
#include "ProtoStats.h"
#include "Utils.h"
#include "Bitmap.h"
#include "NtopGlobals.h"
#include "nDPIStats.h"
#include "InterarrivalStats.h"
#include "FlowStats.h"
#ifdef NTOPNG_PRO
#include "CustomAppMaps.h"
#include "CustomAppStats.h"
#endif
#include "ThroughputStats.h"
#include "GenericTrafficElement.h"
#include "AlertCounter.h"
#include "NetworkStats.h"
#include "ContainerStats.h"
#include "ParsedFlowCore.h"
#include "ParsedeBPF.h"
#include "ParsedFlow.h"
#ifdef HAVE_EBPF
#include "ebpf_flow.h"
#endif

#ifdef NTOPNG_PRO
#include "Profile.h"
#include "Profiles.h"
#include "CountMinSketch.h"
#ifndef HAVE_NEDGE
#include "FlowProfile.h"
#include "FlowProfiles.h"
#include "SubInterface.h"
#include "SubInterfaces.h"
#endif
#include "CounterTrend.h"
#include "LRUMacIP.h"
#include "FlowInterfacesStats.h"
#ifdef HAVE_LDAP
#include "LdapAuthenticator.h"
#endif
#endif
#include "FrequentStringItems.h"
#include "FrequentNumericItems.h"
#include "FrequentTrafficItems.h"
#include "HostPoolStats.h"
#include "HostPools.h"
#include "Fingerprint.h"
#include "Prefs.h"
#include "SerializableElement.h"
#include "DnsStats.h"
#ifndef HAVE_NEDGE
#include "SNMP.h"
#endif
#include "NetworkDiscovery.h"
#include "ICMPstats.h"
#include "ICMPinfo.h"
#include "Grouper.h"
#include "FlowGrouper.h"
#include "PacketStats.h"
#include "EthStats.h"

#include "LocalTrafficStats.h"
#include "PacketDumperGeneric.h"
#include "PacketDumper.h"
#include "PacketDumperTuntap.h"
#include "TimelineExtract.h"
#include "TcpFlowStats.h"
#include "StoreManager.h"
#include "StatsManager.h"
#include "AlertsManager.h"
#include "DB.h"
#ifdef HAVE_MYSQL
#include "MySQLDB.h"
#endif
#include "InterfaceStatsHash.h"
#include "GenericHash.h"
#include "GenericHashEntry.h"
#if defined(NTOPNG_PRO) && defined(HAVE_NINDEX)
#include "nindex_api.h"
#endif
#ifdef HAVE_RADIUS
#include <radcli/radcli.h>
#endif

#include "FifoQueue.h"
#include "FifoStringsQueue.h"
#include "FifoSerializerQueue.h"
#include "SPSCQueue.h"
#include "TimeseriesExporter.h"
#include "InfluxDBTimeseriesExporter.h"
#include "RRDTimeseriesExporter.h"
#include "L4Stats.h"
#include "AlertsQueue.h"
#include "LuaEngine.h"
#include "LuaReusableEngine.h"
#include "AlertCheckLuaEngine.h"
#include "FlowAlertCheckLuaEngine.h"
#include "SyslogLuaEngine.h"
#ifdef NTOPNG_PRO
#include "PeriodicityStats.h"
#include "PeriodicityHash.h"
#endif
#include "NetworkInterface.h"
#ifndef HAVE_NEDGE
#include "PcapInterface.h"
#endif
#include "ViewInterface.h"
#ifdef HAVE_PF_RING
#include "PF_RINGInterface.h"
#endif
#include "FlowAlertCounter.h"
#include "VirtualHost.h"
#include "VirtualHostHash.h"
#include "HTTPstats.h"
#include "Redis.h"
#ifndef HAVE_NEDGE
#include "ElasticSearch.h"
#include "Logstash.h"
#endif
#ifdef HAVE_NINDEX
#include "TextDump.h"
#include "NIndexFlowDB.h"
#endif
#ifdef NTOPNG_PRO
#include "NtopPro.h"
#include "DnsHostMapping.h"
#include "TrafficShaper.h"
#include "L7Policer.h"
#ifdef HAVE_MYSQL
#include "BatchedMySQLDB.h"
#include "BatchedMySQLDBEntry.h"
#endif
#include "LuaHandler.h"
#ifndef WIN32
#include "NagiosManager.h"
#endif
#include "FrequentStringItems.h"
#include "FrequentNumericItems.h"
#include "FrequentTrafficItems.h"
#ifdef HAVE_NEDGE
#include "NetfilterInterface.h"
#endif
#endif
#ifndef HAVE_NEDGE
#include "ParserInterface.h"
#include "ZMQParserInterface.h"
#include "ZMQCollectorInterface.h"
#include "SyslogParserInterface.h"
#include "SyslogCollectorInterface.h"
#include "ZCCollectorInterface.h"
#include "DummyInterface.h"
#include "ExportInterface.h"
#endif

#include "Geolocation.h"
#include "Vlan.h"
#include "AutonomousSystem.h"
#include "Country.h"
#include "MacStats.h"
#include "Mac.h"
#include "PartializableFlowTrafficStats.h"
#include "ViewInterfaceFlowStats.h"
#include "FlowTrafficStats.h"
#include "HostStats.h"
#include "LocalHostStats.h"
#include "HostScore.h"
#ifdef NTOPNG_PRO
#include "L7ProtoBehaviourAnalysis.h"
#include "HostBehaviourAnalysis.h"
#endif
#include "Host.h"
#include "LocalHost.h"
#include "RemoteHost.h"
#include "Flow.h"
#include "FlowHash.h"
#include "MacHash.h"
#include "VlanHash.h"
#include "AutonomousSystemHash.h"
#include "CountriesHash.h"
#include "HostHash.h"
#include "ThreadedActivityStats.h"
#include "ThreadedActivity.h"
#include "ThreadPool.h"
#include "PeriodicActivities.h"
#include "MacManufacturers.h"
#include "AddressResolution.h"
#include "HTTPserver.h"
#include "Paginator.h"
#include "Ntop.h"

#ifdef NTOPNG_PRO
#include "ntoppro_defines.h"
#endif

#endif /* _NTOP_H_ */

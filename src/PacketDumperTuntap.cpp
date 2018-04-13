/*
 *
 * (C) 2015-18 - ntop.org
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
#ifdef __linux__
#include <linux/if_tun.h>
#endif
#ifndef WIN32
#include <unistd.h>
#endif

/* ********************************************* */

PacketDumperTuntap::PacketDumperTuntap(NetworkInterface *i) {
  char *name = i->get_name();

  int ret = openTap(NULL, DUMP_MTU);
  if(ret < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Opening tap (%s) failed", name);
    init_ok = false;
  } else {
    ntop->getTrace()->traceEvent(TRACE_NORMAL, "%s: dumping packets on tap interface %s", 
				 name, dev_name);
    init_ok = true;
    num_dumped_packets = 0;
  }
}

/* ********************************************* */

PacketDumperTuntap::~PacketDumperTuntap() {
  closeTap();
}

/* ********************************************* */

#ifdef __linux__
#define LINUX_SYSTEMCMD_SIZE 128

int PacketDumperTuntap::openTap(char *dev, /* user-definable interface name, eg. edge0 */ int mtu) {
  char *tuntap_device = strdup("/dev/net/tun");
  char buf[LINUX_SYSTEMCMD_SIZE];
  struct ifreq ifr;
  int rc;

  fd = open(tuntap_device, O_RDWR);
  if(fd < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Error while opening %s [%d/%s]\n",
				 tuntap_device, errno, strerror(errno));
    free(tuntap_device);
    return -1;
  }
  memset(&ifr, 0, sizeof(ifr));
  ifr.ifr_flags = IFF_TAP|IFF_NO_PI; /* Want a TAP device for layer 2 frames. */
  if(dev)
    strncpy(ifr.ifr_name, dev, IFNAMSIZ);

  rc = ioctl(fd, TUNSETIFF, (void *)&ifr);
  if(rc < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "ioctl(%s) [%d/%s]\n",
				 tuntap_device, errno, strerror(errno));
    free(tuntap_device);
    close(fd);
    return -1;
  }

  /* Store the device name for later reuse */
  strncpy(dev_name, ifr.ifr_name,
          (IFNAMSIZ < DUMP_IFNAMSIZ ? IFNAMSIZ : DUMP_IFNAMSIZ) );
  snprintf(buf, sizeof(buf), "/sbin/ifconfig %s up mtu %d",
           ifr.ifr_name, DUMP_MTU);
  rc = system(buf);

  ntop->getTrace()->traceEvent(TRACE_INFO, "Bringing up: %s [%d]", buf,rc);
  Utils::readMac(dev_name, mac_addr);
  free(tuntap_device);
  return(fd);
}
#endif

/* ********************************************* */

#ifdef __FreeBSD__
#define FREEBSD_TAPDEVICE_SIZE 32
int PacketDumperTuntap::openTap(char *dev, /* user-definable interface name, eg. edge0 */ int mtu) {
  int i;
  char tap_device[FREEBSD_TAPDEVICE_SIZE];

  for (i = 0; i < 255; i++) {
    snprintf(tap_device, sizeof(tap_device), "/dev/tap%d", i);
    fd = open(tap_device, O_RDWR);
    if(fd > 0) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Successfully open %s", tap_device);
      snprintf(dev_name, sizeof(dev_name), "%s", tap_device); 
      break;
    }
  }

  if(fd < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open tap device");
    return(-1);
  }

  up();
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Interface tap%d up and running", i);
  return(fd);
}
#endif

/* ********************************************* */

#ifdef __OpenBSD__
#define OPENBSD_TAPDEVICE_SIZE 32
int PacketDumperTuntap::openTap(char *dev, /* user-definable interface name, eg. edge0 */ int mtu) {
  int i;
  char tap_device[OPENBSD_TAPDEVICE_SIZE];

  for (i = 0; i < 255; i++) {
    snprintf(tap_device, sizeof(tap_device), "/dev/tap%d", i);
    fd = open(tap_device, O_RDWR);
    if(fd > 0) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Successfully open %s", tap_device);
      snprintf(dev_name, sizeof(dev_name), "%s", tap_device);
      break;
    }
  }

  if(fd < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open tap device");
    return(-1);
  }

  up();
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Interface tap%d up and running", i);
  return(fd);
}
#endif

/* ********************************************* */

#ifdef WIN32
int PacketDumperTuntap::openTap(char *dev, /* user-definable interface name, eg. edge0 */ int mtu) {
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "TAP interface not yet supported on windows");
  return(-1);
}
#endif
	
/* ********************************************* */

#ifndef WIN32
void PacketDumperTuntap::up() {
  int sockfd;
  struct ifreq ifr;
  
  sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  
  if(sockfd < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open socket");
    return;
  }

  memset(&ifr, 0, sizeof ifr);

  strncpy(ifr.ifr_name, dev_name, IFNAMSIZ);

  ifr.ifr_flags |= IFF_UP;
  if(ioctl(sockfd, SIOCSIFFLAGS, &ifr) < 0)
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Error while enabling %s interface [%d/%s]", 
				 ifr.ifr_name, errno, strerror(errno));
  closesocket(sockfd);
}
#endif

/* ********************************************* */

#ifdef __APPLE__
#define OSX_TAPDEVICE_SIZE 32

int PacketDumperTuntap::openTap(char *dev, /* user-definable interface name, eg. edge0 */ int mtu) {
  int i;
  char tap_device[OSX_TAPDEVICE_SIZE];

  for (i = 0; i < 255; i++) {
    snprintf(tap_device, sizeof(tap_device), "/dev/tap%d", i);
    fd = open(tap_device, O_RDWR);
    if(fd > 0) {
      ntop->getTrace()->traceEvent(TRACE_NORMAL, "Successfully open %s", 
				   tap_device);
      snprintf(dev_name, sizeof(dev_name), "%s", tap_device);
      break;
    }
  }

  if(fd < 0) {
    ntop->getTrace()->traceEvent(TRACE_ERROR, "Unable to open tap device");
    return -1;
  }
  
  up();
  ntop->getTrace()->traceEvent(TRACE_NORMAL, "Interface tap%d up and running", i);
  return(fd);
}
#endif

/* ********************************************* */

#ifdef NOTUSED
int PacketDumperTuntap::readTap(unsigned char *buf, int len) {
  if(init_ok)
    return(read(fd, buf, len));
  return 0;
}
#endif

/* ********************************************* */

int PacketDumperTuntap::writeTap(unsigned char *buf, int len,
                                 dump_reason reason, unsigned int sampling_rate) {
  int rc = 0;
  
  if(init_ok) {
    int rate_dump_ok = reason != ATTACK || num_dumped_packets % sampling_rate == 0;
    if(rate_dump_ok) {
      num_dumped_packets++;
      rc = write(fd, buf, len);

      if(rc < 0) {
	static bool shown = false;

	if(!shown) {
	  ntop->getTrace()->traceEvent(TRACE_ERROR, "Error while dumping to tap %s [%d/%s] failed", 
				       dev_name, errno, strerror(errno));	  
#ifdef __APPLE__
	  ntop->getTrace()->traceEvent(TRACE_ERROR, 
				       "Please do 'ipconfig set %s dhcp' and it will work", 
				       &dev_name[5]);
#endif
	  shown = true;
	}
      }
    }
  }

  return(rc);
}

/* ********************************************* */

void PacketDumperTuntap::closeTap() {
  if(init_ok)
    close(fd);
}

/* ********************************************* */

void PacketDumperTuntap::lua(lua_State *vm) {
  lua_newtable(vm);
  lua_push_int_table_entry(vm, "num_dumped_pkts", get_num_dumped_packets());

  lua_pushstring(vm, "pkt_dumper_tuntap");
  lua_insert(vm, -2);
  lua_settable(vm, -3);
}

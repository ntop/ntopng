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

#ifndef _PACKET_DUMPER_TUNTAP_H_
#define _PACKET_DUMPER_TUNTAP_H_

#include "ntop_includes.h"


class PacketDumperTuntap {
 private:
  NetworkInterface *iface;
  int           fd;
  uint8_t       mac_addr[6];
  uint16_t      mtu;
  char          dev_name[DUMP_IFNAMSIZ];
  bool		init_ok;
  u_int32_t     num_dumped_packets;

  int getIPAddress(struct ifreq *ifr, char *if_name);
  int getNetmask(struct ifreq *ifr, char *if_name);
  int getHwAddress(struct ifreq *ifr, char *if_name);
  void up();

 public:
  PacketDumperTuntap(NetworkInterface *i);
  ~PacketDumperTuntap();

  int openTap(char *dev, /* user-definable interface name, eg. edge0 */
		int mtu);
  int readTap(unsigned char *buf, int len);
  int writeTap(unsigned char *buf, int len, dump_reason reason,
               unsigned int sampling_rate);
  inline char *getName(void) { return((char*)dev_name); }
  void closeTap();

  u_int32_t get_num_dumped_packets(void) { return num_dumped_packets; }

  void lua(lua_State *vm);
};

#endif /* _PACKET_DUMPER_TUNTAP_H_ */

#! /usr/bin/python
"""
This is a reference implementation of community ID hashes on network
flows. Pass any pcaps (not pcapng) to the script and it will report
the following for each packet in the traces, separated by "|":

- the timestamp
- the community ID
- a flow tuple summary

Currently supported protocols include IP, IPv6, ICMP, ICMPv6, TCP,
UDP, SCTP.

Please note: the protocol parsing implemented in this script relies
on the dpkt module and is somewhat simplistic:

- dpkt seems to struggle with some SCTP packets, for which it fails
  to register SCTP even though its header is correctly present.

- The script doesn't try to get nested network layers (IP over IPv6,
  IP in IP, etc) right. It expects either IP or IPv6, and it expects
  a transport-layer protocol (including the ICMPs here) as the
  immediate next layer.
"""
import argparse
import base64
import hashlib
import socket
import struct
import sys

try:
    import dpkt
except ImportError:
    print('This needs the dpkt Python module')
    sys.exit(1)

from dpkt.ethernet import Ethernet #pylint: disable=import-error
from dpkt.ip import IP #pylint: disable=import-error
from dpkt.ip6 import IP6 #pylint: disable=import-error
from dpkt.icmp import ICMP #pylint: disable=import-error
from dpkt.icmp6 import ICMP6 #pylint: disable=import-error
from dpkt.tcp import TCP #pylint: disable=import-error
from dpkt.udp import UDP #pylint: disable=import-error
from dpkt.sctp import SCTP #pylint: disable=import-error

TRANSPORT_PROTOS = [ICMP, ICMP6, TCP, UDP, SCTP]

# ---- Code ------------------------------------------------------------

class ICMPHelper(object):
    """
    Helper class for ICMP-related port mappings.
    """
    @staticmethod
    def packet_get_v4_port_equivalents(pkt):
        """
        This function takes the type (and code) of an ICMP packet and
        derives transport layer port-pair equivalents. See the
        analyzer::icmp::ICMP4_counterpart() function (and its IPv6
        equivalent) in the Bro source tree (ICMP.cc) for additional
        detail.

        Returns a triplet of (source port, dest port, is_one_way).
        """
        mapper = {
            dpkt.icmp.ICMP_ECHO:            dpkt.icmp.ICMP_ECHOREPLY,
            dpkt.icmp.ICMP_ECHOREPLY:       dpkt.icmp.ICMP_ECHO,
            dpkt.icmp.ICMP_TSTAMP:          dpkt.icmp.ICMP_TSTAMPREPLY,
            dpkt.icmp.ICMP_TSTAMPREPLY:     dpkt.icmp.ICMP_TSTAMP,
            dpkt.icmp.ICMP_INFO:            dpkt.icmp.ICMP_INFOREPLY,
            dpkt.icmp.ICMP_INFOREPLY:       dpkt.icmp.ICMP_INFO,
            dpkt.icmp.ICMP_RTRSOLICIT:      dpkt.icmp.ICMP_RTRADVERT,
            dpkt.icmp.ICMP_MASK:            dpkt.icmp.ICMP_MASKREPLY,
            dpkt.icmp.ICMP_MASKREPLY:       dpkt.icmp.ICMP_MASK,
        }
        try:
            return pkt[ICMP].type, mapper[pkt[ICMP].type], False
        except KeyError:
            return pkt[ICMP].type, pkt[ICMP].code, True

    @staticmethod
    def packet_get_v6_port_equivalents(pkt):
        """
        This is the same as packet_get_v4_port_equivalents, but for ICMPv6.
        """
        mapper = {
            dpkt.icmp6.ICMP6_ECHO_REQUEST:  dpkt.icmp6.ICMP6_ECHO_REPLY,
            dpkt.icmp6.ICMP6_ECHO_REPLY:    dpkt.icmp6.ICMP6_ECHO_REQUEST,

            dpkt.icmp6.ND_ROUTER_SOLICIT:   dpkt.icmp6.ND_ROUTER_ADVERT,
            dpkt.icmp6.ND_ROUTER_ADVERT:    dpkt.icmp6.ND_ROUTER_SOLICIT,

            dpkt.icmp6.ND_NEIGHBOR_SOLICIT: dpkt.icmp6.ND_NEIGHBOR_ADVERT,
            dpkt.icmp6.ND_NEIGHBOR_ADVERT:  dpkt.icmp6.ND_NEIGHBOR_SOLICIT,

            dpkt.icmp6.MLD_LISTENER_QUERY:  dpkt.icmp6.MLD_LISTENER_REPORT,
            dpkt.icmp6.MLD_LISTENER_REPORT: dpkt.icmp6.MLD_LISTENER_QUERY,

            dpkt.icmp6.ICMP6_WRUREQUEST:    dpkt.icmp6.ICMP6_WRUREPLY,
            dpkt.icmp6.ICMP6_WRUREPLY:      dpkt.icmp6.ICMP6_WRUREQUEST,

            # Home Agent Address Discovery Request Message and reply
            144:                            145,
            145:                            144,
        }

        try:
            return pkt[ICMP6].type, mapper[pkt[ICMP6].type], False
        except KeyError:
            return pkt[ICMP6].type, pkt[ICMP6].code, True


class PacketKey(object):
    """
    A pseudo-struct, since we're in Python. dpkt already ensures that
    the network addresses coming in are in network byte order. The
    constructor ensures that the additional values become NBO values
    as well.
    """
    def __init__(self, src_addr, dst_addr, proto, src_port=0, dst_port=0):
        self.src_addr = src_addr
        self.dst_addr = dst_addr
        self.proto = proto
        self.src_port = src_port
        self.dst_port = dst_port

        # Store the protocol number as 8-bit int
        if isinstance(self.proto, int):
            self.proto = struct.pack('B', self.proto)

        # Store the port numbers as 16-bit, NBO
        if isinstance(src_port, int):
            self.src_port = struct.pack('!H', self.src_port)

        if isinstance(dst_port, int):
            self.dst_port = struct.pack('!H', self.dst_port)


class CommunityIDHasher(object):
    """
    Toplevel class for the functionality in this module.
    """
    def __init__(self, comm_id_seed=0, use_base64=True, verbose=False):
        self.comm_id_seed = comm_id_seed
        self.use_base64 = use_base64
        self.verbose = verbose

    def pcap_handle(self, pcapfile):
        """
        This function processes the given pcap file name, reporting the
        community ID string for every packet in the trace.
        """
        with open(pcapfile) as hdl:
            reader = dpkt.pcap.Reader(hdl)
            for tstamp, pktdata in reader:
                self._packet_handle(tstamp, pktdata)

    def _packet_get_key(self, pkt):
        """
        Returns a populated hashable "struct" (a PacketKey instance) for
        the given packet.
        """
        def is_lt(addr1, addr2, port1=0, port2=0):
            return addr1 < addr2 or (addr1 == addr2 and port1 < port2)

        if IP in pkt:
            saddr = pkt[IP].src
            daddr = pkt[IP].dst
        elif IP6 in pkt:
            saddr = pkt[IP6].src
            daddr = pkt[IP6].dst
        else:
            return None

        if TCP in pkt:
            if is_lt(saddr, daddr, pkt[TCP].sport, pkt[TCP].dport):
                return PacketKey(saddr, daddr, dpkt.ip.IP_PROTO_TCP,
                                 pkt[TCP].sport, pkt[TCP].dport)
            return PacketKey(daddr, saddr, dpkt.ip.IP_PROTO_TCP,
                             pkt[TCP].dport, pkt[TCP].sport)

        if UDP in pkt:
            if is_lt(saddr, daddr, pkt[UDP].sport, pkt[UDP].dport):
                return PacketKey(saddr, daddr, dpkt.ip.IP_PROTO_UDP,
                                 pkt[UDP].sport, pkt[UDP].dport)
            return PacketKey(daddr, saddr, dpkt.ip.IP_PROTO_UDP,
                             pkt[UDP].dport, pkt[UDP].sport)

        if SCTP in pkt:
            if is_lt(saddr, daddr, pkt[SCTP].sport, pkt[SCTP].dport):
                return PacketKey(saddr, daddr, dpkt.ip.IP_PROTO_SCTP,
                                 pkt[SCTP].sport, pkt[SCTP].dport)
            return PacketKey(daddr, saddr, dpkt.ip.IP_PROTO_SCTP,
                             pkt[SCTP].dport, pkt[SCTP].sport)

        if ICMP in pkt:
            port1, port2, is_one_way = ICMPHelper.packet_get_v4_port_equivalents(pkt)
            if is_one_way or is_lt(saddr, daddr, port1, port2):
                return PacketKey(saddr, daddr, dpkt.ip.IP_PROTO_ICMP, port1, port2)
            return PacketKey(daddr, saddr, dpkt.ip.IP_PROTO_ICMP, port2, port1)

        if ICMP6 in pkt:
            port1, port2, is_one_way = ICMPHelper.packet_get_v6_port_equivalents(pkt)
            if is_one_way or is_lt(saddr, daddr, port1, port2):
                return PacketKey(saddr, daddr, dpkt.ip.IP_PROTO_ICMP6, port1, port2)
            return PacketKey(daddr, saddr, dpkt.ip.IP_PROTO_ICMP6, port2, port1)

        if IP in pkt:
            if is_lt(saddr, daddr):
                return PacketKey(saddr, daddr, pkt[IP].p)
            return PacketKey(daddr, saddr, pkt[IP].p)

        if IP6 in pkt:
            if is_lt(pkt[IP6].src, pkt[IP6].dst):
                return PacketKey(pkt[IP6].src, pkt[IP6].dst, pkt[IP].nxt)
            return PacketKey(pkt[IP6].dst, pkt[IP6].src, pkt[IP].nxt)

        return None

    def _packet_parse(self, pktdata):
        """
        Parses the protocols in the given packet data and returns the
        resulting packet (here, as a dict indexed by the protocol layers
        in form of dpkt classes).
        """
        layer = Ethernet(pktdata)
        pkt = {}

        if isinstance(layer.data, IP):
            pkt[IP] = layer = layer.data
        elif isinstance(layer.data, IP6):
            # XXX This does not correctly skip IPv6 extension headers
            pkt[IP6] = layer = layer.data
        else:
            return pkt

        if isinstance(layer.data, ICMP):
            pkt[ICMP] = layer.data
        elif isinstance(layer.data, ICMP6):
            pkt[ICMP6] = layer.data
        elif isinstance(layer.data, TCP):
            pkt[TCP] = layer.data
        elif isinstance(layer.data, UDP):
            pkt[UDP] = layer.data
        elif isinstance(layer.data, SCTP):
            pkt[SCTP] = layer.data

        return pkt

    def _packet_to_str(self, pkt):
        """
        Helper that returns flow tuple string of given packet, as-is (no
        canonicalization).
        """
        parts = []

        if IP in pkt:
            parts.append(socket.inet_ntop(socket.AF_INET, pkt[IP].src))
            parts.append(socket.inet_ntop(socket.AF_INET, pkt[IP].dst))
            parts.append(pkt[IP].p)
        elif IP6 in pkt:
            parts.append(socket.inet_ntop(socket.AF_INET6, pkt[IP6].src))
            parts.append(socket.inet_ntop(socket.AF_INET6, pkt[IP6].dst))
            parts.append(pkt[IP6].nxt)

        if ICMP in pkt:
            parts.append(pkt[ICMP].type)
            parts.append(pkt[ICMP].code)
        elif ICMP6 in pkt:
            parts.append(pkt[ICMP6].type)
            parts.append(pkt[ICMP6].code)
        elif TCP in pkt:
            parts.append(pkt[TCP].sport)
            parts.append(pkt[TCP].dport)
        elif UDP in pkt:
            parts.append(pkt[UDP].sport)
            parts.append(pkt[UDP].dport)
        elif SCTP in pkt:
            parts.append(pkt[SCTP].sport)
            parts.append(pkt[SCTP].dport)

        return ' '.join(str(part) for part in parts)

    def _packet_get_comm_id(self, pkt, key):
        """
        The actual community ID hash logic. Given the packet and the
        "struct" of relevant values, feeds the NBO-ordered values into the
        hash, gets the result in base64, prepends the version string,
        and returns the result.
        """
        hashstate = hashlib.sha1()

        def hash_update(data):
            if self.verbose:
                hexbytes = ':'.join('%02x' % ord(b) for b in data)
                self._log(hexbytes + ' ')
            hashstate.update(data)
            return len(data)

        dlen = hash_update(struct.pack('!H', self.comm_id_seed)) # 2-byte seed
        dlen += hash_update(key.src_addr) # 4 bytes (v4 addr) or 16 bytes (v6 addr)
        dlen += hash_update(key.dst_addr) # 4 bytes (v4 addr) or 16 bytes (v6 addr)
        dlen += hash_update(key.proto) # 1 byte for transport proto
        dlen += hash_update(struct.pack('B', 0)) # 1 byte padding

        if any(proto in pkt for proto in TRANSPORT_PROTOS):
            dlen += hash_update(key.src_port) # 2 bytes
            dlen += hash_update(key.dst_port) # 2 bytes

        self._log('(%d bytes) ' % dlen)

        # The data structure we hash should always align on 32-bit
        # boundaries.
        assert dlen % 4 == 0, 'Hash input not aligned on 32-bit (%d bytes)' % dlen

        # The versioning mechanism is currently very simple: we're at
        # version one, which doesn't allow customization.
        version = '1:'

        # Unless the user disabled the feature, base64-encode the
        # (binary) hash digest. Otherwise, print the ASCII digest.
        if self.use_base64:
            res = version + base64.b64encode(hashstate.digest())
        else:
            res = version + hashstate.hexdigest()

        self._log('-> ' + res + '\n')

        return res

    def _log(self, msg):
        """
        Logging helper: in verbose mode, writes given message string to stderr.
        """
        if self.verbose:
            sys.stderr.write(msg)

    def _packet_handle(self, tstamp, pktdata):
        """
        All per-packet processing: parsing, key data extraction, hashing,
        and community ID production.
        """
        def print_result(tstamp, pkt, res):
            print('%10.6f | %s | %s' % (tstamp, res, self._packet_to_str(pkt)))

        pkt = self._packet_parse(pktdata)
        if not pkt:
            print_result(tstamp, pkt, '<not IP>')
            return

        key = self._packet_get_key(pkt)
        if key is None:
            # Should not happen, caught above!
            print_result(tstamp, pkt, '<not IP (???)>')
            return

        print_result(tstamp, pkt, self._packet_get_comm_id(pkt, key))


def main():
    parser = argparse.ArgumentParser(description='Community flow ID reference')
    parser.add_argument('pcaps', metavar='PCAP', nargs='+',
                        help='PCAP packet capture files')
    parser.add_argument('--seed', type=int, default=0, metavar='NUM',
                        help='Seed value for hash operations')
    parser.add_argument('--no-base64', action='store_true', default=False,
                        help="Don't base64-encode the SHA1 binary value")
    parser.add_argument('--verbose', action='store_true', default=False,
                        help='Show verbose output on stderr')
    args = parser.parse_args()

    hasher = CommunityIDHasher(args.seed, not args.no_base64, args.verbose)

    for pcapfile in args.pcaps:
        hasher.pcap_handle(pcapfile)

    return 0

if __name__ == '__main__':
    sys.exit(main())

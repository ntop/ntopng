--
-- (C) 2014-24 - ntop.org
--

-- ###############################################

-- See Utils::l4proto2name()
local l4_protocol_list = {}
  
l4_protocol_list.l4_keys = {
  { "IP",        "ip",          0 },
  { "ICMP",      "icmp",        1 },
  { "IGMP",      "igmp",        2 },
  { "TCP",       "tcp",         6 },
  { "UDP",       "udp",        17 },
  { "IPv6",      "ipv6",       41 },
  { "RSVP",      "rsvp",       46 },
  { "GRE",       "gre",        47 },
  { "ESP",       "esp",        50 },
  { "IPv6-ICMP", "ipv6icmp",   58 },
  { "EIGRP",     "eigrp",      88 },
  { "OSPF",      "ospf",       89 },
  { "PIM",       "pim",       103 },
  { "VRRP",      "vrrp",      112 },
  { "L2TP",      "l2tp",      115 },
  { "HIP",       "hip",       139 },
  { "SCTP",      "sctp",      132 },
  { "ICMPv6",    "icmpv6",     58 },
  { "IGMP",      "igmp",        2 },
  { "Other IP",  "other_ip",   -1 }
}

return l4_protocol_list
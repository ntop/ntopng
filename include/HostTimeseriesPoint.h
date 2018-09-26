class HostTimeseriesPoint: public TimeseriesPoint {
 public:
  nDPIStats *ndpi;
  u_int64_t sent, rcvd;
  u_int32_t num_flows_as_client, num_flows_as_server;
  TrafficCounter l4_stats[4]; // tcp, udp, icmp, other
  u_int32_t num_contacts_as_cli, num_contacts_as_srv;

  HostTimeseriesPoint();
  virtual ~HostTimeseriesPoint();
  virtual void lua(lua_State* vm, NetworkInterface *iface);
};


Views Architecture
------------------

Views are used to group interfaces into logical interfaces.
When using views the sub/real interfaces handle flows only, hosts are allocated in
the view interface only.

There is a SPSC queue for each sub/real interface belonging to the view interface.

NetworkInterface::viewEnqueue enqueues flows, from Flow::housekeep (incUses is used
to make sure flows are not purged when still in use)
ViewInterface::viewDequeue dequeues flows in the view interface

viewed_flows_walker takes care of hosts allocation/update with the flow information
coming from the sub/real interfaces.

Note:
- in the real interface there is no host allocation, as a consequence of this the
  Flow contructor allocates IpAddress (cli_ip_addr) instead of Host (cli_host)
- hosts are "Shared" between sub/real interfaces (pay attention to concurrent access)

Hosts Lifecycle with Views
--------------------------

1. Flow creation (sub/real interface thread)

   A viewed interface does not allocate the hosts hash table (see
   NetworkInterface, "Do not allocate HTs when the interface is viewed").
   The Flow constructor calls iface->findFlowHosts(), which returns
   *src = *dst = NULL as there is no hosts_hash. As a consequence:
   - cli_host / srv_host are NULL for the whole flow lifetime
   - cli_ip_addr / srv_ip_addr are dynamically allocated IpAddress objects
     (freed in Flow::~Flow when cli_host / srv_host are NULL)

   This means that get_cli_host(), get_srv_host() and get_actual_peers()
   always return NULL on a viewed interface. This includes all the code
   running in the sub/real interface thread during packet processing and
   detection, e.g. Flow::processDetectedProtocol, Flow::postDetectionCallback
   (pro/src/FlowPro.cpp), flow checks, etc.

2. Flow propagation to the view

   At the end of Flow::housekeep, getInterface()->viewEnqueue() pushes the
   flow into the SPSC queue of the view (incUses on the flow).
   ViewInterface::viewDequeue pops it, calls viewed_flows_walker and then
   decUses on the flow.

3. Host allocation/binding (view interface thread)

   viewed_flows_walker calls Flow::get_partial_traffic_stats_view(), which
   allocates the flow's ViewInterfaceFlowStats (viewFlowStats) the first time
   the flow is visited by the view (first_partial = true).

   - first_partial == true: ViewInterface::findFlowHosts() looks up (or
     allocates) the hosts in the view hosts hash using cli_ip_addr /
     srv_ip_addr. Hosts get incUses() / incNumFlows(), and are then saved in
     the flow with viewFlowStats->setClientHost() / setServerHost().
   - first_partial == false: hosts are taken from the flow via
     getViewSharedClient() / getViewSharedServer(), avoiding a hash lookup.
     This is safe here as viewed_flows_walker runs synchronously with the
     view purgeIdle.

   Host stats (traffic, score, services, blacklists, etc.) are updated here
   from the flow partials.

   Note: host allocation happens on the first view visit only. If the hosts
   hash is full at that time, the flow will have no hosts in the view.

4. Flow teardown

   In Flow::~Flow, the view hosts (getViewSharedClient/Server) get
   decUses() / decNumFlows(); score decrements for viewed interfaces are
   also done here (decAllFlowScores) to avoid races.

Accessing hosts from a flow on a viewed interface
-------------------------------------------------

- getViewSharedClient() / getViewSharedServer() return the view hosts
  (the "unsafe_cli" / "unsafe_srv" in ViewInterfaceFlowStats), falling back to
  cli_host / srv_host on non-viewed interfaces. They are NULL until the view
  has visited the flow at least once (i.e. usually NULL at detection time).
- These pointers are "unsafe" in the sub/real interface thread: the same host
  can be shared by multiple sub interfaces concurrently and it is owned by the
  view. Only call methods that are safe (locked or atomic) on them.
- Flow::triggerAlert explicitly looks up the hosts with
  viewedBy()->findFlowHosts() for read-only checks (alert exclusions).

Guidelines when host-related logic is needed (e.g. at detection time):

- If only the flow needs updating, do it in the sub/real interface without
  relying on Host objects. For example, use the IP address
  (get_cli_ip_addr()->isLocalHost()) instead of cli_host->isLocalHost().
- If host state needs updating, do it in ViewInterface::viewed_flows_walker
  (e.g. in the first_partial block), where the hosts are owned by the running
  thread. See Flow::updateHostBlacklists: it skips a NULL host ("Will be
  updated by ViewInterface::viewed_flows_walker") and the walker applies
  setBlacklistName on the view hosts.
- viewed_flows_walker uses the flow's cli_ip/srv_ip as they are. If the logic
  relies on the client/server swap heuristic (get_actual_peers), check
  f->is_swap_requested() and swap the hosts there as well.

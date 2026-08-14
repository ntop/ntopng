Active Scan
===========

ntopng implements active scans (host discovery, TCP and UDP port scans) using nmap.

Manual Installation
-------------------
The ntopng package installs nmap and its dependencies. For a manual installation just
install the nmap package for your platform, then do

``sudo setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip /usr/bin/nmap``

that will enable nmap to perform UDP-scans that require privileges.

Note
----
Earlier versions also shipped CVE, Vulners and OpenVAS scan engines based on the
`vulscan <https://github.com/scipag/vulscan>`_ NSE scripts. Those engines have been
removed and are no longer required: see ``attic/scripts/lua/modules/vulnerability_scan/``.

Scan Engines
------------
The available engines live in ``scripts/lua/modules/active_scan/modules``:

* ``tcp_portscan``
* ``udp_portscan`` (Linux only, requires privileges)
* ``ipv4_netscan``

Adding a new engine only requires dropping a new module in that directory.

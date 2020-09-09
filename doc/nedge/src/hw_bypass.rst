Hardware Bypass Support
=======================

The `Bridge mode` section describes ho to use nEdge to transparently forward
traffic as bump-in-the-wire between two network interfaces, WAN and LAN.
In this mode nEdge is able to leverage on a hardware bypass support for 
implementing automatic failover mechanisms in case of software or other
system failures. This is also useful for forwarding the traffic when the 
system is under maintenance or during a software update.

In bypass mode all packets received from one port are transmitted to the adjacent port.
This mode is automatically enabled when nEdge is not running, or in case the
software is not working properly for some reason (e.g. the fast path is stuck)
by leveraging on a heartbeat mechanism.

nEdge currently supports Silicom bypass adapters only. Please note that no special
configuration is required besides installing the Silicom driver: the adapter 
is automatically detected and the heartbeat mechanism is automatically enabled,
as long as the configured WAN and LAN interface belongs to the same bypass segment.
Please refer to the following section for the adapter configuration.

The adapter is usually in bypass state when the system is off, and it stays
in bypass state until nEdge is up and starts forwarding traffic (at that time
the bypass is switched off and the heartbeat mechanism is configured). The
hardware bypass is turned on again as soon as nEdge or the whole system is shut
down.

Silicom Adapters
----------------

In order to enable the bypass support on Silicom adapters, the *bp_ctl* driver 
(provided by Silicom) should be compiled and installed. Latest tested version
of the driver is is bp_ctl 5.2.0.41.

.. code-block:: console

   tar xvzf bp_ctl-xxx.tar.gz
   cd bp_ctl-xxx
   make && make install

Please note that on some boards like the Silicom RRC-VE CPE, a small patch
is required, by adding "#define ADI_RANGELEY_SUPPORT" at the beginning of the
bp_mod.c source file.

The bypass driver should be loaded using the *bpctl_start* tool. Please make
sure this is persistent across system reboots: a good practice is to create
a pf_ring *pre* script which is called during the capture framework initialization
as shown below.

.. code-block:: console

   echo "/bin/bpctl_start" >> /etc/pf_ring/pre
   chmod +x /etc/pf_ring/pre
   bpctl_start

Please note that a nEdge restart is required after loading the bypass driver in order 
to make sure that the bypass support is detected and enabled successfully.

Industrial Monitoring
#####################

Operational Technology (OT) refers to computing systems that are used to manage industrial operations. ntopng supports some Industrial Control Systems (ICS), often managed via Supervisory Control and Data Acquisition (SCADA) systems. Via nDPI it can detect protocols such as Modbus, S7Comm, PROFINET, IEC 60870-5-104 and BACnet. In addition to this, ntopng provides an extensive analysis of some of these protocols.

ntopng is a monitoring tool able to detect "generic" and behavioural issues that can disrupt an OT network. They include (but are not limited to):

- New device detection and invalid MAC/IP combinations
- Device traffic behavioural analysis (e.g. traffic misbehaving, peaks in traffic)
- New protocols and services: detect when a device changes the provided services (e.g. an HTTPS server is spawned) or a new protocol is used as client

In addition to the above services, specific protocols are supported in detail. This section lists the main protocols for which ntopng provides advanced monitoring features.

.. toctree::
    :maxdepth: 2
    :numbered:

    modbus
    s7comm
    profinet
    IEC60870-5-104

OT, ICS, SCADA Monitoring
#########################

Operational Technology (OT) refers to computing systems that are used to manage industrial operations. ntopng supports some Industrial control systems (ICS) often managed via a Supervisory Control and Data Acquisition (SCADA) systems. Via nDPI it can detect protocols such as Modbus, IEC 60780 and BACnet. In addition to this, ntopng has extensive for some protocols.

ntopng is a monitoring tool able to detect "generic" and behavioural issues that can distupt an OT network. They include (but are not limited to):

- New device detection and invalid MAC/IP combinations
- Device traffic behavioural analysis (e.e. traffic misbehaving, peaks in traffic)
- New protocols and services: detect when a devices changes in provided services (i.e. a HTTPS server is spawn) or a new protocol s used as client

In addition to the above services, specific protocols are supported in detail. This section lists the main protocols for which ntopng provides advanced monitoring feaatues.

.. toctree::
    :maxdepth: 2
    :numbered:

    IEC60870-5-104

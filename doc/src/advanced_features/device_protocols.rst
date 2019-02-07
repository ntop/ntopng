Device Protocols
================

ntopng implements different techniques to automatically identify the device type
of the devices connected to a network. This includes printers, IoT and phone devices.

For each device type, ntopng provides a configurable set of policies to determine
which protocols are acceptable for the specific device type. When a non-acceptable
protocol is detected, ntopng generates an alert.

ntopng provides some built-in policies which should suit most environments. The
`Device Protocols Alerts` must be enabled in order to be able to configure the policies.
Policies can be reviewed and customized in the `Device Protocols` page.

.. figure:: ../img/advanced_features_device_protocols_config.png
  :align: center
  :alt: Device Protocols Configuration

  The Device Protocols Configuration Page

Each policy is splitted in client and server configuration. For example, in the
picture above a *Printer* can act as an HTTP server but not as an HTTP client.

When alerting is not enough, nEdge can be used to `block the new devices protocols`_
according to the configured Device Protocols policies.

.. _`block the new devices protocols`: https://www.ntop.org/guides/nedge/policies.html#device-protocols-policies

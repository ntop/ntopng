Captive Portal
==============

nEdge can provide a captive portal for devices authentication. Any device
connecting to the LAN network won't be able to access the rest of the network
unless it authenticates with a username and password via the web captive portal.

.. figure:: img/captive_portal.png
  :align: center
  :alt: Captive Portal

  nEdge captive portal login

The redirection to the captive portal usually happens automatically when the
device first connects to the network.

.. figure:: img/phone_captive_login.png
  :align: center
  :alt: Android Captive Portal Login

  Android captive portal login notification

The access credentials for the captive portal are the ones configured in the
users_ page. A device label is also required. Although this is a free field, the user is
expected to insert a string to describe its device, e.g. `Joe's Laptop`.

Upon successful authentication, the device will be redirected to the web. A
customized *redirection URL* can be set up to redirect the devices to a specific website.

.. figure:: img/captive_portal_settings.png
  :align: center
  :alt: Captive Portal Settings

  Captive portal settings

By leaving the field blank, the devices will be redirected to the original website
they were trying to visit before the captive portal login.

.. _users: users.html

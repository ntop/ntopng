FAQ
###

Cannot Login into the GUI
=========================

If you locked yourself out of the ntopng GUI after a change in the `authentication method`_,
you can reset the ntopng login method to the default one (local authentication) with the following command:

.. code:: bash

  # For ntopng 3.7 and above:
  redis-cli set ntopng.prefs.local.auth_enabled 1

  # For ntopng 3.6 and below:
  redis-cli set ntopng.prefs.auth_type local

After restarting ntopng, you should be able to login with the administrator credentials.

If you forgot the administrator password, you can reset it with the following command:

.. code:: bash

  redis-cli del ntopng.user.admin.password

After restarting ntopng, you can login with the default ntopng credentials (admin, admin).

.. warning::

   Some browser plugins that perform javascript blocking may interfere with the login.
   Sometimes adding an exception for ntopng is not enough. Try to disable them before
   reporting an issue.

.. _`authentication method`: advanced_features/authentication.html

Too many failed authentication attempts
=======================================

If a device tries to login with wrong credentials too many times, it's IP
address is blacklisted for 5 minutes. In order to manually clean the blacklist,
the following command can be used:

.. code:: bash

  for k in `redis-cli keys ntopng.cache.failed_logins.*`; do redis-cli del $k; done

After executing the above command and restarting ntopng, the device will be able to
login again.

How can I monitor the sites visited by an host?
===============================================

To monitor the web sites visited by an host, make sure it is local (if unsure
about what is a local host check page :ref:`Hosts`). Then, you'll be
able to immediately view its visited sites by following the simple
instructions available at :ref:`Sites`.

Note that both plain HTTP sites as well as HTTPS sites are monitored!

How do I know who is using most of my bandwidth?
================================================

Is your Internet connection slow? Do you think someone in the network
is consuming all the available bandwidth? Well, ntopng helps you in
understanding this.

First, have a look at the :ref:`Dashboard` and the
:ref:`DashboardPro`. You'll immediately see the top local talkers and
the top remote destinations there!

Then, you can click on any of the hosts that have the highest throughput to
see what are they doing. Select the :ref:`Flows` page and sort flows
according to an ascending order of the "Actual Thpt" to have
visibility on the actually traffic the host is currently doing.


How can I associate an hostname to a certain category?
======================================================

Let's say you want to want to associate traffic from and to hostname
:code:`crazynetwork.it` to category "Download-FileTransfer-FileSharing" as
you know that that particular host is a mirror for the download of ISO
images.

Select the "Settings" wheel and click on "Categories"

.. figure:: ./img/faq_edit_traffic_categories.png
  :align: center
  :alt: Edit Categories

  The Edit Categories Menu Entry

Then, add hostname :code:`crazynetwork.it` to category
"Download-FileTransfer-FileSharing" by clicking on "Edit Hosts".

.. figure:: ./img/faq_edit_traffic_categories_custom_host.png
  :align: center
  :alt: Edit Category Hostnames

  The Edit Category Hostnames Page

Finally, save and from that moment on you'll have the matching traffic
opportunely categorized

.. figure:: ./img/faq_edit_traffic_categories_flow.png
  :align: center
  :alt: Flow With a Custom Category

  The Flow Details Page of a Flow with a Custom Category

Additional details and examples can be found at :ref:`CustomCategoryHosts`.

How can I estimate the disk space required by ntopng?
=====================================================

The following blog post gives accurate estimations of the disk space
required by ntopng to store timeseries and flows:
https://www.ntop.org/ntopng/ntopng-disk-requirements-for-timeseries-and-flows/


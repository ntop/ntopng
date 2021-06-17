The ntopng Web GUI
##################
After ntopng has started you can view the GUI. By default, the GUI can be accessed from any web browser at :code:`http://<ntopng IP>:3000/`. A different port can be specified as a command line option during ntopng startup. The first page that always pops out contains the login form - provided that the user has not decided to turn authentication off during startup.

.. figure:: ../img/web_gui_login_page.png
  :align: center
  :alt: The Login Page

  The Login Page

The default login is

+------------------+-------+
| **username**     | admin |
+------------------+-------+
| **password**     | admin |
+------------------+-------+

During the first access, a prompt will require the user to change the default password.

Administrator privileges are granted to user *admin*. If an unauthenticated user attempts to access a specific ntopng URL, the system will redirect the browser to the login page and then, upon successful authentication, to the requested resource. Ntopng GUI web pages have a common structure the user will soon be familiar with. The pages are mostly composed of an always-on-top status bar and some body content.

.. figure:: ../img/web_gui_header_bar.png
  :align: center
  :alt: The Header Bar

  The Header Bar

The header bar show the ntopng status information, in particular:

- The currently `selected interface <interfaces.html>`_.
- The interface Up/Down throughput chart.
- A series of coloured badges.
- A `search box <host_search.html>`_.
- The notifications bell and the `user administration menu <administration.html>`_.

The coloured indicate the status of many components in ntopng. The badges in the above picture have the following meaning (from left to right):

- Yellow triangle of `Degraded performance <../self_monitoring/internals.html#degraded-performance>`_.
- Red triangle with the `Engaged alerts <../basic_concepts/alerts.html#engaged-alerts>`_ count.
- Red triangle with the `Alerted Flows <../basic_concepts/alerts.html#flow-alerts>`_ count.
- Green badge with the number of active local hosts.
- Gray badge with the number of active remote hosts.
- Gray badge with the number of active devices.
- Gray badge with the number of active flows.

Red badges are often symptoms of problems. For example, if the active hosts ore flows badges are red
it means that the ntopng hash tables are full and some statistics can be lost
(`here <../operating_ntopng_on_large_networks.html#red-badges>`_ can be found more information on this topic).

A menu bar is always available on the left to navigate across ntopng pages.
Entries in the menu bar change depending on the currently selected interface. The :ref:`BasicConceptSystemInterface` has menu entries which are different from the other interfaces.
Each individual menu bar entry will be discussed below.
      
.. toctree::
    :maxdepth: 2

    help_menu
    dashboard_menu
    dashboard
    historical
    report
    flows
    checks
    categories
    hosts
    host_details
    pools
    interfaces
    settings
    administration
    host_search
    storage_monitor
    import_export

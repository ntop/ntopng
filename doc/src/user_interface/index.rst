User Interface Guide
####################
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

- The currently `selected interface <../basic_concepts/interfaces.html>`_.
- The interface Up/Down throughput chart.
- A series of coloured badges.
- A search box.
- The notifications bell and the `user administration menu <../user_interface/shared/settings/users.html>`_.

The coloured indicate the status of many components in ntopng. The badges in the above picture have the following meaning (from left to right):

- Yellow triangle with the `Engaged alerts <../basic_concepts/alerts.html#engaged-alerts>`_ count.
- Yellow triangle with the Warning `Alerted Flows <../basic_concepts/alerts.html#flow-alerts>`_ count.
- Red triangle with the Error `Alerted Flows <../basic_concepts/alerts.html#flow-alerts>`_ count.
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
      
The Interfaces dropdown menu entry in the top toolbar contains lists all the interfaces that are currently
monitored by ntopng. Among all interfaces listed, one has a check mark that indicates the interface is
currently selected. A special interface is always present in ntopng, the `System Interface <../basic_concepts/system_interface.html>`_.
Most of the data and information shown in ntopng web GUI is related to the currently selected
interface. Any interface listed can be selected simply by clicking on its name.

.. figure:: ../img/web_gui_interfaces_dropdown.png
  :align: center
  :alt: Interface Dropdown

  The Interfaces Dropdown Menu

The dropdown menu is only used to switch between selected interfaces, it is also used to actually see
interface traffic statistics.

.. toctree::
    :maxdepth: 2

    network_interface/index
    system_interface/index

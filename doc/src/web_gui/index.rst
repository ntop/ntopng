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

The header bar show status information such as the currently selected interface with its throughput, active hosts, flows and engaged alerts. In the right part of the header bar, a search box is available along with information on the currently logged-in user.

A menu bar is always available on the right to navigate across ntopng pages. Entries in the menu bar change depending on the currently selected interface. The :ref:`BasicConceptSystemInterface` has menu entries which are different from the other interfaces.
      
.. toctree::
    :maxdepth: 2

    help_menu
    dashboard_menu
    dashboard
    historical
    report
    flows
    user_scripts
    categories
    hosts
    host_details
    interfaces
    settings
    administration
    alerts
    host_search
    storage_monitor

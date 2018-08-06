ntopng Settings
===============

The Runtime settings can be configured using the dropdown gear menu in the top toolbar.

.. figure:: ../img/web_gui_settings_dropdown.png
  :align: center
  :alt: Settings Dropdown

  The Dropdown Settings Menu in the Top Toolbar

Manage Users
------------

Manage Users menu gives access to ntopng users administration. Ntopng is a multi-user system that
handles multiple simultaneous active sessions. Ntopng users can have the role of Administrators or
standard users.

.. figure:: ../img/web_gui_settings_users.png
  :align: center
  :alt: Users Settings

  The Manage Users Settings Page

Password and other preferences such as role and allowed networks can be changed by clicking on
button Manage, which causes a new window to pop out.

Preferences
-----------

Preferences menu entry enables the user to change runtime configurations. A thorough help is reported
below every preference directly into ntopng web GUI.

Manage Stored Data
------------------

Ntopng is able to export monitored hosts information. It allows to export data in JSON format giving the
user the ability to include ntopng information in a user created GUI.

.. figure:: ../img/web_gui_settings_export_data.png
  :align: center
  :alt: Export Data

  The Export Data Page

Backup Configuration
--------------------

The Backup Configuration entry downloads a copy of the ntopng configuration, as compressed 
tarball (.tar.gz), including:

- Configuration file (unless command line is used for providing the options)
- /etc/ntopng folder
- Runtime configuration (runtimeprefs.json)
- License file

Please note that on Windows systems the runtime configuration file only is provided.

The backup can be used to restore the configuration, placing a copy of the tarball
under /etc/ntopng/conf.tar.gz and restarting the ntopng service. Please note
that after restoring the configuration, the backup copy under /etc/ntopng/conf.tar.gz
is automatically deleted.


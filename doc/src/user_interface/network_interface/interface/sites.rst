.. _Sites:

Sites
-----

A *Site* is a named place - typically a physical location such as an office, a branch,
or a data center - to which one or more networks can be assigned. Sites let you
group networks by location, so that hosts, traffic, score and alerts can be reviewed per
place rather than per individual network. A site can optionally be pinned on a map through
its geographic coordinates.

.. note::

  Sites are available with an Enterprise M (or higher) license.

.. figure:: ../../../img/web_gui_sites_list.png
  :align: center
  :alt: Sites List

  The Sites Page

Sites are managed from the `Dashboard Sites`_ page. To access this page, click on `Dashboard` and the tab `Sites`
should be available

.. figure:: ../../../img/dashboard_sites_entry.png
  :align: center
  :alt: Dashboard Sites Tab

  The Dashboard Sites Tab

For each site the following information is shown:

- **Site**: the display name of the site.
- **Parent Site**: the display name of the Parent Site, if configured.
- **Description**: an optional free-text description.
- **Networks**: the networks currently assigned to the site.
- **Location**: the site coordinates (latitude and longitude). The location is shown only
  when coordinates have been set.

The Default Site
^^^^^^^^^^^^^^^^^

A predefined **Default** site is always present and cannot be removed. Every network
that has not been explicitly assigned to a site belongs to the Default site, which therefore
acts as a fallback. Being a reserved site, the Default site cannot be edited or deleted, and
its actions are disabled in the table.

Adding a Site
^^^^^^^^^^^^^

From the **Sites** tab, click the **+** button at the top of the table to open the creation
form, then fill in the following fields:

- **Site** (required): from 2 to 32 characters. Only letters, numbers and spaces are allowed
  (accented letters are accepted). The name must be unique: two sites cannot share the same name.
- **Description** (optional): up to 256 characters.
- **Parent Site** (optional): enter an other already configured Site to create a hierachy between sites.
- **Location** (optional): set the position either by typing the **Latitude** and **Longitude**
  values, or by clicking directly on the map below the fields. The map marker and the coordinate
  fields stay in sync, so a click updates the values and typing updates the marker. Latitude must
  be between -90 and 90, longitude between -180 and 180. 

.. figure:: ../../../img/web_gui_sites_edit_modal.png
  :align: center
  :alt: Add or Edit Site

  The Site creation / edit form


.. note::

  The search above the geographic map can be used to search for a Nation, a City or an address

Click **Save** to create the site. If a value is not valid (for example a duplicate name) the
form reports the error and the site is not saved.

Editing a Site
^^^^^^^^^^^^^^

In the **Sites** tab, use the edit action on a site row to reopen the same form with the current
values pre-filled. Update the fields as needed and click **Save**. The Default site is reserved
and cannot be edited.

Deleting a Site
^^^^^^^^^^^^^^^

Use the delete action on a site row and confirm to remove the site. The Default site is reserved
and cannot be deleted.

.. note::

  Deleting a site does not prevent removal when networks are still assigned to it. Any network
  that was assigned to the deleted site falls back to the Default site.

Assigning a Network to a Site
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Networks are not assigned to a site from the site form. Instead, the assignment is done from the
**Networks** tab: edit a network and choose the desired site from the list. The **Site** column in
the networks list shows the site each network currently belongs to. Networks left unassigned remain
part of the Default site.

.. figure:: ../../../img/web_gui_networks_edit_modal.png

  :align: center
  :alt: Edit the Network Site

  The Network edit form


Navigating Sites
^^^^^^^^^^^^^^^^

After creating a site, it will be displayed on the left navigation bar.

It is possible to search Sites, Devices, ecc. by entering the name of the Asset to search in the search bar


.. figure:: ../../../img/dashboard_sites_search.png

  :align: center
  :alt: Dashboard Sites Details

  Dashboard Sites Details


All the information displayed are searchable both on Live Data and Historical Data


.. figure:: ../../../img/dashboard_sites_time_picker.png

  :align: center
  :alt: Dashboard Sites Details

  Dashboard Sites Details


From there it is possible to display the data of each site in details:

- Flows (if present);
- Exporters (if present);
- Networks;


.. figure:: ../../../img/dashboard_sites_details.png

  :align: center
  :alt: Dashboard Sites Details

  Dashboard Sites Details


It is also possible to drill down more inside each information displayed.
If available, the Networks and Exporters will be displayed inside the Site and they are also navigable with their own statistics and data.

For Networks, there will be displayed:

- Exporters (if present)
- Flows
- Hosts


.. figure:: ../../../img/dashboard_sites_networks_details.png

  :align: center
  :alt: Dashboard Sites Details

  Dashboard Sites Details


Exporters, instead, will display:

- Traffic Analysis: a generic dashboard with the main stats (e.g. Top Hosts, Top Applications, ...)
- Interfaces: the interfaces of the Exporter
- Flows
- Hosts
- SNMP: only available if the Flow Exporter is being polled with SNMP by ntopng


Finally SNMP devices are also available (only if polled by ntopng with SNMP), with a generic dashboard, displaying various info
about the device itself


.. figure:: ../../../img/dashboard_sites_snmp_device_details.png

  :align: center
  :alt: Dashboard Sites Details

  Dashboard Sites Details
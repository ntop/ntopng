Categories
##########

ntopng provides a classification of the network traffic into a set of logical categories.
Streaming, SocialNetwork and Web are examples of categories.

.. figure:: ../img/web_gui_flow_category.png
  :align: center
  :alt: The Category reported on the flow details

The picture above shows the Collaborative category being reported on the flow
details of a Github/DNS flow. The flow Category is usually determined based on the
flow protocols. The *Protocols* page can be used to review and modify the category
associated to each protocol:

.. figure:: ../img/web_gui_protocols_category.png
  :align: center
  :alt: The Protocol Category editor

Category Hosts
--------------

Apart from the protocol based mapping specified in the *Protocols* page above,
ntopng also supports host-based rules. The host-based rules will be used to perform
substring matching on some of the flow information:

  - Client/Server IP
  - Host SNI
  - HTTP Host

If a match is found, the flow category will be set to the corresponding matching category.
These rules can be configured from the *Categories* page.

.. figure:: ../img/web_gui_category_editor.png
  :align: center
  :alt: The Category editor

By clicking "Edit Hosts" it's possible to define some hosts which will be considered
as part of the category.

.. figure:: ../img/web_gui_edit_category_hosts.png
  :align: center
  :alt: Edit Category Hosts
  :height: 400px

The picture above shows some custom hosts defined for the Advertisement category.
For example, the `.ads.` host rule will match any host containing `.ads.` . It is important
to play with the dots to avoid excessive matching (e.g. a simple `ads` rule would also match `mads.com`).

Host matching based on IP addresses is currently limited to IPv4 flows. So, this currently does *not*
include ICMP flows.

Flow Shortcut
-------------

From the flow details view there is a convenient way to add the flow SNI/HTTP host
to a customized category.

.. figure:: ../img/web_gui_add_host_to_category.png
  :align: center
  :alt: Edit Category Hosts

.. figure:: ../img/web_gui_add_host_to_category_dialog.png
  :align: center
  :alt: Edit Category Hosts

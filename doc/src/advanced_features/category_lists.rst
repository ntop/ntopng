.. _Category Lists:

Category Lists / Blacklists
===========================

ntopng uses third party IP/domain lists to detect malicious hosts, the Category Lists.
Each list contains a list of hosts which are associated to a particular `protocol category`_.

Examples of Category Lists are the malware and mining hosts blacklists, which are used by
ntopng to detect malicious hosts and generate `alerts`_.

.. note::

  Check out the `Custom Category Hosts docs`_ for a way to assign custom hosts to the ntopng categories.

.. figure:: ../img/advanced_features_category_lists.png
  :align: center
  :alt: Category Lists Configuration Page

  The Category Lists Configuration Page

Right now only some built-in lists are supported by user defined lists could be added in the
future. Lists are updated periodically based on the configured *Update Frequency*.
By clicking on the *Update Now* button it's possible to force the list update.
The *Num Hosts* column indicates the number of hosts loaded from the specified list.
The *Status* column indicates the list current status:

- *Enabled*: the list is enabled and will be used by ntopng
- *Disabled*: the list is disabled and will be ignore by ntopng
- *Error*: there was an error while downloading the list. Check out the ntopng log for details.

By clicking on the *Edit* button it's possible to edit the list update frequency and
to disable the list.

.. figure:: ../img/advanced_features_category_lists_edit.png
  :align: center
  :alt: Customize a Category List options
  :scale: 70%

  Customize Category List options

When a list is disabled, it will not be updated anymore.

.. _`protocol category`: ../web_gui/categories.html
.. _`Custom Category Hosts docs`: ../web_gui/categories.html#custom-category-hosts
.. _`alerts`: ../web_gui/alerts.html

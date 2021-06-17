Plugins and Checks
========================

End users can extend the ntopng functionalities by creating plugins which
allow them, for example, to trigger custom alerts or provide new data visualizations
in ntopng.

Plugins can contain different resources, for example `localization files`_, `custom pages`_
and `alert definitions`_. The `Checks`_ are one particular resource which
allow the user to implement a custom logic in response to an event (such
events are called Hooks in ntopng).

For an extensive discussion on how to develop new plugins check out the `Plugins section`_ .

.. _`Plugins section`: ../plugins/overview.html
.. _`localization files`: ../plugins/localization.html
.. _`custom pages`: ../plugins/custom_pages.html
.. _`alert definitions`: ../plugins/alert_definitions.html
.. _`Checks`: ../plugins/checks.html

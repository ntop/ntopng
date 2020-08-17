.. _Manifest:

Manifest
========

:code:`manifest.lua` contains basic plugin information such as name, description and version. It must be placed in the root directory of the plugin as shown in :ref:`Plugin Structure`.

:code:`manifest.lua` must return a Lua table as

.. code:: lua

	  return {
	     title = "Plugin Title",
	     description = "Plugin Description",
	     author = "ntop",
	     dependencies = {},
	  }

Table keys are:

- :code:`title`: The title of the plugin. This is used within the ntopng web GUI to identify and configure the plugin.
- :code:`description`: The description of the plugin. This is used within the ntopng web GUI to describe the plugin to the user.
- :code:`author`: A string indicating the name of the author of the plugin.
- :code:`dependencies`: A Lua array of strings indicating which other plugins this plugin depends on. The array can be empty when the plugin has no dependencies.



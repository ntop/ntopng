ntop
====

The ntop object exposes global utility functions which are not bound to a specific
network interface.

Here is some example of recurrent functions calls:

.. code-block:: lua

  -- An URL
  print[[<a href="]] print(ntop.getHttpPrefix()) print[[/lua/if_stats.lua">interface stats</a>]]

  -- A POST form
  print[[<form method="POST">
    <input name="csrf" type="hidden" value="]] print(ntop.getRandomCSRFValue()) print[[" />
    <input name="my_custom_value" value="1" />
  </form>]]

  -- Set a persistent preference
  ntop.setPref("ntopng.prefs.my_custom_pref", "my_custom_value")

  -- Get a persistent preference
  local res = ntop.getPref("ntopng.prefs.my_custom_pref")

  -- tprint(res)

.. toctree::
    :maxdepth: 2

    ntop_cache
    ntop_prefs
    ntop_fs
    ntop_network
    ntop_users
    ntop_misc

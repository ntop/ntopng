.. _Plugin Localization:

Localization
============

Localization is attempted for every table key which begins with :code:`i18n_`. Such table keys are found in plugin :ref:`Alert Definitions`, :ref:`Flow Definitions`, :ref:`User Scripts` and other plugin components. To localize a string, ntopng considers it as the key of a localization table.

A localization table is a Lua table containing keys and translated strings as values. Multiple localization tables are available, one for each supported language. ntopng selects a localization table on the basis of the language set for the current user. All the ntopng localization tables are available on `GitHub <https://github.com/ntop/ntopng/tree/dev/scripts/locales>`_. English is the fallback localization table.

A string :code:`s` is localized as follows:

1. :code:`s` is looked up into the localization table of the language set for the user. If a key :code:`s` exists in the localization table, the localized string is taken as the value of key :code:`s` and the localization ends. If key :code:`s` does not exists:
2. :code:`s` is looked up into the English fallback localization table. If a  key :code:`s` exists in the English fallback localization table, the localized string is taken as the value of key :code:`s` and the localization ends. If key :code:`s` does not exists:
3. The string :code:`s` is taken verbatim.

If the language set for the user is English, only the English localization table is used.

Dots :code:`.` are allowed in strings to be localized. Dots are treated as separators to handle localization sub-tables. A string :code:`s.t` is looked up into a localization table as follows:

1. Key :code:`s` is looked up into the localization table. The value of :code:`s` is expected to be another table.
2. Key :code:`t` is looked up into the table found as the value for key :code:`s`.

A plugin can extend ntopng localization tables. Extension is done using Lua files placed under plugin sub-directory :code:`./locales`. Lua files contain localization tables. Each file must have the name of one of the ntopng supported languages and it must return a Lua table. For example, to extend the ntopng English localization file a plugin can use an :code:`en.lua` file as shown `here <https://github.com/ntop/ntopng/tree/dev/scripts/plugins/example/locales>`_. Plugin localization tables are automatically merged with ntopng localization tables.

Parameters
----------

Localized strings accept parameters. Parameters are not translated. They are passed to the string automatically by ntopng. Parameters are passed to the localized string as a Lua table. The Lua table is passed automatically by ntopng but is specified in the plugin code.

Parameters in a localized string are expressed as :code:`%{parameter_name}`. Localization replaces the :code:`%{parameter_name}` with the actual parameter value found in key :code:`parameter_name` of the parameters Lua table.

Examples
--------

Consider

.. code:: lua

	i18n_title = "alerts_dashboard.blacklisted_flow"

Prefix :code:`i18n_` tells ntopng :code:`alerts_dashboard.blacklisted_flow` needs to be localized. Assuming german is set as language for the current user:

1. ntopng looks up key :code:`alerts_dashboard` in the german localization table. If the key is found and the value is a table, ntopng looks up key :code:`blacklisted_flow` in the table found as value. If key :code:`blacklisted_flow` is found, then it's value is taken as the localized string and the localization ends. If any of the two keys does not exists:
2. Step 1. is repeated on the English fallback localization table. If no localized string is found:
3. :code:`alerts_dashboard.blacklisted_flow` is taken verbatim.

Consider now the entry

.. code:: lua

	["iface_download"] = "%{iface} download"

Found in file `en.lua <https://github.com/ntop/ntopng/blob/26aa2ebecc3b446119ec981b2454b0ab12d488e2/scripts/locales/en.lua#L105>`_. The localized string contains parameter :code:`%{iface}`. This parameter will be replaced with the value found in key :code:`iface` of the parameters Lua table. So for example if the parameters Lua table is :code:`{iface="eno1"}`, localized string will become :code:`"eno1 download"`.

Scripts Structure
#################

Here is the skeleton for a generic user script:

.. code:: lua

  local user_scripts = require("user_scripts")

  -- #################################################################

  local script = {
    hooks = {},

    -- other script attributes ...
  }

  -- #################################################################

  function script.setup()
    -- return false to disable the script
    return true
  end

  -- #################################################################

  return(script)

A user script must expose the following attributes:

  - `hooks`: a map `hook_name -> callback` which defines on which events
    the callback should be invoked. The scripts must register at least one
    hook. The list of available hooks depends on the script type, check out
    the flow/traffic element documentation for details.

Note: `any` is a special hook name which will cause the associated callback to be called for all the events.

The following optional attributes can also be exposed:

  - `gui`: See `GUI Configuration` below for more details.
  - `local_only` (hosts only): if true, the script will not be executed on remote hosts
  - `packet_interface_only`: only execute the script on packet interfaces
  - `l4_proto` (flows only): only execute the script for flows matching the L4 proto.
  - `l7_proto` (flows only): only execute the script for flows matching the L7 proto.
    see 2nd column in lua_utils.lua::l4_keys for supported protocols.
  - `nedge_only`: if true, the script will only be executed in nEdge
  - `nedge_exclude`: if true, the script will not be executed in nEdge
  - `default_value`: the default value for the script configuration,
    in the form `<script_key>;<operator>;<value>` (e.g. `syn_flood_victim;gt;50`)
  - `default_enabled`: if false, the script will be disabled by default

Futhermore, a script may define the following extra callbacks, which are only called once per script:

  - `setup()`: a function which will be called once per user script. If it
    returns `false` then the script is considered disabled and its hooks
    will not be called.
  - `teardown()`: a function to be called after the script operation is complete
    (e.g. after all the hosts have been iterated and hooks called).

Scripts Location
----------------

The user scripts location is reported into the `Directories` page under the
home icon into the ntopng menu. Usually built-in scripts are located under
the `/usr/share/ntopng/scripts/callbacks` directory.

Hook Callback
-------------

The hook callback function takes the following form:

.. code:: lua

  function my_callback(params)
    -- ...
  end

The information contained into the params object depends on the script type:

  - `granularity` (traffic element only): the current granularity
  - `alert_entity` (traffic element only): the traffic element entity type
  - `entity_info` (traffic element only): contains entity specific data
    (e.g. on hosts, it is the output of `Host:lua()`)

Script Configuration
--------------------

A user script can provide some gui configuration items. These are specified via the
`gui` attribute:

.. code:: lua

  local script = {
    ...

    gui = {
      i18n_title = "config_title",
      i18n_description = "config_description",
      input_builder = user_scripts.checkbox_input_builder,
    }

    ...
  }

The mandatory gui attributes are:

  - `i18n_title`: a localization string for the title of the element
  - `i18n_description`: a localization string for the description of the element
  - `input_builder`: a function which is responsible for building the HTML code
    for the element

Additional parameters can be specified based on the input_builder function. Here is
a list of built-in input_builder functions:

  - `user_scripts.threshold_cross_input_builder`: contains an input field with an operator
    and a unit. Suitable to speficy thresholds like "bytes > 512". Here is a list of additional
    supported parameters:

    - `field_max`: max value for the input field
    - `field_min`: min value for the input field
    - `field_step`: step value for the input field
    - `i18n_field_unit`: localization string for the unit of the field. Should be one of `user_scripts.field_units`.

  - `user_scripts.checkbox_input_builder`: a simple checkbox

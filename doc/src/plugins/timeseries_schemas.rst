.. _Timeseries Schemas:

Timeseries Schemas
==================

Checks invoked via the `checks hooks`_ can use the `Timeseries
API`_ to write their own timeseries data and then visualize it in `Custom
Pages`_. A full example of a plugin specialized in collecting Redis metrics
is the `Redis monitor plugin`_ .

In order to write timeseries, it is first necessary to define the timeseries
schemas.

Schemas Definition
------------------

Custom schemas are defined into the `./ts_schemas` subdirectory of the plugin.
The directory can contain one or more of the following files:

- :code:`min.lua`: Define schemas whose points have 1 minute resolution.
- :code:`5mins.lua`: Define schemas whose points have 5 minutes resolution.
- :code:`hour.lua`: Define schemas whose points have 1 hour resolution.
- :code:`day.lua`: Define schemas whose points have 1 day resolution.

For example, schemas defined into `min.lua` are suitable to be used in the user
scripts `min` hook (see `the relevant page`_ for more details). Each file should use the timeseries
API in order to define its schemas. Here is an example of `min.lua`:

.. code:: lua

  local ts_utils = require "ts_utils_core"
  local schema

  schema = ts_utils.newSchema("example:active_hosts", {
    step = 60,
    metrics_type = ts_utils.metrics.gauge,
  })

  schema:addTag("ifid")
  schema:addMetric("num_hosts")

The above script defines a schema named `example:active_hosts` whose points
have a 60 seconds resolution. For internal reasons, it is always necessary
to specify the `step` even if the file is named `min.lua`. The schema is
identified by the `ifid` tag and contains one gauge metric named `num_hosts`.

Schemas Usage
-------------

A check could then use the above schema as follows:

.. code:: lua

  local script = {
    hooks = {},

    ...
  }

  script.hooks.min = function(params)
    ...

    if params.ts_enabled then
      local ifid = getSystemInterfaceId()
      local num = ... get the current metric value here ...

      ts_utils.append("example:active_hosts", {ifid = ifid, num_hosts = num})
    end
  end

  return(script)

It's important to check that `params.ts_enabled` flag in order to call `ts_utils.append` only
if the timeseries are enabled for the given entity currently processed.

.. _`checks hooks`: check_hooks.html#user-script-hooks
.. _`Timeseries API`: ../api/timeseries/index.html
.. _`Custom Pages`: custom_pages.html
.. _`Redis monitor plugin`: https://github.com/ntop/ntopng/tree/dev/scripts/plugins/redis_monitor
.. _`the relevant page`: check_hooks.html#other-user-script-hooks

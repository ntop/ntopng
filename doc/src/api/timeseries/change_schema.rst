Modify an existing Schema
#########################

Modifying a timeseries schema has some drawbacks and it is only possible under
some constraints. For this reason is usually better to create a new schema or
change the schema name, although this is not always applicable as it leads to
data loss.

The contraints are:

  - Schema type or options (like the step) cannot be modified
  - Up to 3 metrics per schema are supported
  - New schema metrics can be added but not removed. Existing ones can be renamed.

Here are the drawbacks:

  - InfluxDB: If a schema metric name is changed, the past traffic will be not be
    displayed anymore in the ntopng charts (RRD is not affected as the metrics are positional)

.. warning::

   After modifying a schema, the schema name must be added to the function `ts_utils.getPossiblyChangedSchemas`

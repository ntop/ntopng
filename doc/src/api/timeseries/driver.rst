Driver Implementation
#####################

Topk result:
  - *topk*: a sorted list of a topk item
  - *statistics*: (optional) query result statistics.
  - *additional_series*: (optional) a list of additional series (e.g. the *total series*).

Topk item:
  - *tags*: a map tag_name -> tag_value
  - *value*: the integral value for the topk item on the specified time range

A timeseries driver must implement the API described below.

.. doxygenfile:: driver.lua.cpp

ts_utils API
############

`Query options`:
  - *max_num_points*: maximum number of points per data serie.
  - *fill_value*: the value to use for filling empty points. Use 0/0 for `nan`.
  - *min_value*: minimum value.
  - *max_value*: maximum value, use `math.huge` for unlimited.
  - *top*: number of top items to return in a "topk" query.
  - *calculate_stats*: if true, calculate additional stats (like average and 95th percentile).

`Query result` (returned by `ts_utils.query` and `ts_utils.topk`):
  - *start*: result start time.
  - *step*: result time step in seconds between consecutive series points.
  - *count*: number of points for each data series.
  - *series*: a list of data series. See below for details.
  - *statistics*: additional statistics. See below for details. Statistics are optional.
  - *additional_series*: (optional) a list of additional series (e.g. the *total series*).

Data series:
  - *label*: series label.
  - *data*: a unidimensional array of series values.

`Query result statistics`:
  - *total*: traffic integral in the specified time range.
  - *average* average value.
  - *min_val_idx*: index for the minimum series value.
  - *min_val*: minimum series value.
  - *max_val_idx*: index for the maximum series value.
  - *max_val*: maximum series value.
  - *95th_percentile*: the 95th percentile.

.. note::
  All the stats are calculate on the *total series*.
  The *total series* is obtained by taking the sum, point by point, of all the returned
  series. On topk queries, it also includes the non top series.

.. doxygenfile:: ts_utils.lua.cpp

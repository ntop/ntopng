.. _ClickHouseExplorer:

ClickHouse Explorer
===================

The ClickHouse Explorer (left sidebar menu: Developer -> ClickHouse Explorer) lets an administrator
read the historical data that ntopng saves in ClickHouse (flows, alerts, assets...) with SQL queries.

.. note::

  This page needs ntopng Enterprise XL, ClickHouse enabled (``-F clickhouse``) and the
  experimental features enabled in Preferences. Only administrators can open it, and only
  from the web interface (scripts and API tokens cannot use it).

At the top of the page you choose a table: its size, number of rows and columns are shown.
Click a column to add its name to the query, or type in the filter box to find a column.

In the query box you write a SELECT query and click Run (or press Ctrl+Enter). Preview table
shows the first 100 rows of the selected table. Max rows limits how many rows are returned
(100, 1,000, 5,000 or 10,000).

Only read queries are executed: queries that change data, read the ClickHouse system tables
or access files and other servers are refused. Dates and IPv4 addresses are shown in a readable
form, and the results can be sorted by clicking a column.

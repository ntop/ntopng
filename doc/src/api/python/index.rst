Python API
==========

ntopng provides a Python 3 API for querying the engine and retrieve traffic information by using the Python language.

The API is based on the ntopng REST API and it allows users to perform operations such as:

- Read host statistics
- Get the active flows list
- Query network interface stats
- Search historical flows

For each ntopng component there is a corresponding Python class (Host, Interface, Historical), and for each REST API call there is a corresponding method.
The ntopng class is used to keep information about the ntopng configuration including IP address and credentials required to connect.

Prerequisites
-------------

The API is using Pandas for working with time series data.

.. code:: bash

   pip3 install pandas

Examples are using additional libraries including NumPy for playing with time series data, plotly and fpdf for generating reports in PDF format.

.. code:: bash

   pip3 install numpy plotly fpdf

Installation
------------

For you convenience, ntop periodically builds pip packages. You can install the latest available package as:

.. code:: bash

   pip3 install ntopng

Examples
--------

A few sample applications are distributed with the ntopng source code and are available at https://github.com/ntop/ntopng/tree/dev/python/examples

All the examples require:

- ntopng URL (-n option, *localhost:3000* by default)
- ntopng credentials
   - ntopng user (-u option, *admin* by default) and ntopng password (-p option, *admin* by default)
   - or ntopng Token (https://www.ntop.org/guides/ntopng/advanced_features/authentication.html?#token-based-authentication)

Some of the examples also require an ntopng interface ID (-i option) and additional parameters (e.g. host).

Example:

.. code:: bash

   python3 alerts.py -n http://localhost:3000 -i admin -p password -i 0

This sample application is printing alert statistics, please see below a code snippet for achieving the same:

.. code:: python

   # Connect to ntopng using the Ntopng class
   my_ntopng = Ntopng(username, password, auth_token, ntopng_url)
   
   # Get an Historical instance for a specific interface by ID
   my_historical = my_ntopng.get_historical_interface(iface_id)
   
   # Read alert statistics
   data = my_historical.get_alerts_stats(epoch_begin, epoch_end)
   
   # Print the raw statistics
   print(data)

API
---

.. automodule:: ntopng
   :members:

.. automodule:: interface
   :members:

.. automodule:: host
   :members:

.. automodule:: historical
   :members:


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

Installation
------------

For you convenience, ntop periodically builds pip packages. You can install the latest available package as:

.. code:: bash

   pip3 install ntopng

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


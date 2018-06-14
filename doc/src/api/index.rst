API Documentation
=================

Ntopng provides a Lua API to interact with the core. The API is internally used
by periodic scripts and gui scripts to extract information or to apply configuration
changes.

Custom user scripts can use the API, for example, to provide new data visualizations
or extract the data to send it to an external program.

Since some API functions can return very complex objects, which will not be covered here,
the suggestion is to use the utility function `tprint` to print out the result a the function
to figure out its format.

.. toctree::
    :maxdepth: 2
    :numbered:

    lua/index

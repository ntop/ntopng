OEM Customizations
==================

.. warning::

  Only OEMs are allowed to customize ntopng logo and name, and they are required to enter ad-hoc agreements with ntop before doing this. Simply removing the ntopng logo or changing its name would result in user-license infringements.

Linux versions of ntopng Professional/Enterprise allows OEMs to customize logo, favincon, CSS and product name.

To set a product name, place it in a single-line text file under

.. code:: bash

  /etc/ntopng/product_name

To load a custom logo, place it under 

.. code:: bash

  /etc/ntopng/custom_logo.png

The logo must be in format :code:`png` and it must be 52x52 pixels in size.

To load a custom favicon, please it under

.. code:: bash

  /etc/ntopng/custom_favicon.ico

To load a custom CSS, place it under

.. code:: bash

  /etc/ntopng/custom_theme.css

Automatic updates are disabled in OEM mode, unless a custom repository is configured.
The sources file for the repository should be placed under

.. code:: bash

  /etc/apt/sources.list.d/ntop-oem.list


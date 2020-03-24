.. _Web UI:

Web UI
======

A user script can provide some gui configuration items. These are
specified via the :code:`gui` attribute:

.. code:: lua

  local script = {
    ...

    gui = {
      i18n_title = "config_title",
      i18n_description = "config_description",
    }

    ...
  }

The mandatory gui attributes are:

  - :code:`i18n_title`: a localization string for the title of the
    element
  - :code:`i18n_description`: a localization string for the
    description of the element
  - :code:`input_builder`: a function which is responsible for
    building the HTML code for the element

Additional parameters can be specified based on the input_builder
function. Here is a list of built-in input_builder functions:

  - :code:`threshold_cross`: contains an input field with an operator
    and a unit. Suitable to speficy thresholds like "bytes > 512".

Here is a list of additional supported parameters:

    - :code:`field_max`: max value for the input field
    - :code:`field_min`: min value for the input field
    - :code:`field_step`: step value for the input field
    - :code:`i18n_field_unit`: localization string for the unit of the
      field. Should be one of :code:`user_scripts.field_units`.

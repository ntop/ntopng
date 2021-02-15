# ntop-widgets

## How to run ntop-widgets in ntopng

To run and test the ntop widgets components in `ntopng` you have to follow these steps:

1. Clone this repository in the same directory where `ntopng` is installed
2. Go to the `ntop-widgets` directory, open your terminal and type: `npm install && npm run build`
3. Once the build is over, go to the `ntopng` folder, open your terminal and type:

    ```bash
    cd httpdocs/js
    ln -s  ../../../ntop-widgets/dist/ntop-widgets ntop-widgets

    # change directory to ntopng root
    cd scripts/lua
    ln -s ../../tests/lua tests
    ```

4. Start `ntopng` and go to the page: `http://localhost:3000/lua/tests/test_gui_widgets.lua`.

## How to include ntop-widgets inside a web page

To include an ntop-widget inside your web page you have to insert the following tags:

```html5
<script type="module" src="../path/to/ntop-widgets/ntop-widgets.esm.js"></script>
<script nomodule src="../path/to/ntop-widgets/ntop-widgets.js"></script>
```

Once the script tags have been included in your page you can use the ntop widgets. There is an example:

```html5
   <ntop-widget transformation="pie" update="15000" width="600px" height="400px">
       <ntop-datasource type="interface_packet_distro" params-ifid='0'></ntop-datasource>
   </ntop-widget>
```

The `update` paramater indicates, in milliseconds, when refresh a widget.

### Packages Used

These are the packages used for ntop-widgets:

* [chart.js](https://www.chartjs.org/) - MIT License

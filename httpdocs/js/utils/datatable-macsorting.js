/**
 * This is a pluginf for the Spyrmedia Datatables.
 * This plugins sort the columns containing IP Addresses.
 * Thanks to: https://datatables.net/plug-ins/sorting/ip-address
 */
jQuery.extend( jQuery.fn.dataTableExt.oSort, {
    "mac-address-pre": function (mac) {
        const associatedNumber = mac.split(":").map(byte => parseInt(byte, 16)).join("");
        return (associatedNumber);
    },
    "mac-address-asc": function ( a, b ) {
        return ((a < b) ? -1 : ((a > b) ? 1 : 0));
    },
    "mac-address-desc": function ( a, b ) {
        return ((a < b) ? 1 : ((a > b) ? -1 : 0));
    }
});
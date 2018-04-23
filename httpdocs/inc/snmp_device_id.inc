
function snmp_device_setID(row) {
  var index = 0;
  var snmp_device_key = row.find("td").eq(0).text();

  // Set the row index to the network key
  row.attr('id', snmp_device_key);

  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_index");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_chart");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_name");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_type");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_mtu");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_vlan");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_speed");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_mac");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_status");

  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_inb");
  //  row.find("td").eq(index - 1).text(bytesToSize(row.find("td").eq(index).text()));

  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_outb");
  //  row.find("td").eq(index - 1).text(bytesToSize(row.find("td").eq(index).text()));
  
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_in_discards");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_seen_macs");
  row.find("td").eq(index++).attr('id', snmp_device_key + "_port_last_change");

  $("#" + snmp_device_key + '_port_inb').html(bytesToSize($("#" + snmp_device_key + '_port_inb').text()));
  return row;

}

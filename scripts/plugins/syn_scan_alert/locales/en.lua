return {
  syn_scan_attacker_title = "SYN Scan Attacker Alert",
  syn_scan_attacker_description = "Trigger an alert when the number of sent SYNs/min (with no response) exceeds the threshold",
  syn_scan_victim_title = "SYN Scan Victim Alert",
  syn_scan_victim_description = "Trigger an alert when the number of received SYNs/min (with no response) exceeds the threshold",
  syn_scan_attacker = "%{entity} is a SYN Scan attacker [%{value} &gt; %{threshold} SYN sent]",
  syn_scan_victim = "%{entity} is under SYN Scan [%{value} &gt; %{threshold} SYN received]",
  tcp_syn_scan = "TCP SYN Scan",
}

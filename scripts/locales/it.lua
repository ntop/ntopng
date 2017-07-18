local  it = {
   welcome = "Benvenuto",
   version = "La tua versione è %{vers}.",
   report = {period = "Intervallo",
	     date = "%{day}/%{month}/%{year}"},

   locales = {
      en = "Inglese",
      it = "Italiano",
      jp = "Giapponese",
   },

   network_stats = {
      networks = "Reti",
      networks_traffic_with_ipver = "%{networks} con traffico IPv%{ipver}",
      network_list = "Lista Reti",
      network_name = "Nome Rete",
      note_overlapping_networks = "NOTA: Tutte le reti definite sono mostrate nella lista: ",
      note_see_both_network_entries = "Talune reti posso avere intersezione non nulla (es. 192.168.0.128/25 e 192.168.0.0/24)",
      note_broader_network = "Un host viene associato ad una sola rete secondo il principio del longest match.",
   },
}

return {it = it}


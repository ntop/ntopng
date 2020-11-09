--
-- (C) 2020 - ntop.org
--


return {
    shell_script = "Percorso (path) dello Script",
    shell_options = "Opzioni",

    validation = {
        empty_path = "Il percorso di uno script shell non può essere vuoto.",
        invalid_path = "Percorso dello script shell non valido. Lo script deve essere nella cartella \"/usr/share/ntopng/\".",
        invalid_script = "Script non valido. Script ritenuto non sicuro.",
     },

    shell_send_error = "Errore nell'esecuzione dello script.", 

    shell_description = {
        path_description = "Istruzioni:<ul><li>Selezione lo script da eseguire</ul>Note:<ul><li>Lo script deve essere all'interno di \"/usr/share/ntopng/\"<li>Lo script verrà richiamato nel seguente modo \"script -options JSON\" dove JSON è una stringa formattata JSON contenente gli allarmi</lu>",
        option_description = "Istruzioni<ul><li>Inserire qui le opzioni che si vogliono passare allo script</ul>",
     }
 }
 
 

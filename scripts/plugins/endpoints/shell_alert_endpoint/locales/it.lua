--
-- (C) 2020 - ntop.org
--


return {
    shell_script = "Percorso (path) dello Script",
    shell_options = "Opzioni",

    validation = {
        empty_path = "Il percorso di uno script shell non può essere vuoto.",
        invalid_path = "Percorso dello script shell non valido. Lo script deve essere nella cartella \"/usr/share/ntopng/scripts/shell/\" e deve avere il suffisso .sh.",
        invalid_script = "Script non valido. Script ritenuto non sicuro.",
     },

    shell_send_error = "Errore nell'esecuzione dello script.", 

    shell_description = {
        path_description = "Note:<ul><li>Lo script deve essere contenuto in \"/usr/share/ntopng/scripts/shell/\"<li>Le opzioni dello script alert.* saranno espanse a runtime con il valore dell'allarme</lu>",
        option_description = "Istruzioni<ul><li>Inserire qui le opzioni che si vogliono passare allo script</ul>",
     }
 }
 
 

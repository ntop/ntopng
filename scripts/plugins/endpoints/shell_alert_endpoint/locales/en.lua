--
-- (C) 2020 - ntop.org
--


return {
    shell_script = "Script PATH",
    shell_options = "Options",

    validation = {
        empty_path = "Shell script path cannot be empty.",
        invalid_path = "Invalid shell script path. The script must be stored in \"/usr/share/ntopng/scripts/shell/\" and end with .sh.",
        invalid_script = "Invalid script. Script not secure.",
     },

    shell_send_error = "Error while trying to run the script.", 

    shell_description = {
        path_description = "Note:<ul><li>The script must be stored in \"/usr/share/ntopng/scripts/shell/\"<li>Alert information are provided to the script through the standard input in JSON format.</lu>",
        option_description = "Instructions<ul><li>Insert here the options with which the script is going to be executed (e.g. `-i eno1 -p 2220`)</ul>",
     }
 }
 

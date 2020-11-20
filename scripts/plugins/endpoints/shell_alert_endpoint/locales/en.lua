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
        path_description = "Note:<ul><li>The script must be stored in \"/usr/share/ntopng/scripts/shell/\"<li>The script options alert.* are expanded at runtime with the alert values</lu>",
        option_description = "Instructions<ul><li>Insert here the options you want to pass to the script</ul>",
     }
 }
 

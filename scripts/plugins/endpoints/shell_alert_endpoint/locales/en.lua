--
-- (C) 2020 - ntop.org
--


return {
    shell_script = "Script PATH",
    shell_options = "Options",

    validation = {
        empty_path = "Shell script path cannot be empty.",
        invalid_path = "Invalid shell script path. The script must be into the directory \"/usr/share/ntopng/\".",
        invalid_script = "Invalid script. Script not secure.",
     },

    shell_send_error = "Error trying to execute the script.", 

    shell_description = {
        path_description = "Instructions:<ul><li>Copy here the path your script is in</ul>Note:<ul><li>The script must be inside \"/usr/share/ntopng/\"<li>The script is going to be called following this pattern \"script -options JSON\" where JSON is a JSON formatted string containing the alarms</lu>",
        option_description = "Instructions<ul><li>Insert here the options you want to pass to the script</ul>",
     }
 }
 
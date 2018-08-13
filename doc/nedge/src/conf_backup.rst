Configuration Backup/Restore
############################

From the `System Setup` menu, into the `Misc` tab, it is possible to download the nEdge
configuartion by clicking on the `Backup Configuration` button. This downloads a copy of 
the nEdge configuration, as compressed tarball (.tar.gz), including:

- Configuration file (unless command line is used for providing the options)
- System configuration (system.config)
- Runtime configuration (runtimeprefs.json)
- /etc/ntopng folder
- License file

This backup copy can be used to restore the configuration, placing a copy of the tarball
under /etc/ntopng/conf.tar.gz and restarting the nedge service. By logging in into nEdge 
after restarting the service, it will be possible to perform the `first start` setup through
the GUI, and permanently apply the new settings. This will write the system configuration to 
disk and reboot the device. Please refer to the `First Start` section in `Getting Started`.

Please note that after restoring the configuration, the backup copy under /etc/ntopng/conf.tar.gz
is automatically deleted.


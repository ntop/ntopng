Configuration Backup
############################

From the `System Setup` menu, into the `Misc` tab, it is possible to download the nEdge
configuartion by clicking on the `Backup Configuration` button. This downloads a copy of 
the nEdge configuration, as compressed tarball (.tar.gz), including:

- Configuration file (unless command line is used for providing the options)
- System configuration (system.config)
- Runtime configuration (runtimeprefs.json)
- /etc/ntopng folder
- License file

Configuration Restore
#####################

nEdge configuration can be restored by placing the compressed tarball
(downloaded via Backup Configuration) into the nEdge data directory
and restarting the service. The tarball must be named conf.tar.gz.

For example, assuming the default /var/tmp/ntopng data directory has not been changed, one can
restore a previously backed-up configuration by placing the compressed
tarball in /var/tmp/ntopng/conf.tar.gz and then issuing a
:code:`systemctl restart nedge`.

.. note::

   After the restore, the compressed archive into the data directory
   is automatically deleted.

.. note::

   Restore is only supported for packaged ntopng installations on
   systems that use :code:`systemd`.

Commands to execute to minify and optmize the css:
```
Go to httpdocs and type:
cleancss -o css/minified/fontawesome-custom.min.css fontawesome-free-5.11.2-web/css/fontawesome.css fontawesome-free-5.11.2-web/css/brands.css fontawesome-free-5.11.2-web/css/solid.css -O2
cleancss -o css/minified/ntopng.min.css css/ntopng.css -O2
cleancss -o css/minified/heatmap.min.css css/heatmap.css css/cal-heatmap.css -O2
cleancss -o css/minified/rickshaw.min.css css/rickshaw.css -O2
cleancss -o css/minified/bootstrap-orange.min.css bootstrap-custom/ntopng-theme.css -O2
cleancss -o css/minified/dark-mode.min.css css/dark-mode.css -O2
```
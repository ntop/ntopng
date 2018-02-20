print("<script>")
print [[
function displayLocalizedError(error_code) {
  $('#mylocation').html("]] print(i18n("geo_map.geolocation_error") .. ' [\"+ error_code + \"]. ' .. i18n("geo_map.using_default_location")) print [[");
}
]]

print [[
function displayLocalizedPosition(position) {
  $('#mylocation').html("]] print(i18n("geo_map.browser_reported_home_map"))
  print(' <A HREF=\'http://maps.google.com/?q="+ default_latitude + "," + default_longitude+"\'> [' ..i18n("geo_map.latitude").. ': " + default_latitude + ", ' ..i18n("geo_map.longitude").. ': " + default_longitude + "] </A>') print [[");
}
]]

print [[
function displayLocalizedNoGeolocationMsg () {
  $('#mylocation').html("]] print(i18n("geo_map.unavailable_geolocation").. ' ' ..i18n("geo_map.using_default_location")) print [[");
}
]]
print("</script>")

print [[
<p>&nbsp;<p><small><b>]] print(i18n("geo_map.note")) print [[</b></small>
<ol>
<li> <small><i class="icon-map-marker"></i> <span id=mylocation></span></small>
<li> <small>]] print(i18n("geo_map.note_requirements_visualize_maps")) print [[:</small>
<ol>
<li> <small>]] print(i18n("geo_map.note_working_internet_connection")) print [[</small>
<li> <small>]] print(i18n("geo_map.note_compiled_ntopng_with_geolocation")) print[[</small>
<li> <small>]] print(i18n("geo_map.note_active_flows")) print[[</small>
</ol>
<li> <small>]] print(i18n("geo_map.note_html_browser_geolocation",{url="http://diveintohtml5.info/geolocation.html"})) print[[</small>
<li> <small>]] print(i18n("geo_map.note_google_maps_browser_api_key",{url_google="https://googlegeodevelopers.blogspot.it/2016/06/building-for-scale-updates-to-google.html", url_prefs=ntop.getHttpPrefix().."/lua/admin/prefs.lua?tab=misc"})) print[[</small>
</ol>
</small>
]]

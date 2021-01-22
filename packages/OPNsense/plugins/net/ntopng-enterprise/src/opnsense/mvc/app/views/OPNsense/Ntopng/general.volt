{#

Copyright (C) 2021 ntop
Based on the ntopng plugin by Michael Muenz <m.muenz@gmail.com>

OPNsense® is Copyright © 2014 – 2018 by Deciso B.V.
This file is Copyright © 2018 by Michael Muenz <m.muenz@gmail.com>
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1.  Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

2.  Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

#}

<div class="alert alert-warning" role="alert" id="missing_redis" style="display:none;min-height:65px;">
    <div style="margin-top: 8px;">{{ lang._('No Redis plugin found, please install via System > Firmware > Plugins and enable the service.')}}</div>
</div>

<!-- Navigation bar -->
<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class="active"><a data-toggle="tab" href="#general">{{ lang._('General') }}</a></li>
    <li class=""><a href="/ui/ntopng/license" style="color: #555555">{{ lang._('License') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
    <div id="general" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form",['fields':generalForm,'id':'frm_general_settings'])}}
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
	        <hr />
		<span id='ntopngLinkBox'></span>
	    </div>
        </div>
    </div>
    <div id="license" class="tab-pane fade in">
</div>

<script>
let http_prefix = "http://";
let hostname = '';
let port = 3000;

function updateNtopngURL() {
  port = document.getElementById("general.httpport").value;
  let cert = document.getElementById("general.cert").value.trim();
  if (cert !== '') http_prefix = "https://";
  let ntopng_url = http_prefix + hostname + ':' + port;
  $("#ntopngLinkBox").html("").html("Once ntopng is running <a href='" + ntopng_url + "' target='_blank'>click here to open the Web Interface</a>.");
}

$( document ).ready(function() {
    // read hostname from URL
    var l = document.createElement("a");
    l.href = window.location.href;
    hostname = l.hostname;

    var data_get_map = {'frm_general_settings':"/api/ntopng/general/get"};
    mapDataToFormUI(data_get_map).done(function(data){
        formatTokenizersUI();
        $('.selectpicker').selectpicker('refresh');
	updateNtopngURL();
    });

    updateServiceControlUI('ntopng');

    // check if Redis plugin is installed
    ajaxCall(url="/api/ntopng/service/checkredis", sendData={}, callback=function(data,status) {
	    if (data == "0") {
            $('#missing_redis').show();
        }
    });

    $("#saveAct").click(function(){
        saveFormToEndpoint(url="/api/ntopng/general/set", formid='frm_general_settings',callback_ok=function(){
            $("#saveAct_progress").addClass("fa fa-spinner fa-pulse");
            ajaxCall(url="/api/ntopng/service/reconfigure", sendData={}, callback=function(data,status) {
		updateServiceControlUI('ntopng');
                $("#saveAct_progress").removeClass("fa fa-spinner fa-pulse");
	        updateNtopngURL();
            });
        });
    });
});
</script>

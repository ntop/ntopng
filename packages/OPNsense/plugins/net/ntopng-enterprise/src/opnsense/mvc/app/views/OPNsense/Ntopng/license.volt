{#

This file is Copyright 2020 ntop
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1.  Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

2.  Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
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

<!-- Navigation bar -->
<ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
    <li class=""><a href="/ui/ntopng/general" style="color: #555555">{{ lang._('General') }}</a></li>
    <li class="active"><a data-toggle="tab" href="#license">{{ lang._('License') }}</a></li>
</ul>

<div class="tab-content content-box tab-content">
    <div id="general" class="tab-pane fade in">
    </div>
    <div id="license" class="tab-pane fade in active">
        <div class="content-box" style="padding-bottom: 1.5em;">
            {{ partial("layout_partials/base_form",['fields':licenseForm,'id':'frm_license_settings'])}}
	    <div class="table-responsive">
                <table class="table table-striped table-condensed">
		<colgroup>
                    <col class="col-md-3">
                    <col class="col-md-4">
                    <col class="col-md-5">
                </colgroup>
                <tbody>
                    <tr>
                        <td>
                            <div class="control-label">
                                <b>{{ lang._('Version') }}</b>
                            </div>
                        </td>
                        <td>
				<span id="versionBox"></span>
                        </td>
			<td></td>
                    </tr>
                    <tr>
                        <td>
                            <div class="control-label">
                                <b>{{ lang._('System ID') }}</b>
                            </div>
                        </td>
                        <td>
				<span id="systemidBox"></span>
                        </td>
			<td></td>
                    </tr>
                    <tr>
                        <td>
                            <div class="control-label">
                                <b>{{ lang._('Edition') }}</b>
                            </div>
                        </td>
                        <td>
				<span id="editionBox"></span>
                        </td>
			<td></td>
                    </tr>
                    <tr>
                        <td>
                            <div class="control-label">
                                <b>{{ lang._('License Status') }}</b>
                            </div>
                        </td>
                        <td>
				<span id="licenseBox"></span>
                        </td>
			<td></td>
                    </tr>
                    <tr>
                        <td>
                            <div class="control-label">
                                <b>{{ lang._('Maintenance') }}</b>
                            </div>
                        </td>
                        <td>
				<span id="maintenanceBox"></span>
                        </td>
			<td></td>
                    </tr>
                </tbody>
                </table>
	    </div>
            <div class="col-md-12">
                <hr />
                <button class="btn btn-primary" id="saveAct" type="button"><b>{{ lang._('Save') }}</b> <i id="saveAct_progress"></i></button>
	        <hr />
		<span id='shopLinkBox'></span>
            </div>
        </div>
    </div>
</div>

<script>
function updateLicenseInfo() {
    ajaxCall(url="/api/ntopng/license/info", sendData={}, callback=function(data, status) {
        let version = data['version'].trim();
	let systemid = data['systemid'].trim();
	let edition = data['edition'].trim();
	let license = data['license'].trim();
	let maintenance = data['maintenance'].trim();

	if (version !== '' && systemid !== '') {
            $("#shopLinkBox").html("").html("Go to the " +
	    "<a href='https://shop.ntop.org' target='_blank'>e-shop</a>" +
	    " to purchase a license, then go to the " +
	    "<a href='https://shop.ntop.org/mkntopng/?systemid=" + systemid + "&version=" + version + "&edition=enterprise' target='_blank'>license generator</a>" +
	    " to generate an Enterprise license.");
	}

	if (version === '') version = 'Unable to read the ntopng version';
	if (systemid === '') systemid = 'Unable to read the System ID';
	if (license === '') license = 'Not found';
	if (maintenance === '') maintenance = '-';

        $("#versionBox").html(version);
        $("#systemidBox").html(systemid);
        $("#editionBox").html(edition);
        $("#licenseBox").html(license);
        $("#maintenanceBox").html(maintenance);
    });
}

$( document ).ready(function() {
    var data_get_map = {'frm_license_settings':"/api/ntopng/license/get"};
    mapDataToFormUI(data_get_map).done(function(data){
        formatTokenizersUI();
        $('.selectpicker').selectpicker('refresh');
    });

    $("#saveAct").click(function(){
        saveFormToEndpoint(url="/api/ntopng/license/set", formid='frm_license_settings',callback_ok=function(){
            $("#saveAct_progress").addClass("fa fa-spinner fa-pulse");
            ajaxCall(url="/api/ntopng/service/reconfigure", sendData={}, callback=function(data,status) {
                $("#saveAct_progress").removeClass("fa fa-spinner fa-pulse");
                updateLicenseInfo();
            });
        });
    });

    updateLicenseInfo();
});
</script>

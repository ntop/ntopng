$(document).ready(function() {

    $("button[data-toggle='sidebar']").click(function(){

        $("#n-container").toggleClass("extended")
        $("#n-sidebar, #ntop-logo").toggleClass("active")

        $(`div[id$='-submenu']`).toggleClass('side-collapse');

        if (!$('#n-sidebar').hasClass('active')) {
            $("#ntop-logo").fadeToggle(function () {
                $('.squared-logo').fadeToggle();
            });
        }
        else {
            $(".squared-logo").fadeToggle(function () {
                $('#ntop-logo').fadeToggle();
            });
        }

    });

});
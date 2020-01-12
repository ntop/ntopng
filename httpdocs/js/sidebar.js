$(document).ready(function() {

    $("button[data-toggle='sidebar']").click(function(){

        $("#n-container").toggleClass("extended")
        $("#n-sidebar, #ntop-logo").toggleClass("active")

        if (!window.matchMedia('(max-width: 575.98px)').matches) {
            $(`div[id$='-submenu']`).toggleClass('side-collapse');
        }
        else {

            if (!$('#n-sidebar').hasClass('active')) {
            
                $('#n-sidebar').css('width', $(window).width())
                $('#n-sidebar').css('height', $(window).height())
                $('html, body').css('overflow', 'hidden')

            }
            else {

                $('#n-sidebar').css('width', 0)
                $('html, body').css('overflow', '')

            }
        }

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

    $("#n-sidebar a[data-toggle='collapse']").click(function() {
        
        if (window.matchMedia('(max-width: 575.98px)').matches) return;

        const $submenu = $(this).parent().find(`div[id$='-submenu']`);

        if ($('#n-sidebar').hasClass('active')) {
            $submenu.css('top', '');
            return;
        }
        
        const {y} = $(this)[0].getBoundingClientRect();
        $submenu.css({top: `${y}px`});


    });

});

$(window).resize(function() {

    if (!window.matchMedia('(max-width: 575.98px)').matches) return;

    if (!$('#n-sidebar').hasClass('active')) {
        $('#n-sidebar').css('width', $(window).width())
        $('#n-sidebar').css('height', $(window).height())
    }
})
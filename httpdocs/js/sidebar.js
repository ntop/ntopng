$(window).ready(function() {

    const sidebar_dark = localStorage.getItem('sidebar-dark');
    if (sidebar_dark) {
        $('#n-sidebar').removeClass('bg-light').addClass('bg-dark');
    }

    if (window.matchMedia('(max-width: 575.98px)').matches) return;

    // get collapsing sidebar info from local storage
    const sidebar_collapsed = localStorage.getItem('sidebar-collapsed');
    // if the sidebar_collapsed property is null it means that has not been set yet
    if (sidebar_collapsed != null && sidebar_collapsed != undefined) {
        // if the sidebar is collapsed then remove the active class from the sidebar
        if (sidebar_collapsed) {
            $("#n-sidebar").removeClass('active');
            $("#n-container").addClass("extended")
            $('#ntop-logo-t,#ntop-logo-o,#ntop-logo-p').hide();
            $(`div[id$='-submenu']`).toggleClass('side-collapse').toggleClass('fade');
            $(`#n-sidebar button[data-toggle='sidebar']`).hide();
            $(`#n-container button[data-toggle='sidebar']`).removeClass('d-none').fadeIn();
        }
        else {
            $("#n-sidebar").addClass('active');
            $("#n-container").removeClass("extended")
        }
    }

})

$(window).resize(function() {

    if (!window.matchMedia('(max-width: 575.98px)').matches) return;

    if (!$('#n-sidebar').hasClass('active')) {
        $('#n-sidebar').css('width', $(window).width())
        $('#n-sidebar').css('height', $(window).height())
    }
})

$(document).ready(function() {

    $("#toggle-theme").click(function() {

        $('#n-sidebar').toggleClass('bg-light').toggleClass('bg-dark');

        const is_dark = $('#n-sidebar').hasClass('bg-dark');
        if (is_dark) {
            localStorage.setItem('sidebar-dark', is_dark);
        }
        else {
            localStorage.removeItem('sidebar-dark');
        }
    })

    $("button[data-toggle='sidebar']").click(function(){

        const ntop_logo = {
            'n': $('#ntop-logo-n'),
            't': $('#ntop-logo-t'),
            'o': $('#ntop-logo-o'),
            'p': $('#ntop-logo-p'),
        };

        const fade_delay = 100;

        $("#n-container").toggleClass("extended");
        $("#n-sidebar, #ntop-logo").toggleClass("active");

        // handle locale storage for collapsing
        const collapsed = !$('#n-sidebar').hasClass('active');

        if (collapsed) {
            localStorage.setItem('sidebar-collapsed', collapsed);
        }
        else {
            localStorage.removeItem('sidebar-collapsed');
        }

        if (!window.matchMedia('(max-width: 575.98px)').matches) {
            $(`div[id$='-submenu']`).toggleClass('side-collapse').toggleClass('fade');
        }
        else {

            if (!$('#n-sidebar').hasClass('active')) {
            
                $('#n-sidebar').css('width', $(window).width());
                $('#n-sidebar').css('height', $(window).height());
                $('html, body').css('overflow', 'hidden');
            }
            else {

                $('#n-sidebar').css('width', 0);
                $('html, body').css('overflow', '');
            }
        }

        if (!$('#n-sidebar').hasClass('active')) {

            $(`#n-sidebar button[data-toggle='sidebar']`).hide();
            $(`#n-container button[data-toggle='sidebar']`).removeClass('d-none').fadeIn();

            ntop_logo.p.fadeOut(fade_delay, 
                () => ntop_logo.o.fadeOut(fade_delay, 
                    () => ntop_logo.t.fadeOut(fade_delay)));
        }
        else {

            $(`#n-container button[data-toggle='sidebar']`).hide();

            ntop_logo.t.fadeIn(fade_delay, 
                () => ntop_logo.o.fadeIn(fade_delay, 
                    () => ntop_logo.p.fadeIn(fade_delay, () => {
                        $(`#n-sidebar button[data-toggle='sidebar']`).fadeIn();
            })));
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


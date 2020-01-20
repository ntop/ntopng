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
            $("#n-container, #n-navbar").addClass("extended")
            $('#ntop-logo-t,#ntop-logo-o,#ntop-logo-p').hide();
            $(`div[id$='-submenu']`).toggleClass('side-collapse').toggleClass('fade');
            $('#collapse-sidebar').find('span').text('');
        }
        else {
            $("#n-sidebar").addClass('active');
            $("#n-container, #n-navbar").removeClass("extended")
        }
    }
    
})

$(window).resize(function() {   

    fix_current_submenu_position();
})

$(document).ready(function() {
    
    // toggle button collapse visibility
    $('#collapse-sidebar').on('click', function() {
        // hide span
        $(this).fadeOut(250, function(e) {
            
            $(this).toggleClass('active');
            
            if (!$('#n-sidebar').hasClass('active')) {
                $(this).find('span').text('').hide();
            }
            else {
                $(this).find('span').text('Collapse').show();
            }
            
            $(this).fadeIn(250);
        });
    });
    
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
    
    $("[data-toggle='sidebar']").click(function(){
        
        $("#n-container, #n-navbar").toggleClass("extended");
        $("#n-sidebar, #ntop-logo").toggleClass("active");
        
        // handle locale storage for collapsing
        handle_collapse_info();
        
        // disable overflow when the sidebar is open in mobile device
        if (is_mobile_device()) {
            $('html,body').toggleClass('no-scroll');
        }
        else {
            $(`div[id$='-submenu']`).toggleClass('side-collapse').toggleClass('fade');
            fix_current_submenu_position();
        }


        toggle_logo_animation();
        
    });
    
    $("#n-sidebar a[data-toggle='collapse']").click(function() {
        
        if (window.matchMedia('(max-width: 575.98px)').matches) return;
        
        const $submenu = $(this).parent().find(`div[id$='-submenu']`);
        
        if ($('#n-sidebar').hasClass('active')) {
            $submenu.css('top', '');
            return;
        }
        
        const delta_menu_button = $(this)[0].getBoundingClientRect().y;
        handle_submenu_height($submenu, delta_menu_button);
        
    });
    
});

const toggle_logo_animation = () => {

    const ntop_logo = {
        'n': $('#ntop-logo-n'),
        't': $('#ntop-logo-t'),
        'o': $('#ntop-logo-o'),
        'p': $('#ntop-logo-p'),
    };
    
    const fade_delay = 100;

    if (!$('#n-sidebar').hasClass('active')) {
        ntop_logo.p.fadeOut(fade_delay, () => ntop_logo.o.fadeOut(fade_delay, () => ntop_logo.t.fadeOut(fade_delay)));
    }
    else {
        ntop_logo.t.fadeIn(fade_delay, () => ntop_logo.o.fadeIn(fade_delay, () => ntop_logo.p.fadeIn(fade_delay)));
    }
}

const fix_current_submenu_position = () => {
    
    // handle resize of submenu oustide the sidebar if it is collapsed
    const sidebar_collapsed = !$('#n-sidebar').hasClass('active');
    const $current_submenu = $('.side-collapse.show');

    if (sidebar_collapsed && $current_submenu != undefined) {

        const $submenu_parent = $current_submenu.parent().find('a');
        if ($submenu_parent[0] == undefined) return;

        const delta_menu_button = $submenu_parent[0].getBoundingClientRect().y;
        handle_submenu_height($current_submenu, delta_menu_button);
    }
}

const handle_submenu_height = ($submenu, delta_menu_button) => {

    const height_submenu = $submenu.height();
    const delta_between = $(window).height() - delta_menu_button;

    $submenu.css({ top: `${delta_menu_button}px` });
    
    const is_greater_than_page = delta_menu_button + height_submenu > $(window).height();

    if ($submenu.hasClass('show') && is_greater_than_page) {
        $submenu.css({'overflow-y': `auto`,'height': `${delta_between}px`});
        return;
    }
    else if ($submenu.hasClass('show') && !is_greater_than_page) {
        $submenu.css({'overflow-y': `visible`, 'height': `auto`});
        return;
    }
    
    // action to execute once the collapsible area is expanded
    // if the sidebar menu is more tall than the page height,
    // then apply an overflow on submenu
    $submenu.on('shown.bs.collapse', function (e) {
        
        if (is_greater_than_page) {
            $submenu.css({'overflow-y': `auto`,'height': `${delta_between}px`});
        }
    });
}

const is_mobile_device = () => {
    return window.matchMedia('(min-width: 320px) and (max-width: 480px) ').matches;
}

const handle_collapse_info = () => {

    const collapsed = !$('#n-sidebar').hasClass('active');
    
    if (collapsed) {
        localStorage.setItem('sidebar-collapsed', collapsed);
        return;
    }

    localStorage.removeItem('sidebar-collapsed');
}


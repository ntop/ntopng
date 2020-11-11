const fixSubMenuPosition = ($submenu, $hoverButton) => {

    const MIN_SPACE = 20;
    const MIN_HEIGHT = 150;

    let distFromAbove = $hoverButton.position().top;
    const submenuHeight = $submenu.height();
    const documentHeight = $(window).height();

    // if the submenu is too high to be shown then set
    // the overflow on y axis
    if (submenuHeight + distFromAbove >= documentHeight) {

        const currentSubmenuHeight = documentHeight - distFromAbove;
        if (currentSubmenuHeight <= MIN_HEIGHT) {
            distFromAbove = distFromAbove - submenuHeight + $hoverButton.outerHeight();
        }
        else {
            $submenu.css({'max-height': currentSubmenuHeight - MIN_SPACE, 'overflow-y': 'auto'})
        }

    }

    // set the submenu height
    $submenu.css('top', `${distFromAbove}px`);

};

$(window).scroll(function(){

    const UPPER_LIMIT = 32;
    const navbarHeight = $(`#n-navbar`).height();
    const windowScrollTop = $(this).scrollTop();

    if (windowScrollTop >= UPPER_LIMIT) {
        $(`#n-navbar`).addClass("scrolled bg-light");
    }
    else {
        $(`#n-navbar`).removeClass("scrolled bg-light");
    }

});

$(document).ready(() => {

    const toggleSidebar = () => {
        // if the layer doesn't exists then create it
        if ($(`.sidebar-close-layer`).length == 0) {

            const $layer = $(`<div class='sidebar-close-layer' style='display:none'></div>`);
            // when the user clicks on the layer
            $layer.click(function(){
                // remove active class from sidebar
                $(`#n-sidebar`).removeClass('active');
                // hide the layer and remove it from the DOM
                $layer.fadeOut(function() {
                    $(this).remove();
                });
            });

            // append the layer to the wrapper
            $(`#wrapper`).append($layer);
            // show the layer inside the page
            $layer.fadeIn();
        }
        else {
            // hide the existing layer and destroy it
            $(`.sidebar-close-layer`).fadeOut(function() {
                $(this).remove();
            });
        }

        // show/hide the sidebar
        $(`#n-sidebar`).toggleClass('active');
    }

    $(`#n-sidebar a.submenu`).mouseenter(function() {

        const $submenu = $(this).parent().find(`div[id$='submenu']`);
        fixSubMenuPosition($submenu, $(this));
        $submenu.collapse('show');

        $(this).attr('aria-expanded', true);
    });

    $(`div[id$='submenu']`).mouseenter(function() {
        $(this).addClass('show');
    });
    $(`div[id$='submenu']`).mouseleave(function() {
        $(this).removeClass('show');
        $(this).css({'max-height': 'initial'});
    });

    $(`#n-sidebar a.submenu`).mouseleave(function() {
        const $submenu = $(this).parent().find(`div[id$='submenu']`);
        $submenu.removeClass('show');
        $(this).attr('aria-expanded', false);
    });

    /* toggle sidebar display */
    $(`button[data-toggle='sidebar']`).click(function() {
        toggleSidebar();
    });

    $(`#iface-select`).change(function() {

        const action = $(this).val();
        const $form = $(this).parents('form');

        $form.attr('action', action);

        if (!systemInterfaceEnabled) {
            toggleSystemInterface(true);
        }
        else {
            toggleSystemInterface(false, $form);
        }

    });

});

$(window).resize(function() {

    // re-calc submenu height
    const $currentSubmenu = $('#n-sidebar').find(`div.show[id$='submenu']`);

    if ($currentSubmenu.length > 0) {

        const $hoverButton = $currentSubmenu.parent().find(`a[data-toggle='collapse']`);
        fixSubMenuPosition($currentSubmenu, $hoverButton);
    }

});

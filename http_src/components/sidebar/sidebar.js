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

$(window).on('scroll', function(){

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

$(() => {

    const toggleSidebar = () => {
        // if the layer doesn't exists then create it
        if ($(`.sidebar-close-layer`).length == 0) {

            const $layer = $(`<div class='sidebar-close-layer' style='display:none'></div>`);
            // when the user clicks on the layer
            $layer.on('click', function(){
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

    $('#n-sidebar a.submenu').bind({
        mouseenter: function() {
            let submenu = $(this).parent().find(`div[id$='submenu']`);
            fixSubMenuPosition(submenu, $(this));
            submenu.show()
        },
        mouseleave: function() {
            let submenu = $(this).parent().find(`div[id$='submenu']`);
            submenu.hide();
        }
    });

    $(`div[id$='submenu']`).bind({
        mouseenter: function() {
            $(this).show()
        },
        mouseleave: function() {
            $(this).hide();
        }
    });

    /* toggle sidebar display */
    $(`button[data-bs-toggle='sidebar']`).on('click', function() {
        toggleSidebar();
    });
});

$(window).on('resize', function() {

    // re-calc submenu height
    const $currentSubmenu = $('#n-sidebar').find(`div.show[id$='submenu']`);

    if ($currentSubmenu.length > 0) {

        const $hoverButton = $currentSubmenu.parent().find(`a[data-bs-toggle='collapse']`);
        fixSubMenuPosition($currentSubmenu, $hoverButton);
    }

});

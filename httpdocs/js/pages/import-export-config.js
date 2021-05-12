$(function() {

    $(`#btn-import-config`).click(function() {

        const selectedItem = $(`input[name='item']`).val();
        const itemLabel = $(`label[for='radio-${selectedItem}']`).text();
        $(`#import-modal span.item`).text(itemLabel);
    });

    // on item change updates export link
    $(`input[name='item']`).change(function() {

        // change selected item to export
        const item = $(this).val();
        const href = $(`#btn-export-config`).attr('href');
        const currentURL = new URL(href, window.location.origin);
        currentURL.searchParams.set('item', item);

        if (item == "all") {
            $(`#import-export`).hide();
            $(`#backup-restore`).show();
            return;
        }

        $(`#backup-restore`).hide();
        $(`#import-export`).show();

        // update the new export link
        $(`#btn-export-config`).attr('href', currentURL.toString());
    });

});

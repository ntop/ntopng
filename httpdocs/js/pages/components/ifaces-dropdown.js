$(function() {

    // initialize the selectpicker
    $('#interfaces-dropdown').selectpicker();

    $(`#iface-select`).on('change', function(e) {
        const selectedValue = $(this).val();
        toggleSystemInterface($('#switch_interface_form_' + selectedValue));
    });

    $("#interfaces-dropdown").on("changed.bs.select", function(e, clickedIndex, isSelected, oldValue) {
        
        if (clickedIndex == null && isSelected == null) {
            return;
        } 

        const selectedValue = $(this).find('option').eq(clickedIndex).val();  
        toggleSystemInterface($('#switch_interface_form_' + selectedValue));
    });
});

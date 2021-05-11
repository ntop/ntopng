$(document).ready(function() {

    // initialize the selectpicker
    $('#interfaces-dropdown').selectpicker();

    $("#interfaces-dropdown").on("changed.bs.select", function(e, clickedIndex, isSelected, oldValue) {
        
        if (clickedIndex == null && isSelected == null) {
            return;
        } 

        const selected_value = $(this).find('option').eq(clickedIndex).val();  
        toggleSystemInterface(false, $('#switch_interface_form_' + selected_value));
    });
});

$(function() {

    // initialize the selectpicker
    $('#interfaces-dropdown').selectpicker();

    $("#interfaces-dropdown").on("changed.bs.select", function(e, clickedIndex, isSelected, oldValue) {
        
        if (clickedIndex == null && isSelected == null) {
            return;
        } 

        const selectedValue = $(this).find('option').eq(clickedIndex).val();  
        if (selectedValue === "system") {
            toggleSystemInterface(true);
            return;
        }

        toggleSystemInterface(false, $('#switch_interface_form_' + selectedValue));
    });
});

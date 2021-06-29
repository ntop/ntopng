$(function() {

    // initialize the selectpicker
    $('#interfaces-dropdown').selectpicker();

    $(`#iface-select`).on('change', function(e) {
        const selectedValue = $(this).val();
        toggleSystemInterface($('#switch_interface_form_' + selectedValue));
    });

    const toggleObservationPoint = ($form = null) => {
	if($form != null) {
	    $form.submit();
	}
	else {
	    console.error("An error has occurred when switching interface!");
	}
    }
    
    $(`#observationpoint-dropdown`).on('change', function(e) {
        const selectedValue = $(this).val();
        $('#switch_interface_form_observation_point_'+selectedValue).submit();
    });

    $("#interfaces-dropdown").on("changed.bs.select", function(e, clickedIndex, isSelected, oldValue) {
        
        if (clickedIndex == null && isSelected == null) {
            return;
        } 

        const selectedValue = $(this).find('option').eq(clickedIndex).val();  
        toggleSystemInterface($('#switch_interface_form_' + selectedValue));
    });
});

$(function() {

    // initialize the selectpicker
    $('#interfaces-dropdown').selectpicker();

    const toggleObservationPoint = ($form = null) => {
	if($form != null) {
	    $form.submit();
	} else {
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
        if(isNaN(Number(selectedValue)) ){
            window.location.replace(selectedValue);
        }else{
            toggleSystemInterface($('#switch_interface_form_' + selectedValue));
        }
    });
});

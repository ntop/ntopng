$(function () {
  $('#interfaces-dropdown').selectpicker();
  $("#interfaces-dropdown").on("changed.bs.select", function(e, clickedIndex, isSelected, oldValue) {
      if (clickedIndex == null && isSelected == null) {
          const selectedItems = ($(this).selectpicker('val') || []).length;
          const allItems = $(this).find('option:not([disabled])').length;
          if (selectedItems == allItems) {
              // console.log('selected all');
          } else {
              // console.log('deselected all');
          }
      } else {
          const selectedD = $(this).find('option').eq(clickedIndex).text();
	  const selected_value = $(this).find('option').eq(clickedIndex).val();
          // console.log('selectedD: ' + selectedD +  ' selected value: ' + selected_value + '  oldValue: ' + oldValue);

          if(selected_value == "system")
	      toggleSystemInterface(true);
          else
              toggleSystemInterface(false, $('#maina_switch_interface_form_' + selected_value));
      }
  });
});


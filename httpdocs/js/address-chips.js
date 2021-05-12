(function($) {
 
    $.fn.chips = function(action) {

        if (action == 'val') {
            return chips_to_array(this);
        }

        const self = this;
        this.chips_already_created = [];

        // add event handler on space press
        this.find(`input[type='text']`).on('keyup', function(e) {
            
            if (e.key != "Enter") return;

            const chips_created = tokenize_input($(this).val(), self.chips_already_created);
            
            // clean the input box 
            $(this).val('');

            self.find('.chips-container').prepend(chips_created);
            
        });

        return this;
    };


    const chips_to_array = ($chips_container) => {

        const chips = $chips_container.find('.chip');
        const data = [];

        // for each chips inside the container take the correct value
        chips.each(function(index) {

            // take data-value from current chips
            const $current_chip = $(this);
            data.push($current_chip.data('value'));
        });

        return data;
    }

    /**
     * Tokenize the input string into chips and delegate events to them
     * @param {string} input the string that will be tokenized in chips
     */
    const tokenize_input = (input, chips_created) => {

        // check input value
        if (input == undefined || input == null || input == "") return;

        // clean string from space
        const cleaned_input = input.trim();
        // split each address by comma
        const addresses = cleaned_input.split(',');

        const chips = addresses.map((value) => {

            if (value == "") return;
            // check if the chip with this value has been created
            if (chips_created.find(v => $(v).data('value') == value)) return;

            const $chip = $(`
                <div class='chip badge bg-light'>
                    ${value} 
                    <i class='fas fa-times'></i>
                </div>
            `);

            $chip.data('value', value);
            // on click delete the chip
            $chip.find('i').on('click', function() {
                // remove entry from chips created array
                chips_created = chips_created.filter(v => v != value);
                // delete chip
                $(this).parent().remove();
            });

            // add new value inside the array
            chips_created.push($chip);

            return $chip;
        });

        return chips;

    };

    

}(jQuery));
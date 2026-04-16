/*
  (C) 2013-23 - ntop.org
 */

/* ******************************************************************** */

function format_num_for_sort(num) {
    if (typeof num === "number") {
        /* Check if it's a number */
        return num;
    } else if (typeof num === "string") {
        if (num == "") {
            /* Safety check */
            return 0;
        }

        /* If it's a string convert it into a number */
        num = num.split(',').join("");
        num = parseInt(num);
    } else {
        /* In case both failed, convert num to 0 */
        num = 0;
    }

    return num;
}

// max number value for sort number with normalize option 
// for cases: last scan and last duration column to handle empty values
const MAX_NUMBER_VALUE = 99999999999;

const normalize_number_value = function (lower_value, val, sort) {
    if (val == lower_value) {
        if (sort == 1) {
            val = MAX_NUMBER_VALUE;
        }
    }
    return val;
}
/* ******************************************************************** */

const sortByName = function (val_1, val_2, sort) {
    // Convert the values into number, to see if they are numbers or not
    const num1 = Number(val_1);
    const num2 = Number(val_2);

    const isNumeric1 = !isNaN(num1) && val_1 !== null && val_1 !== '';
    const isNumeric2 = !isNaN(num2) && val_2 !== null && val_2 !== '';

    /* Both are numbers */
    if (isNumeric1 && isNumeric2) {
        return sortByNumber(num1, num2, sort);
    }

    /* At least a string */
    const str1 = (val_1 ?? '').toString();
    const str2 = (val_2 ?? '').toString();

    if (sort === 1) {
        if (!str1) return -1;
        if (!str2) return 1;
        return str1.localeCompare(str2, undefined, { numeric: true, sensitivity: 'base' });
    }

    if (!str1) return 1;
    if (!str2) return -1;
    return str2.localeCompare(str1, undefined, { numeric: true, sensitivity: 'base' });
};

/* ******************************************************************** */

/* Sort by IP Addresses */
const sortByIP = function (val_1, val_2, sort) {
    val_1 = String(NtopUtils.convertIPAddress(val_1));
    val_2 = String(NtopUtils.convertIPAddress(val_2));
    if (sort == 1) {
        return val_1.localeCompare(val_2);
    }
    return val_2.localeCompare(val_1);
}

/* ******************************************************************** */

/* Sort by MAC Addresses */
const sortByMacAddress = function (val_1, val_2, sort) {
    val_1 = NtopUtils.convertMACAddress(val_1);
    val_2 = NtopUtils.convertMACAddress(val_2);
    if (sort == 1) {
        return val_1.localeCompare(val_2);
    }
    return val_2.localeCompare(val_1);
}

/* ******************************************************************** */

/* Sort by Number */
const sortByNumber = function (val_1, val_2, sort) {
    /* It's an array */
    val_1 = format_num_for_sort(val_1);
    val_2 = format_num_for_sort(val_2);

    if (sort == 1) {
        return val_1 - val_2;
    }
    return val_2 - val_1;
}

/* ******************************************************************** */

/* Sort by Number after values normalization */
const sortByNumberWithNormalizationValue = function (val_1, val_2, sort, lower_value) {
    val_1 = normalize_number_value(lower_value, val_1, sort);
    val_2 = normalize_number_value(lower_value, val_2, sort);

    return sortByNumber(val_1, val_2, sort);
}

/* ******************************************************************** */

/* Sort by Array Length */
const sortByArrayLength = function (val_1, val_2, sort) {
    const len1 = Array.isArray(val_1) ? val_1.length : 0;
    const len2 = Array.isArray(val_2) ? val_2.length : 0;

    if (sort == 1) {
        return len1 - len2;
    }
    return len2 - len1;
}

/* ******************************************************************** */

const sortingFunctions = function () {
    return {
        sortByIP,
        sortByName,
        sortByNumber,
        sortByMacAddress,
        sortByNumberWithNormalizationValue,
        sortByArrayLength,
    };
}();

export default sortingFunctions;
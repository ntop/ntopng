/*
  (C) 2013-23 - ntop.org
 */

/* ******************************************************************** */ 

function format_num_for_sort(num) {
  if(typeof num === "number") {
    /* Check if it's a number */
    return num;
  } else if(typeof num === "string") {
    if(num == "") {
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

const normalize_number_value = function(lower_value, val, sort) {
  if (val == lower_value) {
    if (sort == 1) {
      val = MAX_NUMBER_VALUE;
    }
  }    
  return val; 
}
/* ******************************************************************** */ 

/* Sort by Name */
const sortByName = function(val_1, val_2, sort) {
  if (sort == 1) {
    return val_1?.localeCompare(val_2);
  }
  return val_2?.localeCompare(val_1);
}

/* ******************************************************************** */ 

/* Sort by IP Addresses */
const sortByIP = function(val_1, val_2, sort) {
  val_1 = NtopUtils.convertIPAddress(val_1);
  val_2 = NtopUtils.convertIPAddress(val_2);
  if (sort == 1) {
    return val_1.localeCompare(val_2);
  }
  return val_2.localeCompare(val_1);
}

/* ******************************************************************** */ 

/* Sort by MAC Addresses */
const sortByMacAddress = function(val_1, val_2, sort) {
  val_1 = NtopUtils.convertMACAddress(val_1);
  val_2 = NtopUtils.convertMACAddress(val_2);
  if (sort == 1) {
    return val_1.localeCompare(val_2);
  }
  return val_2.localeCompare(val_1);
}

/* ******************************************************************** */ 

/* Sort by Number */
const sortByNumber = function(val_1, val_2, sort) {
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
const sortByNumberWithNormalizationValue = function(val_1, val_2, sort, lower_value) {
  val_1 = normalize_number_value(lower_value, val_1, sort);
  val_2 = normalize_number_value(lower_value, val_2, sort);

  return sortByNumber(val_1,val_2,sort);
}

/* ******************************************************************** */ 

const sortingFunctions = function () {
  return {
    sortByIP,
    sortByName,
    sortByNumber,
    sortByMacAddress,
    sortByNumberWithNormalizationValue,
  };
}();

export default sortingFunctions;
/*
  (C) 2013-23 - ntop.org
 */

/*
  Here a list of functions used to check, format data;
  e.g. functions that check if a string is null or empty
 */

/* This function check if value is null, empty or 0 */
const isEmptyOrNull = (value) => {
  return !!(value == null || value == "" || value == 0);
}

/* ******************************************************************** */

const dataUtils = function () {
  return {
    isEmptyOrNull,
  };
}();

export default dataUtils;


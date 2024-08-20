/*
  (C) 2013-23 - ntop.org
 */

/*
  Here a list of functions used to check, format data;
  e.g. functions that check if a string is null or empty
 */

/* This function check if value is not set (null or empty).
 * Do not check for 0 as it may be a valid value. */
const isEmptyOrNull = (value) => {
  return !!(value == null || value == "");
}

/* This function check if value is null, or an empty array */
const isEmptyArrayOrNull = (value) => {
  return !!(value == null || value.length === 0);
}

/* ******************************************************************** */

const dataUtils = function () {
  return {
    isEmptyOrNull,
    isEmptyArrayOrNull,
  };
}();

export default dataUtils;


const _i18n = (t) => i18n(t);

function wrap_datatable_columns_config(datatable_columns) {
    return function (col) {
	let name = _i18n(col.name);
	if (name == null || name == "") {
	    return "Test";
	}
	return `${name}`;
    }
}

const table_utils = {
    wrap_datatable_columns_config,
};

export default table_utils;

function get_filters_object(filters) {
    let filters_groups = {};
    filters.forEach((f) => {
        let group = filters_groups[f.id];
        if (group == null) {
            group = [];
            filters_groups[f.id] = group;
        }
        group.push(f);
    });
    let filters_object = {};
    for (let f_id in filters_groups) {
        let group = filters_groups[f_id];
        let filter_values = group.filter((f) => f.value != null && f.operator != null && f.operator != "").map((f) => `${f.value};${f.operator}`).join(",");
        filters_object[f_id] = filter_values;
    }
    return filters_object;
}

const filtersManager = function () {
    return {
	get_filters_object
    };
}();

export default filtersManager;

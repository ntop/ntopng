/**
    (C) 2022 - ntop.org
*/
//import { ntopng_utility } from '../services/context/ntopng_globals_services';

function tsInterfaceToApexOptions(tsInterface) {
    let startTime = tsInterface.start;
    let step = tsInterface.step * 1000;
    tsInterface.series.forEach((s) => {
	let time = startTime * 1000;;
	s.data = s.data.map((d) => {
	    let d2 = { x: time, y: d };
	    time += step;
	    return d2;
	});
    });
}

const ntopChartOptionsUtility = function() {
    return {
	tsInterfaceToApexOptions: tsInterfaceToApexOptions,
    };
}();

export { ntopChartOptionsUtility };

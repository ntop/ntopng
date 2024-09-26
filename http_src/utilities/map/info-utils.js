/*
  (C) 2013-24 - ntop.org
 */

const flowInfo = {
    'Audio': "<i class='fa fa-lg fa-volume-up'></i>",
    'Video': "<i class='fa fa-lg fa-video'></i>",
    'Desktop Sharing': "<i class='fa fa-lg fa-binoculars'></i>",
}

/* *********************************** */

const addFlowInfoIcon = function(info) {
    let formatted_info = info;

    if (info && flowInfo[info]) {
        formatted_info = `${flowInfo[info]} ${info}`;
    }
    return formatted_info;
}

/* *********************************** */

const infoUtils = function () {
    return {
        addFlowInfoIcon
    };
}();

export default infoUtils;
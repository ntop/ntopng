/*
  (C) 2013-24 - ntop.org
 */

const breed_icon = {
    Safe: "<i class='fas fa-thumbs-up'></i>",
    Acceptable: "<i class='fas fa-thumbs-up'></i>",
    Fun: "<i class='fas fa-smile'></i>",
    Unsafe: "<i class='fas fa-thumbs-down'></i>",
    Dangerous: "<i class='fas fa-exclamation-triangle'></i>"
}

const confidence_icons = [
    { id: -1, icon_class: "badge bg-warning" }, /* Unknown */
    { id: 0, icon_class: "badge bg-warning" }, /* Guessed */
    { id: 1, icon_class: "badge bg-success" }, /* DPI */
]

const encrypted_icon = "<i class='fas fa-lock'></i>"

/* *********************************** */

const formatBreedIcon = function(breed, is_encrypted) {
    let icon = ''
    if(breed_icon[breed]) {
        icon = breed_icon[breed]
    }
    return is_encrypted ? `${icon} ${encrypted_icon}` : icon
}

/* *********************************** */

const formatConfidence = function(confidence, confidence_id) {
    let confidence_string = ''
    confidence_icons.forEach((el) => {
        if(Number(el.id) === Number(confidence_id)) {
            confidence_string = `<span class="${el.icon_class}" title="${confidence}">${confidence}</span>`
        }
    })
    return confidence_string
}

/* *********************************** */

const protocolUtils = function () {
    return {
        formatBreedIcon,
        formatConfidence
    };
}();

export default protocolUtils;
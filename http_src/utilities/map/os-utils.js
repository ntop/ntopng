/*
  (C) 2013-24 - ntop.org
 */

const os = [
   { name: "Unknown", icon: '' },
   { name: "Linux", icon: '<i class=\'fab fa-linux fa-lg\'></i>' },
   { name: "Windows", icon: '<i class=\'fab fa-windows fa-lg\'></i>' },
   { name: "MacOS", icon: '<i class=\'fab fa-apple fa-lg\'></i>' },
   { name: "iOS", icon: '<i class=\'fab fa-apple fa-lg\'></i>' },
   { name: "Android", icon: '<i class=\'fab fa-android fa-lg\'></i>' },
   { name: "LaserJET", icon: 'LasetJET' },
   { name: "AppleAirport", icon: 'Apple Airport' }
]

const asset_icons = [
   { id: 'unknown', icon: '', name: i18n("device_types.unknown") },
   { id: 'printer', icon: '<i class="fas fa-print fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.printer") },
   { id: 'video', icon: '<i class="fas fa-video fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.video") },
   { id: 'workstation', icon: '<i class="fas fa-desktop fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.workstation") },
   { id: 'laptop', icon: '<i class="fas fa-laptop fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.laptop") },
   { id: 'tablet', icon: '<i class="fas fa-tablet fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.tablet") },
   { id: 'phone', icon: '<i class="fas fa-mobile fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.phone") },
   { id: 'tv', icon: '<i class="fas fa-tv fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.tv") },
   { id: 'networking', icon: '<i class="fas fa-arrows-alt fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.networking") },
   { id: 'wifi', icon: '<i class="fas fa-wifi fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.wifi") },
   { id: 'nas', icon: '<i class="fas fa-database fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.nas") },
   { id: 'multimedia', icon: '<i class="fas fa-music fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.multimedia") },
   { id: 'iot', icon: '<i class="fas fa-thermometer fa-lg devtype-icon" aria-hidden="true"></i>', name: i18n("device_types.iot") },
]

const getOSList = () => {
   return icons;
}

const getAssetIconsList = () => {
   return asset_icons
}

const getOS = (value) => {
   return os[value] || os[0];
}

const getAssetIcon = (value) => {
   if(asset_icons[value] != null) {
      return asset_icons[value]["icon"];
   }
   return ''
}

const osUtils = function () {
   return {
      getOSList,
      getAssetIconsList,
      getOS,
      getAssetIcon
   };
}();

export default osUtils;
/**
 * Progetto GR
 *
 * Data: 01/08/2013
 *
 * @author Filippo Fontanelli <fontanelli.filippo@gmail.com>
 */
/*Variabili globali*/

var debug = false;
var g_Map;
var g_UrlJsonFile = url_prefix+'/lua/get_geo_hosts.lua';
var g_InfoWindowMarker = new google.maps.InfoWindow();
var g_InfowindowPolyline = new google.maps.InfoWindow();


if(!(zoomIP === undefined)) {
    g_UrlJsonFile = g_UrlJsonFile+"?"+zoomIP;
}


/*----------------------------------------JSON----------------------------------------*/
var g_JSONData = {};

/*----------------------------------------Marker----------------------------------------*/

var g_aMarker = [];

/*---------------------------------------Polyline---------------------------------------*/

//enum contenente  per le sub polyline
var g_WeightPL = [2, //Small
      3, //Medium
      5 //Big
      ];
//enum identificativo per le main polyline
var g_enumMainPL = {
  "Blue" : 0,
  "Green" : 1,
  "Orange" : 2,
  "length" : 3
};
//enum contente le configurazioni di colore per le main polyline
var g_ColorMainPL = ['#0000FF', //Blue
         '#64AA21', //Green
         '#FFA500' //Orange
         ];
//enum identificativo per le sub polyline
var g_enumSubPL = {
  "Cyan" : 0,
  "LightGreen" : 1,
  "Red" : 2,
  "length" : 3
};
//enum contente le configurazioni di colore per le sub polyline
var g_ColorSubPL = ['#00FFFF', //Cyan
        '#64FF21', //LightGreen
        '#FF4500' //Red
        ];

var g_aStyleMainPL = [];
//Array contente le configurazioni di stile per le main polyline
var g_aStyleSubPL = [];
//Array contente le configurazioni di stile per le sub polyline

var g_SogliePL = [];
//Array contente le soglie di diversificazione

var g_aMainPL = [];
//Array contente le main polyline
var g_aSubPL = [];
//Array contente le main polyline

// Rome, Italy
var default_latitude  = 41.9;
var default_longitude = 12.4833333;
var error_code        = "";
var locating = 1;
var mc;
function createMap() {
  createGoogleMap();
  loadJSONData();
}

function displayError(error) {
  var errors = {
  1: 'Permission denied',
  2: 'Position unavailable',
  3: 'Request timeout'
  };

  error_code = errors[error.code];
  locating = 0;
  
//  $('#mylocation').html("Geolocation error ["+ error_code+"]. Using default location.");
  displayLocalizedError(error_code);
  createMap();
}


function displayPosition(position) {
  default_latitude = position.coords.latitude;
  default_longitude = position.coords.longitude;
    locating = 0;

//    $('#mylocation').html("Browser reported home map location <A HREF=\"http://maps.google.com/?q="+ default_latitude + "," + default_longitude+"\">[Latitude: " + default_latitude + ", Longitude: " + default_longitude+"]</A>");
    displayLocalizedPosition(position);

    createMap();
}


/*----------------------------------------Main-------------------------------------------*/
/**
 * Main function
 */
function initialize() {

  if (navigator.geolocation) {
    var timeoutVal = 10 * 1000 * 1000;
    navigator.geolocation.getCurrentPosition(
               displayPosition,
               displayError,
               { enableHighAccuracy: true, timeout: timeoutVal, maximumAge: 0 }
               );

//    sleep(1000);

      // 
  }
  else {
      //alert("Geolocation is not supported by this browser");
      //$('#mylocation').html("Geolocation not supported by your browser or disabled. Using default location.");
      displayLocalizedNoGeolocationMsg();
    // We use the default location
      createMap();
  }

}

google.maps.event.addDomListener(window, 'load', initialize);

/*----------------------------------------Google Map Function----------------------------------------*/

/**
 * Crea una mappa di google , con impostazioni di default
 */
function createGoogleMap() {
  ConsoleDebug("[createGoogleMap][Start]");

  var l_DefaultLatlng = new google.maps.LatLng(default_latitude, default_longitude);
  var l_MapOptions = {
  zoom : 4,
  center : l_DefaultLatlng,
  mapTypeId : google.maps.MapTypeId.ROADMAP
  }
  g_Map = new google.maps.Map(document.getElementById('map-canvas'), l_MapOptions);
  var mcOptions = {maxZoom: 15,opt_nodraw: true};
  mc = new MarkerClusterer(g_Map,[],mcOptions);
  ConsoleDebug("[createGoogleMap][End]");
}

/**
 * Funzione principale per la creazione dei marker.
 *
 * @param p_data, dati JSON
 *
 */
function createMarkers(p_data) {
  ConsoleDebug("[createMarkers][Start]");

  var l_hostPosition;

  $.each(p_data.objects, function(i, elem) {
   
      $.each(elem.host, function(index, hostData) {
        
    if((hostData.lat == 0) && (hostData.lng == 0)) {
      hostData.lat = default_latitude;
      hostData.lng = default_longitude;
    }
    
    l_hostPosition = new google.maps.LatLng(hostData.lat, hostData.lng);

    if (find(l_hostPosition) == false) {
      ConsoleDebug(l_hostPosition);
      g_aMarker.push(new google.maps.Marker({
    position : l_hostPosition,
        // map : g_Map
        }));
      
      var l_currMarker = g_aMarker[g_aMarker.length - 1];

      var l_html = "<div class='infowin'><strong><A HREF=/lua/host_details.lua?host=" + hostData.name + ">" + hostData.name + "</A></strong><hr>";
      l_html = l_html + hostData.html;
      google.maps.event.addListener(l_currMarker, 'mouseover', function() {
    g_InfoWindowMarker.setContent(l_html);
    g_InfoWindowMarker.open(g_Map, l_currMarker);
        });
      /*
        google.maps.event.addListener(l_currMarker, 'mouseout', function() {
        g_InfoWindowMarker.close();
        });
      */
    }

  });

    });
  ConsoleDebug("[createMarkers][End]");

}

/**
 * Funzione principale per la creazione delle polyline.
 *
 * @param p_data, dati JSON
 *
 */
function createPolyline(p_data) {
  ConsoleDebug("[createPolyline][Start]");

  var l_flusso;
  var l_iIndexEnum;
  var l_polyCoordinates = [];

  createStylePL();
  $.each(p_data.objects, function(i, elem) {

      l_flusso = elem.flusso;

      if (l_flusso < 30)
  l_iIndexEnum = 0;
      else if (l_flusso < 60)
  l_iIndexEnum = 1;
      else
  l_iIndexEnum = 2;

      $.each(elem.host, function(index, hostData) {
    l_polyCoordinates.push(new google.maps.LatLng(hostData.lat, hostData.lng));
  });

      createMainPL(l_iIndexEnum, l_polyCoordinates, l_flusso, elem.html);
      createSubPL(l_iIndexEnum, l_polyCoordinates);
      l_polyCoordinates = [];
    });
  ConsoleDebug("[createPolyline][End]");

}

/**
 * Crea la main polyline
 *
 * @param p_iIndexEnum, identifica la posizione dell'array g_aStyleMainPL relativa allo style che vogliamo applicare alla polyline
 * @param p_polyCoordinates, array contenente le cordinate geografiche degli estremi della polyline
 * @param p_html, contiene del testo html, il quala verra' visualizzato come parte descrittiva dell'infowindow
 *
 */
function createMainPL(p_iIndexEnum, p_polyCoordinates, p_flusso, p_html) {
  ConsoleDebug("[createMainPL][Start]");

  g_aMainPL.push(new google.maps.Polyline({
      map : g_Map,
    path : p_polyCoordinates,
    geodesic : true,
    strokeOpacity : 0,
    icons : [{
    icon : g_aStyleMainPL[p_iIndexEnum],
        offset : '0',
        repeat : '20px'
        }]
    }));
    
  /*
    var polyTemp = g_aMainPL[g_aMainPL.length - 1];

    var l_html = "<div class='infowin'><strong>" + "Flusso:" + p_flusso + "</strong><hr>";
    l_html = l_html + p_html;

    google.maps.event.addListener(polyTemp, 'click', function(event) {
    g_InfowindowPolyline.setContent(l_html);
    g_InfowindowPolyline.position = event.latLng;
    g_InfowindowPolyline.open(g_Map);
    //, polyTemp);
    });

    google.maps.event.addListener(polyTemp, 'mouseover', function(event) {
    g_InfowindowPolyline.setContent(l_html);
    g_InfowindowPolyline.position = event.latLng;
    g_InfowindowPolyline.open(g_Map);
    //, polyTemp);
    });
    google.maps.event.addListener(polyTemp, 'mouseout', function() {
    g_InfowindowPolyline.close();
    });
  */
  ConsoleDebug("[createMainPL][End]");

}

/**
 * Crea la sub polyline per ottenere l'effetto grafico desiderato
 *
 * @param p_iIndexEnum, identifica la posizione dell'array g_aStyleSubPL relativa allo style che vogliamo applicare alla polyline
 * @param p_polyCoordinates, array contenente le cordinate geografiche degli estremi della polyline
 *
 */
function createSubPL(p_iIndexEnum, p_polyCoordinates) {
  ConsoleDebug("[createSubPL][Start]");

  g_aSubPL.push(new google.maps.Polyline({
      path : p_polyCoordinates,
    icons : [{
    icon : g_aStyleSubPL[p_iIndexEnum],
        offset : '100%'
        }],
    map : g_Map,
    strokeWeight : 0,
    geodesic : true
    }));
  ConsoleDebug("[createSubPL][End]");

}

/**
 * Scorre l'array delle main polyline, e per ognuna di esse, crea una funzione con il relativo intervallo,
 * per ottenere l'effetto grafico che identifica il fluire del flusso.
 */
function animateCircle() {
  ConsoleDebug("[animateCircle][Start]");

  var count = 0;

  offsetId = window.setInterval(function() {
      count = (count + 1) % 200;
      for ( i = 0; i < g_aMainPL.length; i++) {
  var icons = g_aSubPL[i].get('icons');
  icons[0].offset = (count / 2) + '%';
  g_aSubPL[i].set('icons', icons);
      }
    }, 20);
  ConsoleDebug("[animateCircle][End]");

}

/*----------------------------------------JSON Function----------------------------------------*/

/**
 * Funzione di caricamento dati JSON tramite JQUERY
 */
function loadJSONData() {

  $.getJSON(g_UrlJsonFile, function(data) {
      if (debug)
  logJSONData(data);

      ConsoleDebug("[loadJSONData]");
      createMarkers(data);
      mc.addMarkers(g_aMarker);

      if(!(zoomIP === undefined)) {
         createPolyline(data);
         animateCircle();
      }

    });

}

/*Utility function*/

/**
 * Inizializza con la giusta configurazione(color,weight) gli arrey g_aStyleMainPL e g_aStyleSubPL
 */
function createStylePL() {
  ConsoleDebug("[createPolyline][Start]");

  for (var i = 0; i < g_enumMainPL.length; i++) {
    g_aStyleMainPL[i] = {
    path : 'M 0,-1 0,1',
    strokeOpacity : 1,
    strokeWeight : g_WeightPL[i],
    strokeColor : g_ColorMainPL[i],
    scale : 6
    };
  };

  for (var i = 0; i < g_enumSubPL.length; i++) {
    g_aStyleSubPL[i] = {
    path : 'M 0,-0.5 0,0.5',
    scale : 6,
    strokeWeight : g_WeightPL[i],
    strokeColor : g_ColorSubPL[i]
    };
  };

  ConsoleDebug("[createPolyline][End]");
}

/**
 * Funzione di log
 *
 * Visualizza in output(conosole) i dati in input
 */
function logJSONData(data) {

  ConsoleDebug("Center: " + data.center);
  $.each(data.objects, function(i, elem) {
      ConsoleDebug("N: " + i);
      $.each(elem.host, function(i, elemH) {
    ConsoleDebug("Position: " + elemH.lat + "," + elemH.lng);
    ConsoleDebug("---- Info: " + elemH.name + "," + elemH.html);
  });

      ConsoleDebug("flusso: " + elem.flusso);
      ConsoleDebug("Info Aggiuntive flusso: " + elem.html);

      ConsoleDebug("**********************");

    });
}

/**
 * Restituisce true se esiste un marker posizionato in p_hostPosition(google.LatLen), false altrimenti.
 */
function find(p_hostPosition) {
  for ( i = 0; i < g_aMarker.length; i++) {
    if (p_hostPosition.equals(g_aMarker[i].getPosition()))
      return true;
  }
  return false;
}

/*Stampa nella console di log, la stringa ricevuta in ingresso se la variabile debug = true*/
function ConsoleDebug(string) {
  if (debug)
    console.log(string);
}

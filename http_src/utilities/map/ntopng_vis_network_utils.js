/**
    (C) 2022 - ntop.org    
*/


const defaultOptions = { 
  autoResize: true, 
  nodes: { 
      shape: "dot", 
      scaling: {
          min: 10,
          max: 30,
          label: {
              min: 15,
              max: 15,
          },
      },
      shadow: false,
  },
  edges: {
      width: 0.15,
      color: { inherit: "from" },
      smooth: {
          type: "continuous",
          roundness: 0
      },
  },
  interaction: {
      tooltipDelay: 150,
      hideEdgesOnDrag: true,
      hideEdgesOnZoom: true,
      hover: true,
      tooltipDelay: 0,
  },
  physics: {
      solver: "barnesHut",
      barnesHut: {
          theta: 0.5,
          springConstant: 0.1,
          avoidOverlap: 1,
          gravitationalConstant: -2000,
          damping: 1,
          centralGravity: 0,
          springLength: 200
      },
      stabilization: {
          onlyDynamicEdges: false
      },    
  },
  groups: {
      unknown: {
          shape: "dot",
      },
      printer: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf02f",
          size: 50,
          weight: 700,
        },
      },

      video: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf03d",
          size: 50,
          weight: 700,
        },
      },

      workstation: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf109",
          size: 50,
          weight: 700,
        },
      },

      laptop: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf109",
          size: 50,
          weight: 700,
        },
      },

      tablet: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf10a",
          size: 50,
          weight: 700,
        },
      },

      phone: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf10b",
          size: 50,
          weight: 700,
        },
      },

      tv: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf26c",
          size: 50,
          weight: 700,
        },
      },

      networking: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf0b2",
          size: 50,
          weight: 700,
        },
      },

      wifi: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf1eb",
          size: 50,
          weight: 700,
        },
      },

      nas: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf1c0",
          size: 50,
          weight: 700,
        },
      },

      multimedia: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\uf001",
          size: 50,
          weight: 700,
        },
      },

      iot: {
        shape: "icon",
        icon: {
          face: "'FontAwesome'",
          code: "\ue012",
          size: 50,
          weight: 700,
        },
      },

  },
};

export const ntopng_map_manager = {
  /**
   * Change the status of a service.
   * @param {string} service_id id of the service.
   * @param {string} new_state id of the new status of the service.
   * @param {function} callback function to be called on success.
   */
  toggle_state: function(service_id, new_state, callback, csrf) {
    const request = $.post(`${http_prefix}/lua/pro/enterprise/switch_service_state.lua`, { 
      service_id: service_id, service_status: new_state, csrf: csrf
    });
    request.then((data) => {
      if(data.success && callback) 
        callback();
    });
  },
  get_default_options: function() {
    return defaultOptions;
  },
}

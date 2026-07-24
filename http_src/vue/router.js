//
// (C) 2013-26 - ntop.org
//
//
// A route entry:
//   path:      the pathname of the .lua page (e.g. "/lua/about.lua")
//   component: the Vue component name as registered in ntop_vue.js
//   section / entry: menu keys used to keep the sidebar highlight in sync
//                     (mirrors what page_utils.print_header_and_set_active_menu_entry
//                     computes server-side for the legacy render path)
//   context:   optional object of extra static fields merged into
//              props.context alongside boot context + shared menu.lua flags
//   navbar:    optional { title, baseUrl, tabs, endTabs?, labelUrl?, backUrl?,
//              helpLink? } OR a function (menuFlags) => that same shape, for
//              tab lists that depend on shared menu.lua flags. AppShell
//              renders a PageNavbar (http_src/vue/components/page-navbar.vue)
//              above the routed page whenever this resolves to a value,
//              replacing the page's own page_utils.print_navbar(...) call.
//              menuFlags is ntopng_utility.get_menu_flags()'s return value.
//              A tab entry may set `legacyOnly: true` when its query value
//              isn't handled by this route's component/componentByQuery
//   isCheckEnabledFlag: optional string -- names the menu.lua response field
//              (e.g. "acl_violation_enabled") that answers this route's
//              component's props.context.is_check_enabled. Different pages
//              mean different things by "is_check_enabled" (ACL checks vs
//              network-config checks vs host-policy checks); this says
//              which shared flag applies for THIS route. See app-shell.vue's
//              routeContext computed.
//   extraComponentByQuery: optional { param, map } (same shape as
//              componentByQuery) for a SECOND component AppShell mounts
//              before the main one, only for query values present in `map`
//              -- e.g. network_stats.lua's PageTreemapNetworks chart, which
//              sits above PageNetworks only on the "networks" tab. Renders
//              nothing for query values not in `map`
import { createRouter, createWebHistory } from "vue-router";

export const spaRoutes = [
  {
    path: "/lua/about.lua",
    component: "PageAbout",
    section: "about",
    entry: "about",
  },
  {
    path: "/lua/license.lua",
    component: "PageLicense",
    section: "about",
    entry: "license",
  },
  {
    path: "/lua/checks_overview.lua",
    component: "PageChecksOverview",
    section: "dev",
    entry: "checks_dev",
  },
  {
    path: "/lua/defs_overview.lua",
    component: "PageDefsOverview",
    section: "dev",
    entry: "alert_definitions",
  },
  {
    path: "/lua/ts_overview.lua",
    component: "PageTsOverview",
    section: "dev",
    entry: "ts_definitions",
  },
  {
    path: "/lua/directories.lua",
    component: "PageDirectories",
    section: "dev",
    entry: "directories",
  },
  {
    path: "/lua/limits.lua",
    component: "PageLimits",
    section: "about",
    entry: "limits",
  },
  {
    path: "/lua/pro/alerts_graph.lua",
    component: "PageAlertsGraph",
    section: "alerts",
    entry: "alerts_graph",
  },
  {
    path: "/lua/pro/nanalyst.lua",
    component: "PageChatbot",
    section: "nanalyst",
    entry: "nanalyst",
  },
  {
    path: "/lua/pro/ai_policy.lua",
    component: "PageAiPolicy",
    section: "nanalyst",
    entry: "ai_policy",
  },
  {
    path: "/lua/pro/ai_stats.lua",
    component: "PageAiStats",
    section: "nanalyst",
    entry: "ai_usage_stats",
  },
  {
    path: "/lua/pro/ai_audit.lua",
    component: "PageAiAudit",
    section: "nanalyst",
    entry: "ai_audit",
  },
  {
    path: "/lua/pro/analyst_pipeline.lua",
    component: "PageAnalystPipeline",
    section: "nanalyst",
    entry: "analyst_pipeline",
  },
  {
    path: "/lua/hosts_geomap.lua",
    component: "PageGeoMap",
    section: "maps",
    entry: "geo_map",
  },
  {
    path: "/lua/discover.lua",
    component: "PageNetworkDiscovery",
    section: "monitoring",
    entry: "network_discovery",
    navbar: {
      title: "Network Discovery",
      baseUrl: "/lua/discover.lua",
      tabs: [
        { pageName: "network_discovery", label: '<i class="fas fa-lg fa-project-diagram"></i>' },
      ],
    },
  },
  {
    path: "/lua/macs_stats.lua",
    component: "PageMacsList",
    section: "hosts",
    entry: "devices",
    navbar: {
      title: "MAC List",
      baseUrl: "/lua/macs_stats.lua",
      tabs: [
        { pageName: "overview", label: '<i class="fas fa-lg fa-home"></i>' },
      ],
    },
  },
  {
    path: "/lua/pro/admin/access_control_list.lua",
    component: "PageAccessControlList",
    section: "policies",
    entry: "access_control_list",
    isCheckEnabledFlag: "acl_violation_enabled",
    navbar: {
      title: "Access Control List",
      baseUrl: "/lua/pro/admin/access_control_list.lua",
      tabs: [
        { pageName: "overview", label: "Overview" },
        { pageName: "scope_filters", label: i18n('acl_page.scope_filters'), component: "PageAccessControlScopeFilters" }
      ],
    },
  },
  {
    path: "/lua/admin/edit_configset.lua",
    component: "PageEditConfigset",
    section: "policies",
    entry: "scripts_config",
    navbar: (menuFlags) => {
      const isSystemIface = String(menuFlags.system_ifid) === String(menuFlags.current_ifid);
      const baseUrl = "/lua/admin/edit_configset.lua";
      const subMenu = isSystemIface
        ? [{ key: "system", label: i18n("system") || "System" }]
        : [
            { key: "all", label: i18n("all") || "All" },
            { key: "hosts", label: i18n("hosts") || "Hosts" },
            { key: "interfaces", label: i18n("interface") || "Interfaces" },
            { key: "networks", label: i18n("networks") || "Networks" },
            { key: "snmp_devices", label: i18n("snmp_devices") || "SNMP Devices" },
            { key: "flows", label: i18n("flows") || "Flows" },
            { key: "system", label: i18n("system") || "System" },
            { key: "syslog", label: i18n("syslog.syslog") || "Syslog" },
            { key: "active_monitoring", label: i18n("active_monitoring") || "Active Monitoring" },
            { key: "as", label: i18n("as") || "AS" },
          ];
      return {
        title: i18n("internals.checks") || "Checks",
        baseUrl,
        queryParam: "subdir",
        tabs: subMenu.map((s) => ({ pageName: s.key, label: s.label, url: `${baseUrl}?subdir=${s.key}` })),
      };
    },
  },
  {
    path: "/lua/admin/network_configuration.lua",
    // Three different components share this one URL, switched by ?page= --
    // see `componentByQuery` below (router.js's normal single-`component`
    // field can't express this; app-shell.vue's resolveRouteComponent()
    // checks for componentByQuery first).
    componentByQuery: {
      param: "page",
      map: {
        __default__: "PageNetworkConfiguration", // page=assets_inventory or absent
        assets_inventory: "PageNetworkConfiguration",
        policy: "PageNetworkPolicy",
        asn_config: "PageASNConfiguration",
      },
    },
    section: "policies",
    entry: "network_config",
    isCheckEnabledFlag: (query) => {
      const page = query?.page || "assets_inventory";
      if (page === "policy") return "network_policy_enabled";
      if (page === "asn_config") return null; // ASN config's is_check_enabled is hardcoded true server-side
      return "network_configuration_enabled";
    },
    navbar: {
      title: i18n("checks.network_configuration") || "Network Configuration",
      baseUrl: "/lua/admin/network_configuration.lua",
      tabs: [
        { pageName: "assets_inventory", label: '<i class="fas fa-lg fa-home"></i>' },
        { pageName: "policy", label: i18n("network_configuration.network_policy") || "Network Policy" },
        { pageName: "asn_config", label: i18n("checks.asn_configuration") || "ASN Configuration" },
      ],
    },
  },
  {
    path: "/lua/pro/admin/edit_alert_exclusions.lua",
    component: "PageAlertExclusions",
    section: "policies",
    entry: "alert_exclusions",
  },
  {
    path: "/lua/pro/sites.lua",
    component: "PageSitesDashboard",
    section: "dashboard",
    entry: "sites_dashboard",
  },
  {
    path: "/lua/pro/assets_dashboard.lua",
    component: "Dashboard",
    section: "dashboard",
    entry: "assets_dashboard",
    // template_endpoint/template_list_endpoint need http_prefix, which isn't
    // known at router-module-eval time -- app-shell.vue's routeContext
    // computed prefixes these with pfx.value before merging staticContext.
    context: {
      page: "dashboard",
      template: "assets",
      disable_date: true,
      is_infrastructure: false,
      hide_time: true,
      template_endpoint: "/lua/rest/v2/get/dashboard/template/data.lua",
      template_list_endpoint: "/lua/rest/v2/get/dashboard/template/list.lua",
      _prefixFields: ["template_endpoint", "template_list_endpoint"],
    },
  },
  {
    path: "/lua/admin/edit_categories.lua",
    component: "PageEditCategories",
    section: "admin",
    entry: "categories",
  },
  {
    path: "/lua/tags.lua",
    component: "PageTags",
    section: "admin",
    entry: "tags",
    navbar: {
      title: i18n("tags_page.tags") || "Tags",
      baseUrl: "/lua/tags.lua",
      tabs: [
        { pageName: "overview", label: '<i class="fas fa-lg fa-home"></i>' },
      ],
    },
  },
  {
    path: "/lua/admin/prefs.lua",
    component: "PagePreferences",
    section: "admin",
    entry: "preferences",
  },
  {
    path: "/lua/pro/admin/edit_profiles.lua",
    component: "PageTrafficProfiles",
    section: "policies",
    entry: "profiles",
    navbar: {
      title: "Traffic Profiles",
      baseUrl: "/lua/pro/admin/edit_profiles.lua",
      tabs: [
        { pageName: "overview", label: '<i class="fas fa-lg fa-home"></i>' },
      ],
    },
  },
  {
    path: "/lua/network_stats.lua",
    componentByQuery: {
      param: "page",
      map: {
        __default__: "PageNetworks",
        networks: "PageNetworks",
        sites: "PageSites",
      },
    },
    section: "if_stats",
    entry: "networks",
    navbar: (menuFlags) => {
      const tabs = [
        { pageName: "networks", label: i18n("network_stats.networks") || "Networks" },
      ];
      if (menuFlags.isPro) {
        tabs.push({ pageName: "sites", label: i18n("sites_page.sites") || "Sites" });
      }
      return {
        title: i18n("network_stats.networks") || "Networks",
        baseUrl: "/lua/network_stats.lua",
        tabs: tabs,
      };
    },
  },
  {
    path: "/lua/pool_stats.lua",
    component: "PageHostPools",
    section: "if_stats",
    entry: "host_pools",
    isCheckEnabledFlag: null,
    navbar: {
      title: i18n("pool_stats.host_pool_list") || "Host Pools",
      baseUrl: "/lua/pool_stats.lua",
      tabs: [
        { pageName: "overview", label: '<i class="fas fa-lg fa-home"></i>' },
      ],
    },
  },
  {
    path: "/lua/country_stats.lua",
    component: "PageCountryStats",
    section: "if_stats",
    entry: "countries",
    navbar: {
      title: i18n("countries") || "Countries",
      baseUrl: "/lua/country_stats.lua",
      tabs: [
        { pageName: "overview", label: '<i class="fas fa-lg fa-home"></i>' },
      ],
    },
  },
];

// pathname -> route entry, for O(1) lookup from click interception / mount checks
export const spaRoutesByPath = Object.fromEntries(
  spaRoutes.map((r) => [r.path, r])
);

const router = createRouter({
  history: createWebHistory(),
  routes: spaRoutes.map((r) => ({
    path: r.path,
    name: r.component || r.path,
    meta: {
      section: r.section,
      entry: r.entry,
      componentName: r.component || null,
      componentByQuery: r.componentByQuery || null,
      extraComponentByQuery: r.extraComponentByQuery || null,
      navbar: r.navbar || null,
      isCheckEnabledFlag: r.isCheckEnabledFlag || null,
      staticContext: r.context || null,
    },
    // component resolution happens in app-shell.vue via ntopVue[componentName]
    // (or, for componentByQuery routes, ntopVue[resolved name]), since page
    // components are already registered on the global ntopVue object rather
    // than as ES module imports the router can consume directly.
    component: { render: () => null },
  })),
});

export default router;

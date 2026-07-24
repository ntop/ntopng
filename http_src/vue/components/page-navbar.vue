<!-- (C) 2013-26 - ntop.org
  Vue port of httpdocs/templates/pages/components/page-navbar.template same classes

  Tabs whose `path` matches a registered SPA route navigate via the router
  (no page reload); everything else is a plain <a href> full navigation,
  same as the legacy version.
-->
<template>
  <nav class="navbar navbar-shadow navbar-expand-lg navbar-light bg-light px-2 mb-2">
    <span v-if="!labelUrl" class="me-1 text-nowrap" style="font-size: 1.1rem;" v-html="titleHtml"></span>
    <span v-if="!labelUrl" class="text-muted ms-1 d-none d-lg-inline d-md-none">|</span>
    <a v-else class="navbar-brand" :href="labelUrl">
      <small v-html="titleHtml"></small>
    </a>

    <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav"
      aria-controls="navbarNav" aria-expanded="false">
      <span class="navbar-toggler-icon"></span>
    </button>

    <div class="collapse navbar-collapse scroll-x" id="navbarNav">
      <ul class="navbar-nav">
        <template v-for="tab in visibleTabs" :key="tab.pageName">
          <li v-if="isActive(tab)" class="nav-item nav-link active">
            <span v-if="tab.badgeNum > 0" class="badge rounded-pill bg-dark" style="float:right;margin-bottom:-10px;">{{ tab.badgeNum }}</span>
            <b v-html="tab.label"></b>
          </li>
          <span v-else-if="tab.disabled" class="nav-item nav-link text-muted" style="cursor:not-allowed; opacity:.65;"
            :title="tab.tooltip || ''">
            <span v-html="tab.label"></span>
          </span>
          <a v-else :href="tabHref(tab)" class="nav-item nav-link" :title="tab.tooltip || ''"
            @click="onTabClick($event, tab)">
            <span v-if="tab.badgeNum > 0" class="badge rounded-pill bg-dark" style="float:right;margin-bottom:-10px;">{{ tab.badgeNum }}</span>
            <span v-html="tab.label"></span>
          </a>
        </template>
      </ul>

      <ul class="navbar-nav ms-auto">
        <template v-for="tab in visibleEndTabs" :key="tab.pageName">
          <li v-if="isActive(tab)" class="nav-item nav-link active">
            <span v-if="tab.badgeNum > 0" class="badge rounded-pill bg-dark" style="float:right;margin-bottom:-10px;">{{ tab.badgeNum }}</span>
            <b v-html="tab.label"></b>
          </li>
          <a v-else :href="tabHref(tab)" class="nav-item nav-link" @click="onTabClick($event, tab)">
            <span v-if="tab.badgeNum > 0" class="badge rounded-pill bg-dark" style="float:right;margin-bottom:-10px;">{{ tab.badgeNum }}</span>
            <span v-html="tab.label"></span>
          </a>
        </template>

        <a v-if="backUrl" :href="backUrl" class="nav-item nav-link text-muted">
          <i class="fas fa-arrow-left"></i>
        </a>
        <a v-else href="javascript:history.back()" class="nav-item nav-link text-muted">
          <i class="fas fa-arrow-left"></i>
        </a>

        <a v-if="helpLink" target="_newtab" :href="helpLink" class="nav-item nav-link text-muted">
          <i class="fas fa-question-circle"></i>
        </a>
      </ul>
    </div>
  </nav>
</template>

<script setup>
import { computed } from "vue";
import { useRouter, useRoute } from "vue-router";
import { spaRoutesByPath } from "../router.js";
import { ntopng_utility } from "../../services/context/ntopng_globals_services.js";

const props = defineProps({
  title: { type: String, default: "" },
  baseUrl: { type: String, default: "" },   // legacy base URL, e.g. ".../lua/as_stats.lua"
  tabs: { type: Array, default: () => [] }, // [{ pageName, label, url?, hidden?, disabled?, tooltip?, badgeNum? }]
  endTabs: { type: Array, default: () => [] },
  labelUrl: { type: String, default: "" },
  backUrl: { type: String, default: "" },
  helpLink: { type: String, default: "" },
  // most pages use ?page= to track the active tab; a few (edit_configset.lua) use a differently named param
  // (?subdir=) -- this lets the same component serve both without a fork.
  queryParam: { type: String, default: "page" },
});

const router = useRouter();
const route = useRoute();

const visibleTabs = computed(() => (props.tabs || []).filter((t) => !t.hidden));
const visibleEndTabs = computed(() => (props.endTabs || []).filter((t) => !t.hidden));

// Matches page_utils.print_navbar's server-side behavior exactly: prefix
// the title with the current section's icon, taken from the same
// menu.lua provided sections list AppShell's own sidebar reads
const titleHtml = computed(() => {
  const sectionKey = route.meta?.section;
  const sections = ntopng_utility.get_menu_flags().sections || [];
  const icon = sections.find((s) => s.key === sectionKey)?.icon || "";
  const iconHtml = icon ? `<i class="${icon}"></i> ` : "";
  return `${iconHtml}${props.title}`;
});

// A tab is active if it names the current query value (?page= by default,
// see queryParam prop), or -- for the "overview"/default tab -- if the
// param is absent entirely (matches the Lua convention:
// `active = page == "overview" or not page`).
function isActive(tab) {
  const current = route.query[props.queryParam] || props.tabs[0]?.pageName;
  return tab.pageName === current;
}

function tabHref(tab) {
  if (tab.url) return tab.url;
  const sep = props.baseUrl.includes("?") ? "&" : "?";
  return `${props.baseUrl}${sep}${props.queryParam}=${tab.pageName}`;
}

function onTabClick(e, tab) {
  if (tab.legacyOnly) return; // this tab isn't handled by the SPA route's component: full navigation
  const href = tabHref(tab);
  let url;
  try { url = new URL(href, window.location.origin); } catch (_) { return; }
  if (url.origin !== window.location.origin) return;
  if (!spaRoutesByPath[url.pathname]) return; // not SPA-routed: let the browser navigate normally

  e.preventDefault();
  router.push({ path: url.pathname, query: Object.fromEntries(url.searchParams) });
}
</script>

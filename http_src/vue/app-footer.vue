<!--
  (C) 2013-26 - ntop.org
  AppFooter — orchestration component.
  Handles: software updates polling, ext_link_dialog, nEdge power/reboot modals,
           ajaxError -> login redirect, history.replaceState on POST.
  No visible UI of its own except modals.
-->
<template>
  <!-- External link confirmation modal -->
  <div class="modal fade" id="ext_link_dialog" tabindex="-1">
    <div class="modal-dialog modal-sm">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">{{ _i18n("external_link") }}</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
        </div>
        <div class="modal-body">
          <span id="url_ext_link_dialog"></span><br/>{{ _i18n("are_you_sure") }}
        </div>
        <div class="modal-footer">
          <button class="btn btn-secondary btn-sm" data-bs-dismiss="modal">{{ _i18n("cancel") }}</button>
          <a id="btn-confirm-action_ext_link_dialog" class="btn btn-primary btn-sm"
             href="#" target="_blank" rel="noopener" data-bs-dismiss="modal">
            {{ _i18n("redirect") }}
          </a>
        </div>
      </div>
    </div>
  </div>

  <!-- nEdge poweroff/reboot modals -->
  <template v-if="ctx.is_nedge && ctx.is_admin">
    <form id="powerOffForm" method="post">
      <input name="csrf" :value="ctx.csrf" type="hidden" />
      <input name="poweroff" value="" type="hidden" />
    </form>
    <form id="rebootForm" method="post">
      <input name="csrf" :value="ctx.csrf" type="hidden" />
      <input name="reboot" value="" type="hidden" />
    </form>

    <div class="modal fade" id="poweroff_dialog" tabindex="-1">
      <div class="modal-dialog modal-sm">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ _i18n("nedge.power_off") }}</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body">{{ _i18n("nedge.power_off_confirm") }}</div>
          <div class="modal-footer">
            <button class="btn btn-secondary btn-sm" data-bs-dismiss="modal">{{ _i18n("cancel") }}</button>
            <button class="btn btn-danger btn-sm" @click="submitForm('powerOffForm')">
              {{ _i18n("nedge.power_off") }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <div class="modal fade" id="reboot_dialog" tabindex="-1">
      <div class="modal-dialog modal-sm">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">{{ _i18n("nedge.reboot") }}</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body">{{ _i18n("nedge.reboot_corfirm") }}</div>
          <div class="modal-footer">
            <button class="btn btn-secondary btn-sm" data-bs-dismiss="modal">{{ _i18n("cancel") }}</button>
            <button class="btn btn-primary btn-sm" @click="submitForm('rebootForm')">
              {{ _i18n("nedge.reboot") }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </template>
</template>

<script setup>
import { computed, onMounted, onBeforeUnmount } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";

const props = defineProps({ context: Object });
const ctx   = computed(() => props.context || {});

function _i18n(key) { return i18n(key) || key; }

// Updates
const UPDATES_POLL_SLOW  = 300; // seconds — when idle
const UPDATES_POLL_FAST  = 10;  // seconds — when checking/installing

let updatesStatus   = "";
let updatesLastCheck = 0;
let updatesTimer    = null;

async function updatesRefresh() {
  if (!ctx.value.has_updates_support) return;

  const now = Date.now() / 1000;
  const checkInterval = (updatesStatus === "installing" || updatesStatus === "checking")
    ? UPDATES_POLL_FAST : UPDATES_POLL_SLOW;

  if (updatesStatus === "update-avail" || updatesStatus === "upgrade-failure") return;
  if (now < updatesLastCheck + checkInterval) return;
  updatesLastCheck = now;

  try {
    const data = await ntopng_utility.http_request(
      `${http_prefix}/lua/check_update.lua`
    );
    if (!data || !data.status) return;
    updatesStatus = data.status;
    applyUpdatesStatus(data);
  } catch (_) {}
}

function applyUpdatesStatus(data) {
  const infoEl    = document.getElementById("updates-info-li");
  const installEl = document.getElementById("updates-install-li");
  const badgeEl   = document.getElementById("admin-badge");

  if (!infoEl) return;

  if (data.status === "installing") {
    infoEl.textContent = _i18n("updates.installing");
    installEl?.style && (installEl.style.display = "none");
    badgeEl?.style   && (badgeEl.style.display = "none");

  } else if (data.status === "checking") {
    infoEl.textContent = _i18n("updates.checking");
    installEl?.style && (installEl.style.display = "none");
    badgeEl?.style   && (badgeEl.style.display = "none");

  } else if (data.status === "update-avail" || data.status === "upgrade-failure") {
    infoEl.innerHTML = `<span class="badge bg-danger">${_i18n("updates.available")}</span> ${data.version || ""}`;

    if (installEl) {
      installEl.style.display = "";
      const icon = data.status === "update-avail"
        ? '<i class="fas fa-download me-1"></i>'
        : '<i class="fas fa-exclamation-triangle text-danger me-1"></i>';
      installEl.innerHTML = `<a class="dropdown-item" href="#">${icon}${_i18n("updates.install")}</a>`;
      installEl.querySelector("a")?.addEventListener("click", e => {
        e.preventDefault();
        doInstallUpdate();
      });
    }

    if (badgeEl) badgeEl.style.display = "";

    // Show in major-release alert bar
    const alertEl = document.getElementById("major-release-alert");
    const textEl  = document.getElementById("ntopng_update_available");
    if (alertEl && textEl) {
      textEl.textContent = `${_i18n("updates.available")}: ${data.version || ""}`;
      alertEl.style.display = "";
    }

  } else {
    infoEl.textContent = _i18n("updates.no_updates") + ".";
    installEl?.style && (installEl.style.display = "none");
    badgeEl?.style   && (badgeEl.style.display = "none");
  }
}

async function doInstallUpdate() {
  let msg = _i18n("updates.install_confirm");
  if (!confirm(msg)) return;

  try {
    await ntopng_utility.http_request(
      `${http_prefix}/lua/install_update.lua`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ csrf: ctx.value.csrf || window.__CSRF_DATATABLE__ }),
      }
    );
    const infoEl    = document.getElementById("updates-info-li");
    const installEl = document.getElementById("updates-install-li");
    const badgeEl   = document.getElementById("admin-badge");
    if (infoEl) infoEl.textContent = _i18n("updates.installing");
    installEl?.style && (installEl.style.display = "none");
    badgeEl?.style   && (badgeEl.style.display = "none");
    updatesStatus = "installing";
  } catch (_) {}
}

function startUpdatesCheck() {
  const infoEl    = document.getElementById("updates-info-li");
  const installEl = document.getElementById("updates-install-li");
  if (infoEl) infoEl.textContent = _i18n("updates.checking");
  if (installEl) installEl.style.display = "none";

  doManualCheck();
}

async function doManualCheck() {
  try {
    await ntopng_utility.http_request(
      `${http_prefix}/lua/check_update.lua`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          csrf: ctx.value.csrf || window.__CSRF_DATATABLE__,
          search: "true",
        }),
      }
    );
    updatesStatus = "checking";
    updatesLastCheck = 0; // force a refresh on next tick
  } catch (_) {}
}

// ext_link_dialog — intercept .ntopng-external-link clicks
function onExternalLinkClick(e) {
  const anchor = e.target.closest("a.ntopng-external-link");
  if (!anchor) return;
  e.preventDefault();

  const url = anchor.href;
  const el  = document.getElementById("url_ext_link_dialog");
  const btn = document.getElementById("btn-confirm-action_ext_link_dialog");
  if (el)  el.textContent = url;
  if (btn) btn.href = url;

  const modalEl = document.getElementById("ext_link_dialog");
  if (modalEl && window.bootstrap) {
    bootstrap.Modal.getOrCreateInstance(modalEl).show();
  }
}

// Toast dismiss, from ToastUtils
function onToastDismiss(e) {
  const btn = e.target.closest(".notification button.dismiss");
  if (!btn) return;
  const toast = btn.closest(".notification");
  if (!toast) return;
  const id = toast.dataset.toastId;
  if (typeof ToastUtils !== "undefined" && id) {
    ToastUtils.dismissToast(id, ctx.value.csrf || window.__CSRF_DATATABLE__, data => {
      if (data?.success) {
        const bsToast = bootstrap.Toast.getInstance(toast);
        bsToast?.hide();
      }
    });
  }
}

// ---------------------------------------------------------------
// 403 ajaxError -> redirect to login
function onAjaxError(_evt, xhr) {
  if (xhr?.status === 403 && xhr?.responseText === "Login Required") {
    window.location.href = `${http_prefix}/lua/login.lua`;
  }
}

// ---------------------------------------------------------------
// nEdge form submit helper
function submitForm(id) {
  document.getElementById(id)?.submit();
}

// ---------------------------------------------------------------
// history.replaceState (avoid Document Expired on POST pages)
function fixHistoryState() {
  if (history?.replaceState && window.location.href) {
    history.replaceState(history.state, "", window.location.href);
  }
}

function wireUpdatesInstallButton() {
  const installEl = document.getElementById("updates-install-li");
  if (installEl) {
    installEl.addEventListener("click", e => {
      e.preventDefault();
      startUpdatesCheck();
    });
  }
}

onMounted(async () => {
  document.addEventListener("click", onExternalLinkClick);
  document.addEventListener("click", onToastDismiss);
  document.addEventListener("ajaxError", onAjaxError);

  // jQuery ajaxError fallback
  if (window.$) {
    $(document).ajaxError((err, response) => {
      if (response?.status === 403 && response?.responseText === "Login Required") {
        window.location.href = `${http_prefix}/lua/login.lua`;
      }
    });
  }

  fixHistoryState();
  wireUpdatesInstallButton();

  if (ctx.value.has_updates_support) {
    // initial check
    updatesLastCheck = 0;
    await updatesRefresh();
    // poll every 10 seconds; the function internally throttles to slow/fast intervals
    updatesTimer = setInterval(updatesRefresh, UPDATES_POLL_FAST * 1000);
  }
});

onBeforeUnmount(() => {
  document.removeEventListener("click", onExternalLinkClick);
  document.removeEventListener("click", onToastDismiss);
  document.removeEventListener("ajaxError", onAjaxError);
  if (updatesTimer) clearInterval(updatesTimer);
});
</script>

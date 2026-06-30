<!--
  (C) 2013-26 - ntop.org
  two column sidebar. Rail + hover/click expandable panel
  Labels hidden by default, fade in on hover. Click locks panel open.
-->
<template>

  <!-- Icon Rail -->
  <nav
    id="n-sidebar"
    class="sb-rail"
    :class="{ 'sb-rail--expanded': railHovered }"
    @mouseenter="onRailEnter"
    @mouseleave="onRailLeave"
  >
    <!-- Logo: OEM custom image or default -->
    <a :href="`${pfx}/lua/index.lua`" class="sb-rail__logo" :title="menu.product || 'ntopng'">
      <img v-if="menu.logo_path" :src="menu.logo_path" width="26" height="26"
           :alt="menu.product || 'ntopng'" class="sb-rail__logo-img" />
      <svg v-else xmlns="http://www.w3.org/2000/svg" viewBox="0 0 13.758333 13.758334"
           width="26" height="26" aria-hidden="true">
        <path fill="#ff7500"
          d="M 2.7739989,9.5828812 V 4.216811 q 0,-0.9839173 0.3224603,-1.4552054 0.3307285,-0.4795564 1.008722,-0.4795564 0.4051424,0 0.7193345,0.2149735 Q 5.1387078,2.7037281 5.378486,3.1336751 5.808433,2.662387 6.3706715,2.4474135 6.93291,2.2324399 7.7349267,2.2324399 q 1.5792286,0 2.4143183,0.9012352 0.835089,0.9012352 0.835089,2.6210235 v 3.8281826 q 0,0.9839178 -0.330728,1.4634738 -0.330729,0.479556 -1.0087222,0.479556 -0.6779934,0 -1.0087219,-0.479556 Q 8.3054333,10.566799 8.3054333,9.5828812 V 6.5649835 q 0,-1.1162088 -0.3389967,-1.5874969 -0.3307285,-0.4795563 -1.0996723,-0.4795563 -0.7276027,0 -1.0748677,0.4960927 -0.3472649,0.4878246 -0.3472649,1.5378876 v 3.0509706 q 0,0.9839178 -0.3307285,1.4634738 -0.3307286,0.479556 -1.008722,0.479556 -0.6779935,0 -1.008722,-0.479556 Q 2.7739989,10.566799 2.7739989,9.5828812 Z"
        />
      </svg>
    </a>

    <!-- Up triangl: shown when user has scrolled down -->
    <div v-show="navCanScrollUp" class="sb-rail__scroll-hint sb-rail__scroll-hint--up">
      <i class="fas fa-chevron-up"></i>
    </div>

    <!-- Section buttons -->
    <div class="sb-rail__nav-wrap">
      <div class="sb-rail__nav" ref="railNav" @scroll="checkNavOverflow">
        <div
          v-for="section in visibleSections"
          :key="section.key"
          class="sb-rail__btn"
          :class="{
            'sb-rail__btn--current':  activeSection === section.key,
            'sb-rail__btn--open':     lockedSection?.key === section.key,
            'sb-rail__btn--hovering': hoveredSection?.key === section.key && lockedSection?.key !== section.key
          }"
          :data-section="section.key"
          @mouseenter="onSectionHover(section)"
          @click.stop="onSectionClick(section)"
          :title="section.label"
        >
          <!-- Orange pill for active/open menu entry-->
          <span class="sb-rail__pill"></span>
          <i :class="section.icon" class="sb-rail__icon" aria-hidden="true"></i>
          <span class="sb-rail__label">{{ section.label }}</span>
        </div>
      </div>
      <!-- Bottom fade: outside scroll container, sticks to bottom of nav area -->
      <div v-show="navOverflow" class="sb-rail__nav-fade" aria-hidden="true"></div>
    </div>

    <!-- Scroll-more indicator: bouncing arrow when nav items overflow -->
    <div v-show="navOverflow" class="sb-rail__scroll-hint">
      <i class="fas fa-chevron-down"></i>
    </div>

    <!-- Bottom: avatar -->
    <div class="sb-rail__bottom">
      <div
        class="sb-rail__btn sb-rail__btn--avatar"
        :class="{ 'sb-rail__btn--open': userPopupOpen }"
        @mouseenter="onAvatarEnter"
        @mouseleave="onAvatarLeave"
        :title="_i18n('infrastructure_dashboard.profile')"
        ref="avatarBtn"
      >
        <span class="sb-rail__pill"></span>
        <div class="sb-rail__avatar-cell">
          <div class="sb-avatar">{{ userInitials }}</div>
          <span v-if="hasAdminNotifications" class="sb-avatar-dot"
                :class="{ 'sb-avatar-dot--update': updateStatus === 'update-avail' || updateStatus === 'upgrade-failure' }"></span>
        </div>
        <span class="sb-rail__label">{{ _i18n("profile") || "Profile" }}</span>
      </div>
    </div>
  </nav>

  <!-- Expandable Panel-->
  <Teleport to="body">
    <Transition name="sb-panel-anim">
      <div
        v-if="isPanelOpen && currentPanelSection && (hasEntries(currentPanelSection) || currentPanelSection.key === 'about')"
        class="sb-panel"
        @mouseenter="onPanelEnter"
        @mouseleave="onPanelLeave"
      >
        <div class="sb-panel__header"></div>

        <!-- Nav entries -->
        <nav class="sb-panel__nav">
          <template v-for="(entry, idx) in visibleEntries(currentPanelSection)" :key="entry.is_divider ? `divider-${idx}` : entry.key">
            <template v-if="entry.is_divider">
              <div class="sb-panel-divider"></div>
              <div v-if="entry.label" class="sb-panel-group-label">{{ entry.label }}</div>
            </template>
            <a
              v-else
              :href="entry.url"
              class="sb-nav-link"
              :class="{ 'sb-nav-link--active': activeSection === currentPanelSection.key && activeEntry === entry.key }"
              :target="entry.is_external ? '_blank' : undefined"
              :rel="entry.is_external ? 'noopener' : undefined"
            >
              <i v-if="entry.icon" :class="entry.icon" class="sb-nav-link__icon" aria-hidden="true"></i>
              <span>{{ entry.label }}</span>
              <i v-if="entry.is_external" class="fas fa-external-link-alt sb-ext-icon" aria-hidden="true"></i>
            </a>
          </template>
        </nav>
      </div>
    </Transition>

    <!-- Profile popup: floats above avatar -->
    <Transition name="sb-popup-anim">
      <div v-if="userPopupOpen" class="sb-user-popup" @click.stop
           @mouseenter="onAvatarEnter" @mouseleave="onAvatarLeave"
           :style="popupStyle">

        <!-- Card header -->
        <div class="sb-user-card">
          <div class="sb-avatar sb-avatar--lg">{{ userInitials }}</div>
          <div class="sb-user-card__info">
            <div class="sb-user-card__name">{{ menu.username || _i18n("infrastructure_dashboard.user") }}</div>
            <div class="sb-user-card__role">{{ menu.is_admin ? _i18n("infrastructure_dashboard.admin") : _i18n("infrastructure_dashboard.user") }}</div>
          </div>
        </div>

        <div class="sb-popup-divider"></div>

        <!-- Profile link -->
        <template v-if="menu.is_no_login_user">
          <div class="sb-popup-item sb-popup-item--text">
            <i class="fas fa-user sb-popup-icon"></i>
            <span>{{ menu.username }}</span>
          </div>
        </template>
        <template v-else-if="!menu.is_local_user && !menu.is_admin">
          <a class="sb-popup-item" href="#password_dialog" data-bs-toggle="modal"
             @click="triggerPasswordDialog(menu.username)">
            <i class="fas fa-user sb-popup-icon"></i>
            <span>{{ manageUserLabel }}</span>
          </a>
        </template>
        <template v-else>
          <a class="sb-popup-item"
             :href="`${pfx}/lua/admin/users.lua?user=${encodeURIComponent(menu.username || '')}`">
            <i class="fas fa-user sb-popup-icon"></i>
            <span>{{ _i18n("profile") || "Profile" }}</span>
          </a>
        </template>

        <!-- Dark mode toggle — THE only place -->
        <button class="sb-popup-item" @click.stop="toggleTheme">
          <i :class="isDark ? 'fas fa-sun' : 'fas fa-moon'" class="sb-popup-icon"></i>
          <span>{{ isDark ? (_i18n("toggle_white_theme") || "Light mode") : (_i18n("toggle_dark_theme") || "Dark mode") }}</span>
          <div class="sb-toggle-switch" :class="{ on: isDark }">
            <div class="sb-toggle-thumb"></div>
          </div>
        </button>

        <!-- Updates -->
        <template v-if="menu.has_updates_support">
          <div class="sb-popup-divider"></div>
          <div class="sb-popup-item sb-popup-item--text">
            <i class="fas fa-sync sb-popup-icon"></i>
            <span v-if="updateStatus === 'update-avail' || updateStatus === 'upgrade-failure'">
              <span class="badge bg-danger">{{ _i18n("updates.available") }}</span> {{ updateVersion }}
            </span>
            <span v-else-if="updateStatus === 'installing'">{{ _i18n("updates.installing") }}</span>
            <span v-else-if="updateStatus === 'checking'">{{ _i18n("updates.checking") }}</span>
            <span v-else-if="updateStatus === 'not-avail'">{{ _i18n("updates.no_updates") }}</span>
            <span v-else-if="updateStatus === 'update-failure'">
              <i class="fas fa-exclamation-triangle text-danger me-1"></i>{{ _i18n("updates.no_updates") }}
            </span>
            <span v-else>{{ _i18n("updates.checking") }}</span>
            <span v-if="updateStatus === 'update-avail' || updateStatus === 'upgrade-failure'"
                  class="badge bg-danger ms-auto">{{ updateStatus === 'upgrade-failure' ? '!' : '1' }}</span>
          </div>
          <!-- Install / Check button row -->
          <template v-if="updateStatus === 'update-avail' || updateStatus === 'upgrade-failure'">
            <button class="sb-popup-item" style="width:100%" @click="doInstallUpdate"
                    :title="updateStatus !== 'update-avail' ? _i18n('updates.update_failure_message') + ': ' + updateStatus : ''">
              <i :class="updateStatus === 'update-avail' ? 'fas fa-download me-1' : 'fas fa-exclamation-triangle text-danger me-1'"></i>
              {{ _i18n("updates.install") }}
            </button>
          </template>
          <template v-else-if="updateStatus === 'not-avail' || updateStatus === 'update-failure'">
            <button class="sb-popup-item" style="width:100%" @click="doCheckForUpdates">
              <i class="fas fa-sync me-1"></i>{{ _i18n("updates.check") }}
            </button>
          </template>
        </template>

        <!-- Restart -->
        <template v-if="menu.is_admin && menu.is_package && !menu.is_windows">
          <div class="sb-popup-divider"></div>
          <button class="sb-popup-item" @click="confirmRestart">
            <i class="fas fa-redo-alt sb-popup-icon"></i>
            <span>{{ _i18n("restart.restart") }}</span>
          </button>
        </template>

        <!-- nEdge power off / reboot -->
        <template v-if="menu.is_nedge && menu.is_admin">
          <div class="sb-popup-divider"></div>
          <button class="sb-popup-item sb-popup-item--danger" @click="confirmNedgePowerOff">
            <i class="fas fa-power-off sb-popup-icon"></i>
            <span>{{ _i18n("nedge.power_off") }}</span>
          </button>
          <button class="sb-popup-item" @click="confirmNedgeReboot">
            <i class="fas fa-redo sb-popup-icon"></i>
            <span>{{ _i18n("nedge.reboot") }}</span>
          </button>
        </template>

        <!-- Blog feed -->
        <template v-if="!menu.is_oem">
          <div class="sb-popup-divider"></div>
          <button class="sb-popup-item" @click.stop="blogExpanded = !blogExpanded">
            <i class="fas fa-bell sb-popup-icon"></i>
            <span v-html="_i18n('infrastructure_dashboard.news_from_blog')"></span>
            <span v-if="menu.new_posts_counter > 0" class="badge bg-danger ms-auto me-1">{{ menu.new_posts_counter }}</span>
            <i v-else :class="blogExpanded ? 'fas fa-chevron-up' : 'fas fa-chevron-down'"
               style="font-size:0.6rem;opacity:0.45;margin-left:auto"></i>
          </button>
          <template v-if="blogExpanded">
            <template v-if="hasBlogPosts">
              <a v-for="post in menu.blog_posts" :key="post.id"
                 class="sb-popup-blog-item" :href="post.url" target="_blank" rel="noopener"
                 @click="markPostRead(post.id)">
                <i class="fas fa-circle fa-xs" :class="post.is_read ? 'text-muted opacity-25' : 'text-danger'" style="flex-shrink:0;margin-top:0.2rem"></i>
                <div class="sb-popup-blog-item__body">
                  <div :class="{ 'fw-semibold': !post.is_read }">{{ post.title }}</div>
                  <div v-if="post.short_desc" class="sb-popup-blog-item__desc">{{ post.short_desc }}</div>
                </div>
                <i class="fas fa-external-link-alt" style="font-size:0.55rem;opacity:0.4;flex-shrink:0;margin-top:0.2rem"></i>
              </a>
            </template>
            <div v-else class="sb-popup-blog-empty">Nothing to show here. Try tomorrow!</div>
          </template>
        </template>

        <div class="sb-popup-divider"></div>

        <button v-if="!menu.is_no_login_user" class="sb-popup-item sb-popup-item--danger"
           @click="confirmLogout">
          <i class="fas fa-sign-out-alt sb-popup-icon"></i>
          <span>{{ _i18n("login.logout") }}</span>
        </button>

      </div>
    </Transition>
  </Teleport>

  <!-- Topbar -->
  <nav id="n-navbar" class="sb-topbar">

    <!-- Left cluster -->
    <div class="sb-topbar__left">

      <!-- Interface selector -->
      <div v-if="hasInterfaces" class="sb-iface-selector" ref="ifaceDropRef"
           @mouseenter="onIfaceEnter"
           @mouseleave="onIfaceLeave">
        <button class="sb-iface-btn" :class="{ open: ifaceOpen }"
                @click.stop="ifaceOpen = !ifaceOpen" aria-label="Select interface">
          <span class="sb-iface-btn__icon">
            <i :class="currentIfaceIcon"></i>
          </span>
          <span class="sb-iface-btn__name">{{ currentIfaceLabel }}</span>
          <span v-if="currentIsZmq && !isInfraView" class="sb-iface-btn__zmq" title="ZMQ interface">ZMQ</span>
          <span v-if="currentHasDrops && !isInfraView" class="sb-iface-btn__warn"
                :title="_i18n('if_stats.drops')" data-bs-toggle="tooltip" data-bs-placement="bottom">
            <i class="fas fa-exclamation-triangle"></i>
          </span>
          <i class="fas fa-chevron-down sb-iface-btn__caret" :class="{ rotated: ifaceOpen }"></i>
        </button>

        <Teleport to="body">
          <Transition name="sb-drop-anim">
            <div v-if="ifaceOpen" class="sb-iface-menu" :style="ifaceMenuStyle" @click.stop
                 @mouseenter="onIfaceEnter"
                 @mouseleave="onIfaceLeave">

              <div class="sb-iface-menu__section">
                <div class="sb-iface-menu__label">{{ _i18n("infrastructure_dashboard.interfaces") }}</div>

                <!-- System interface always first, standalone -->
                <template v-if="menu.system_ifid && menu.ifnames?.[menu.system_ifid]">
                  <a class="sb-iface-item sb-iface-item--system"
                     :class="{ 'sb-iface-item--active': menu.system_ifid === currentIfid }"
                     href="#" @click.prevent="selectSystemIface()">
                    <span class="sb-iface-item__icon"><i class="fas fa-cog text-muted"></i></span>
                    <span class="sb-iface-item__info">
                      <span class="sb-iface-item__name">{{ menu.ifHdescr?.[menu.system_ifid] || menu.ifnames?.[menu.system_ifid] }}</span>
                      <span class="sb-iface-item__tags"><span class="sb-iface-tag sb-iface-tag--sys">{{ _i18n("infrastructure_dashboard.tag_system") }}</span></span>
                    </span>
                    <i v-if="menu.system_ifid === currentIfid" class="fas fa-check sb-iface-item__check"></i>
                  </a>
                  <div class="sb-iface-menu__divider"></div>
                </template>

                <!-- ── Infrastructure mode: Local Instance as root ── -->
                <template v-if="menu.infrastructure_instances?.length">

                  <!-- Local Instance row (root) -->
                  <a class="sb-iface-item"
                     :class="{ 'sb-iface-item--active': !isInfraView }"
                     href="#" @click.prevent="selectInfraView(`${pfx}/lua/index.lua`)">
                    <span class="sb-iface-item__icon"><i class="fas fa-home text-muted"></i></span>
                    <span class="sb-iface-item__info">
                      <span class="sb-iface-item__name">{{ _i18n("infrastructure_dashboard.local_interfaces") }}</span>
                    </span>
                    <i v-if="!isInfraView" class="fas fa-check sb-iface-item__check"></i>
                  </a>

                  <!-- With ViewAll: ViewAll child of Local, sub-ifaces grandchildren -->
                  <template v-if="viewAllId">
                    <a class="sb-iface-item sb-iface-item--child"
                       :class="{ 'sb-iface-item--active': !isInfraView && viewAllId === currentIfid }"
                       href="#" @click.prevent="selectIface(viewAllId)">
                      <span class="sb-iface-tree-branch" aria-hidden="true"></span>
                      <span class="sb-iface-item__icon"><i class="fas fa-layer-group text-info"></i></span>
                      <span class="sb-iface-item__info">
                        <span class="sb-iface-item__name">{{ menu.ifHdescr?.[viewAllId] || menu.ifnames?.[viewAllId] || viewAllId }}</span>
                        <span class="sb-iface-item__tags">
                          <span class="sb-iface-tag sb-iface-tag--view">{{ _i18n("infrastructure_dashboard.tag_view_all") }}</span>
                          <span v-if="menu.drops?.[viewAllId]" class="sb-iface-tag sb-iface-tag--drop">{{ _i18n("infrastructure_dashboard.tag_drops") }}</span>
                        </span>
                      </span>
                      <i v-if="!isInfraView && viewAllId === currentIfid" class="fas fa-check sb-iface-item__check"></i>
                    </a>
                    <template v-for="id in subIfaceIds" :key="id">
                      <a class="sb-iface-item sb-iface-item--grandchild"
                         :class="{ 'sb-iface-item--active': !isInfraView && id === currentIfid }"
                         href="#" @click.prevent="selectIface(id)">
                        <span class="sb-iface-tree-branch sb-iface-tree-branch--spacer" aria-hidden="true"></span>
                        <span class="sb-iface-tree-branch" aria-hidden="true"></span>
                        <span class="sb-iface-item__icon">
                          <i v-if="menu.pcapdump?.[id]"       class="fas fa-file-archive text-secondary"></i>
                          <i v-else-if="menu.recording?.[id]" class="fas fa-circle text-danger"></i>
                          <i v-else-if="menu.zmqifs?.[id]"    class="fas fa-stream text-warning"></i>
                          <i v-else                           class="fas fa-ethernet text-muted"></i>
                        </span>
                        <span class="sb-iface-item__info">
                          <span class="sb-iface-item__name">{{ menu.ifHdescr?.[id] || menu.ifnames?.[id] || id }}</span>
                          <span class="sb-iface-item__tags">
                            <span v-if="menu.recording?.[id]" class="sb-iface-tag sb-iface-tag--rec">{{ _i18n("infrastructure_dashboard.tag_rec") }}</span>
                            <span v-if="menu.pcapdump?.[id]"  class="sb-iface-tag sb-iface-tag--pcap">{{ _i18n("infrastructure_dashboard.tag_pcap") }}</span>
                            <span v-if="menu.zmqifs?.[id]"    class="sb-iface-tag sb-iface-tag--zmq">{{ _i18n("infrastructure_dashboard.tag_zmq") }}</span>
                            <span v-if="menu.drops?.[id]"     class="sb-iface-tag sb-iface-tag--drop">{{ _i18n("infrastructure_dashboard.tag_drops") }}</span>
                          </span>
                        </span>
                        <i v-if="!isInfraView && id === currentIfid" class="fas fa-check sb-iface-item__check"></i>
                      </a>
                    </template>
                  </template>

                  <!-- No ViewAll: non-system ifaces as direct children of Local -->
                  <template v-else>
                    <template v-for="id in sortedIfaceIds" :key="id">
                      <a v-if="id !== menu.system_ifid"
                         class="sb-iface-item sb-iface-item--child"
                         :class="{ 'sb-iface-item--active': !isInfraView && id === currentIfid }"
                         href="#" @click.prevent="selectIface(id)">
                        <span class="sb-iface-tree-branch" aria-hidden="true"></span>
                        <span class="sb-iface-item__icon">
                          <i v-if="menu.views?.[id]"      class="fas fa-layer-group text-info"></i>
                          <i v-else-if="menu.pcapdump?.[id]"  class="fas fa-file-archive text-secondary"></i>
                          <i v-else-if="menu.recording?.[id]" class="fas fa-circle text-danger"></i>
                          <i v-else-if="menu.zmqifs?.[id]"    class="fas fa-stream text-warning"></i>
                          <i v-else                           class="fas fa-ethernet text-muted"></i>
                        </span>
                        <span class="sb-iface-item__info">
                          <span class="sb-iface-item__name">{{ menu.ifHdescr?.[id] || menu.ifnames?.[id] || id }}</span>
                          <span class="sb-iface-item__tags">
                            <span v-if="menu.views?.[id]"      class="sb-iface-tag sb-iface-tag--view">{{ _i18n("infrastructure_dashboard.tag_view") }}</span>
                            <span v-if="menu.recording?.[id]"  class="sb-iface-tag sb-iface-tag--rec">{{ _i18n("infrastructure_dashboard.tag_rec") }}</span>
                            <span v-if="menu.pcapdump?.[id]"   class="sb-iface-tag sb-iface-tag--pcap">{{ _i18n("infrastructure_dashboard.tag_pcap") }}</span>
                            <span v-if="menu.zmqifs?.[id]"     class="sb-iface-tag sb-iface-tag--zmq">{{ _i18n("infrastructure_dashboard.tag_zmq") }}</span>
                            <span v-if="menu.drops?.[id]"      class="sb-iface-tag sb-iface-tag--drop">{{ _i18n("infrastructure_dashboard.tag_drops") }}</span>
                          </span>
                        </span>
                        <i v-if="!isInfraView && id === currentIfid" class="fas fa-check sb-iface-item__check"></i>
                      </a>
                    </template>
                  </template>

                  <!-- Infrastructure Dashboard + remote instances -->
                  <div class="sb-iface-menu__divider"></div>
                  <a class="sb-iface-item"
                     :class="{ 'sb-iface-item--active': isInfraView }"
                     href="#" @click.prevent="selectInfraView(`${pfx}/lua/index.lua?view=infrastructure`)">
                    <span class="sb-iface-item__icon"><i class="fas fa-tachometer-alt text-info"></i></span>
                    <span class="sb-iface-item__info">
                      <span class="sb-iface-item__name">{{ _i18n("infrastructure_dashboard.infrastructure") }}</span>
                      <span class="sb-iface-item__tags"><span class="sb-iface-tag sb-iface-tag--view">{{ _i18n("infrastructure_dashboard.tag_dashboard") }}</span></span>
                    </span>
                    <i v-if="isInfraView" class="fas fa-check sb-iface-item__check"></i>
                  </a>
                  <a v-for="inst in menu.infrastructure_instances" :key="inst.id"
                     class="sb-iface-item sb-iface-item--child"
                     href="#" @click.prevent="selectInfraView(inst.info.url)">
                    <span class="sb-iface-tree-branch" aria-hidden="true"></span>
                    <span class="sb-iface-item__icon"><i class="fas fa-building text-muted"></i></span>
                    <span class="sb-iface-item__info">
                      <span class="sb-iface-item__name">{{ inst.info.name }}</span>
                    </span>
                  </a>

                </template>

                <!-- ── No infrastructure: original flat/tree layout ── -->
                <template v-else>

                  <!-- Tree layout: ViewAll as parent, sub-ifaces as children -->
                  <template v-if="viewAllId">
                    <a class="sb-iface-item"
                       :class="{ 'sb-iface-item--active': viewAllId === currentIfid }"
                       href="#" @click.prevent="selectIface(viewAllId)">
                      <span class="sb-iface-item__icon"><i class="fas fa-layer-group text-info"></i></span>
                      <span class="sb-iface-item__info">
                        <span class="sb-iface-item__name">{{ menu.ifHdescr?.[viewAllId] || menu.ifnames?.[viewAllId] || viewAllId }}</span>
                        <span class="sb-iface-item__tags">
                          <span class="sb-iface-tag sb-iface-tag--view">{{ _i18n("infrastructure_dashboard.tag_view_all") }}</span>
                          <span v-if="menu.drops?.[viewAllId]" class="sb-iface-tag sb-iface-tag--drop">{{ _i18n("infrastructure_dashboard.tag_drops") }}</span>
                        </span>
                      </span>
                      <i v-if="viewAllId === currentIfid" class="fas fa-check sb-iface-item__check"></i>
                    </a>
                    <template v-for="id in subIfaceIds" :key="id">
                      <a class="sb-iface-item sb-iface-item--child"
                         :class="{ 'sb-iface-item--active': id === currentIfid }"
                         href="#" @click.prevent="selectIface(id)">
                        <span class="sb-iface-tree-branch" aria-hidden="true"></span>
                        <span class="sb-iface-item__icon">
                          <i v-if="menu.pcapdump?.[id]"       class="fas fa-file-archive text-secondary"></i>
                          <i v-else-if="menu.recording?.[id]" class="fas fa-circle text-danger"></i>
                          <i v-else-if="menu.zmqifs?.[id]"    class="fas fa-stream text-warning"></i>
                          <i v-else                           class="fas fa-ethernet text-muted"></i>
                        </span>
                        <span class="sb-iface-item__info">
                          <span class="sb-iface-item__name">{{ menu.ifHdescr?.[id] || menu.ifnames?.[id] || id }}</span>
                          <span class="sb-iface-item__tags">
                            <span v-if="menu.recording?.[id]" class="sb-iface-tag sb-iface-tag--rec">{{ _i18n("infrastructure_dashboard.tag_rec") }}</span>
                            <span v-if="menu.pcapdump?.[id]"  class="sb-iface-tag sb-iface-tag--pcap">{{ _i18n("infrastructure_dashboard.tag_pcap") }}</span>
                            <span v-if="menu.zmqifs?.[id]"    class="sb-iface-tag sb-iface-tag--zmq">{{ _i18n("infrastructure_dashboard.tag_zmq") }}</span>
                            <span v-if="menu.drops?.[id]"     class="sb-iface-tag sb-iface-tag--drop">{{ _i18n("infrastructure_dashboard.tag_drops") }}</span>
                          </span>
                        </span>
                        <i v-if="id === currentIfid" class="fas fa-check sb-iface-item__check"></i>
                      </a>
                    </template>
                  </template>

                  <!-- Flat layout when no ViewAll -->
                  <template v-else>
                    <template v-for="id in sortedIfaceIds" :key="id">
                      <a class="sb-iface-item"
                         :class="{
                           'sb-iface-item--active': id === currentIfid,
                           'sb-iface-item--system': id === menu.system_ifid
                         }"
                         href="#" @click.prevent="selectIface(id)">
                        <span class="sb-iface-item__icon">
                          <i v-if="id === menu.system_ifid"              class="fas fa-cog text-muted"></i>
                          <i v-else-if="menu.views?.[id]"                class="fas fa-layer-group text-info"></i>
                          <i v-else-if="menu.pcapdump?.[id]"             class="fas fa-file-archive text-secondary"></i>
                          <i v-else-if="menu.recording?.[id]"            class="fas fa-circle text-danger"></i>
                          <i v-else-if="menu.zmqifs?.[id]"               class="fas fa-stream text-warning"></i>
                          <i v-else                                       class="fas fa-ethernet text-muted"></i>
                        </span>
                        <span class="sb-iface-item__info">
                          <span class="sb-iface-item__name">{{ menu.ifHdescr?.[id] || menu.ifnames?.[id] || id }}</span>
                          <span class="sb-iface-item__tags">
                            <span v-if="id === menu.system_ifid"   class="sb-iface-tag sb-iface-tag--sys">{{ _i18n("infrastructure_dashboard.tag_system") }}</span>
                            <span v-if="menu.views?.[id]"          class="sb-iface-tag sb-iface-tag--view">{{ _i18n("infrastructure_dashboard.tag_view") }}</span>
                            <span v-if="menu.recording?.[id]"      class="sb-iface-tag sb-iface-tag--rec">{{ _i18n("infrastructure_dashboard.tag_rec") }}</span>
                            <span v-if="menu.pcapdump?.[id]"       class="sb-iface-tag sb-iface-tag--pcap">{{ _i18n("infrastructure_dashboard.tag_pcap") }}</span>
                            <span v-if="menu.zmqifs?.[id]"         class="sb-iface-tag sb-iface-tag--zmq">{{ _i18n("infrastructure_dashboard.tag_zmq") }}</span>
                            <span v-if="menu.drops?.[id]"          class="sb-iface-tag sb-iface-tag--drop">{{ _i18n("infrastructure_dashboard.tag_drops") }}</span>
                          </span>
                        </span>
                        <i v-if="id === currentIfid" class="fas fa-check sb-iface-item__check"></i>
                      </a>
                    </template>
                  </template>

                </template>
              </div>

            </div>
          </Transition>
        </Teleport>
      </div>

      <!-- Sparklines (d3v7, refs driven) -->
      <div v-if="!menu.is_system_interface && !isInfraView && !menu.is_pcap_dump"
           class="sb-sparklines d-none d-md-flex">
        <div class="sb-spark-combined" :title="`↑ ${sparkLabels.up}  ↓ ${sparkLabels.dn}`">
          <svg ref="svgCombined" class="sb-spark"></svg>
          <div class="sb-spark-labels">
            <span class="sb-spark-val">
              <i class="fas fa-arrow-up sb-spark-arrow"></i>{{ sparkLabels.up }}
            </span>
            <span class="sb-spark-val">
              <i class="fas fa-arrow-down sb-spark-arrow"></i>{{ sparkLabels.dn }}
            </span>
          </div>
        </div>
      </div>

      <!-- License badge -->
      <a v-if="menu.license_badge" :href="menu.license_badge.url || `${pfx}/lua/license.lua`"
         target="_blank" rel="noopener" class="sb-license-badge d-none d-md-inline-flex">
        <span class="badge bg-warning text-dark">{{ menu.license_badge.label }}</span>
      </a>

      <div v-if="!isInfraView" class="network-load d-none d-lg-flex"></div>
    </div>

    <!-- Right cluster -->
    <div class="sb-topbar__right">

      <SearchBox :context="searchCtx" />

    </div>
  </nav>

  <!-- Update available banner -->
  <Transition name="sb-banner-anim">
    <div v-if="(updateStatus === 'update-avail' || updateStatus === 'upgrade-failure') && !updateBannerDismissed"
         class="sb-update-banner">
      <i class="fas fa-cloud-download-alt sb-update-banner__icon"></i>
      <span class="sb-update-banner__text">
        {{ _i18n("updates.new_update_available_banner") }}<template v-if="updateVersion">: <strong>{{ updateVersion }}</strong></template>
      </span>
      <button class="sb-update-banner__action" @click="openUpdatePopup">
        <i class="fas fa-download me-1"></i>{{ _i18n("updates.install_now_banner") }}
      </button>
      <button class="sb-update-banner__close" @click="dismissUpdate" title="Dismiss">
        <i class="fas fa-times"></i>
      </button>
    </div>
  </Transition>

  <!-- Footer: teleported into #n-container so it flows at the bottom of each page -->
  <Teleport to="#n-container">
    <footer id="n-footer" class="sb-footer">
      <div class="sb-footer__col">
        <a v-if="menu.version_full" href="https://www.ntop.org/products/traffic-analysis/ntop/"
           target="_blank" rel="noopener" v-html="menu.version_full"></a>
        <a v-else-if="menu.version" href="https://www.ntop.org/products/traffic-analysis/ntop/"
           target="_blank" rel="noopener">{{ menu.version }}</a>
        <span v-else-if="menu.product">{{ menu.product }}</span>
      </div>
      <div v-if="menu.copyright" class="sb-footer__col sb-footer__col--center" v-html="menu.copyright"></div>
      <div class="sb-footer__col sb-footer__col--right">
        <i class="fas fa-clock"></i> {{ currentTime }}<template v-if="menu.tzname"> &nbsp;{{ menu.tzname }}</template>
        <template v-if="currentUptime"><span class="sb-footer__sep">|</span>Uptime: {{ currentUptime }}</template>
      </div>
    </footer>
  </Teleport>

  <!-- Restart modal -->
  <div class="modal fade" id="restart-modal" tabindex="-1">
    <div class="modal-dialog modal-sm">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">{{ _i18n("restart.restart") }}</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
        </div>
        <div class="modal-body">{{ _i18n("restart.confirm").replace(/%\{product\}/g, menu.product || "ntopng") }}</div>
        <div class="modal-footer">
          <button class="btn btn-secondary btn-sm" data-bs-dismiss="modal">{{ _i18n("cancel") }}</button>
          <button class="btn btn-danger btn-sm" @click="doRestart">{{ _i18n("restart.restart") }}</button>
        </div>
      </div>
    </div>
  </div>

  <!-- Logout modal -->
  <div class="modal fade" id="logout-modal" tabindex="-1">
    <div class="modal-dialog modal-sm">
      <div class="modal-content">
        <div class="modal-header">
          <h5 class="modal-title">{{ _i18n("login.logout") }}</h5>
          <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
        </div>
        <div class="modal-body">{{ _i18n("login.logout_message") }}</div>
        <div class="modal-footer">
          <button class="btn btn-secondary btn-sm" data-bs-dismiss="modal">{{ _i18n("cancel") }}</button>
          <button class="btn btn-danger btn-sm" @click="doLogout">{{ _i18n("login.logout") }}</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch, nextTick } from "vue";
import { ntopng_utility } from "../services/context/ntopng_globals_services.js";
import { default as SearchBox } from "./components/search-box.vue";
import NtopUtils from "../utilities/ntop-utils";
const d3 = d3v7;

const props = defineProps({ context: Object });
const ctx   = computed(() => props.context || {});

const pfx = computed(() =>
  ctx.value.http_prefix || (typeof http_prefix !== "undefined" ? http_prefix : "")
);

const _i18n = (t) => i18n(t);

// Updates state
const updateStatus           = ref("");
const updateVersion          = ref("");
const dismissedUpdateVersion = ref("");  // version stored in Redis as dismissed
const updateBannerDismissed  = computed(() =>
  dismissedUpdateVersion.value !== "" && dismissedUpdateVersion.value === updateVersion.value
);

// State
const menu           = ref({});
const hoveredSection = ref(null);  // currently hovered (transient)
const lockedSection  = ref(null);  // clicked/locked open
const isPanelOpen    = ref(false);
const userPopupOpen  = ref(false);
const blogExpanded   = ref(false);
const railHovered    = ref(false); // rail hover -> expand all labels
const avatarBtn      = ref(null);  // ref to avatar button element
const ifaceDropRef   = ref(null);  // interface selector button
const railNav        = ref(null);  // ref to scrollable nav area
const navOverflow    = ref(false); // true when items are hidden below visible area
const navCanScrollUp = ref(false); // true when scrolled down (items hidden above)
const ifaceOpen      = ref(false);
const locationHref   = ref(window.location.href);
let ifaceLeaveTimer  = null;
let railNavObserver  = null;

function checkNavOverflow() {
  if (!railNav.value) return;
  const el = railNav.value;
  navCanScrollUp.value = el.scrollTop > 4;
  navOverflow.value    = (el.scrollHeight - el.scrollTop) > el.clientHeight + 4;
}

function onIfaceEnter() { window.clearTimeout(ifaceLeaveTimer); }
function onIfaceLeave() { ifaceLeaveTimer = window.setTimeout(() => { ifaceOpen.value = false; }, 200); }

function selectSystemIface() {
  const sysId = String(menu.value.system_ifid || "");
  if (sysId) selectIface(sysId);
}


// Popup opens above the avatar button, aligned to the left edge of the rail
const popupStyle = computed(() => {
  if (!avatarBtn.value) return {};
  const rect = avatarBtn.value.getBoundingClientRect();
  return { bottom: (window.innerHeight - rect.top + 4) + "px", left: "0" };
});

// Interface dropdown positioned below the trigger button
const ifaceMenuStyle = computed(() => {
  if (!ifaceDropRef.value) return {};
  const rect = ifaceDropRef.value.getBoundingClientRect();
  return { top: (rect.bottom + 4) + "px", left: rect.left + "px" };
});

// The panel shows: locked section if any, otherwise hovered
const currentPanelSection = computed(() => lockedSection.value || hoveredSection.value);

const activeSection = computed(() => {
  if (ctx.value.active_section) return ctx.value.active_section;
  const pathname = new URL(locationHref.value).pathname;
  for (const section of (menu.value.sections || [])) {
    for (const entry of (section.entries || [])) {
      if (!entry.url || entry.is_divider) continue;
      try {
        const ep = new URL(entry.url, window.location.origin).pathname;
        if (ep === pathname) return section.key;
      } catch (_) {}
    }
  }
  return "";
});

const activeEntry = computed(() => {
  if (ctx.value.active_entry) return ctx.value.active_entry;
  const pathname = new URL(locationHref.value).pathname;
  for (const section of (menu.value.sections || [])) {
    for (const entry of (section.entries || [])) {
      if (!entry.url || entry.is_divider) continue;
      try {
        const ep = new URL(entry.url, window.location.origin).pathname;
        if (ep === pathname) return entry.key;
      } catch (_) {}
    }
  }
  return "";
});

// Theme: initialised from DOM (set by page_utils.lua before Vue mounts),
// then kept in sync by toggleTheme() so the toggle is instant.
function readDomTheme() {
  const html = document.documentElement;
  return html.getAttribute("data-theme") === "dark"
    || html.getAttribute("data-bs-theme") === "dark"
    || html.classList.contains("dark-mode")
    || document.body?.classList.contains("dark-mode")
    || document.body?.classList.contains("dark");
}
const isDark = ref(readDomTheme());

const userInitials = computed(() => {
  const u = (menu.value.username || "").trim();
  if (!u) return "U";
  const parts = u.split(/[\s._@-]+/).filter(Boolean);
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return u.slice(0, 2).toUpperCase();
});

// Menu data
async function loadMenu() {
  const ifid = ctx.value.ifid || (typeof interfaceID !== "undefined" ? interfaceID : 0);
  const view = new URL(locationHref.value).searchParams.get("view") || "";
  const viewParam = view ? `&view=${encodeURIComponent(view)}` : "";
  try {
    const data = await ntopng_utility.http_request(
      `${pfx.value}/lua/rest/v2/get/ntopng/menu.lua?ifid=${ifid}${viewParam}`
    );
    if (data) {
      menu.value = data;
      clockLoadedAt  = Date.now();
      if (data.server_epoch) clockEpochBase = data.server_epoch;
      if (data.uptime_epoch) uptimeBase     = data.uptime_epoch;
    }
  } catch (_) {}
}

// Menu helpers
const visibleSections = computed(() =>
  (menu.value.sections || []).filter(s => !s.hidden)
);

function visibleEntries(section) {
  const entries = (section?.entries || []).filter(e => !e.hidden);
  // Remove leading, trailing, and consecutive dividers
  return entries.filter((e, i, arr) => {
    if (!e.is_divider) return true;
    const prev = arr.slice(0, i).find(x => !x.is_divider);
    const next = arr.slice(i + 1).find(x => !x.is_divider);
    return !!(prev && next);
  });
}

function hasEntries(section) {
  return !!(section?.entries?.filter(e => !e.hidden).length);
}

// Switch interface: POST switch_interface=1 via fetch (no page reload) so C++
// persists the new ifid to the Redis session, then navigate via GET.
// This avoids the form-submit → redirect double round-trip and the blank flash.
async function selectIface(targetIfid) {
  if (!targetIfid) return;
  const sysId  = String(menu.value.system_ifid || "");
  const target = String(targetIfid);

  // Build destination URL: same logic as page_utils.switch_interface_form_action_url
  let actionUrl;
  if (target === sysId) {
    actionUrl = `${pfx.value}/lua/system_stats.lua?ifid=${target}`;
  } else if (currentIfid.value === sysId) {
    actionUrl = `${pfx.value}/lua/index.lua?ifid=${target}`;
  } else {
    // Preserve current page and all its params, only swap ifid
    const u = new URL(locationHref.value);
    u.searchParams.set("ifid", target);
    u.searchParams.delete("observationPointId");
    actionUrl = u.toString();
  }

  locationHref.value = actionUrl;
  ifaceOpen.value = false;

  // POST to persist the session, then navigate — avoids redirect round-trip
  const csrf = ctx.value.csrf || window.__CSRF_DATATABLE__ || "";
  const body = new URLSearchParams({ switch_interface: "1" });
  if (csrf) body.set("csrf", csrf);
  try {
    await fetch(actionUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
      redirect: "manual",  // don't follow the C++ redirect — we navigate ourselves
    });
  } catch (_) {}
  window.location.href = actionUrl;
}

function selectInfraView(url) {
  locationHref.value = new URL(url, window.location.origin).href;
  ifaceOpen.value = false;
  loadMenu();
  window.location.href = url;
}

// Interface helpers
const hasInterfaces = computed(() =>
  (menu.value.ifnames && Object.keys(menu.value.ifnames).length > 1) ||
  !!(menu.value.infrastructure_instances?.length)
);

// Sorted interface ids: system first, then alphabetically by display name
const sortedIfaceIds = computed(() => {
  const ifnames = menu.value.ifnames || {};
  const sysId   = menu.value.system_ifid;
  return Object.keys(ifnames).sort((a, b) => {
    if (a === sysId) return -1;
    if (b === sysId) return  1;
    const na = menu.value.ifHdescr?.[a] || ifnames[a] || a;
    const nb = menu.value.ifHdescr?.[b] || ifnames[b] || b;
    return na.localeCompare(nb);
  });
});

// Ground-truth current ifid: read from URL ifid param so it survives navigation,
// fall back to menu response, then page boot context. Always a string.
const currentIfid = computed(() => {
  const urlIfid = new URL(locationHref.value).searchParams.get("ifid");
  if (urlIfid) return String(urlIfid);
  if (menu.value.current_ifid) return String(menu.value.current_ifid);
  return String(ctx.value.ifid || (typeof interfaceID !== "undefined" ? interfaceID : 0) || "");
});

// True when in infrastructure view — check both server flag and reactive URL
const isInfraView = computed(() => {
  if (menu.value.infrastructure_view) return true;
  try {
    return new URL(locationHref.value).searchParams.get("view") === "infrastructure";
  } catch (_) { return false; }
});

const currentIfaceLabel = computed(() => {
  if (isInfraView.value) return _i18n("infrastructure_dashboard.infrastructure");
  const id = currentIfid.value;
  if (!id) return "";
  return (menu.value.ifHdescr && menu.value.ifHdescr[id])
    || (menu.value.ifnames && menu.value.ifnames[id]) || "";
});

const currentHasDrops = computed(() => {
  const id = currentIfid.value;
  return !!(id && menu.value.drops && menu.value.drops[id]);
});

const currentIsZmq = computed(() => {
  const id = currentIfid.value;
  return !!(id && menu.value.zmqifs && menu.value.zmqifs[id]);
});

const currentIfaceIcon = computed(() => {
  if (isInfraView.value) return "fas fa-tachometer-alt";
  const id = currentIfid.value;
  if (!id) return "fas fa-ethernet";
  if (id === menu.value.system_ifid)       return "fas fa-cog";
  if (menu.value.views?.[id])              return "fas fa-layer-group";
  if (menu.value.pcapdump?.[id])           return "fas fa-file-archive";
  if (menu.value.recording?.[id])          return "fas fa-circle text-danger";
  if (menu.value.zmqifs?.[id])             return "fas fa-stream";
  return "fas fa-ethernet";
});

// ViewAll tree: viewAllId is the single view interface id (if exactly one view exists)
const viewAllId = computed(() => {
  const views = menu.value.views;
  if (!views) return null;
  const ids = Object.keys(views);
  return ids.length > 0 ? ids[0] : null;
});

// Sub-interfaces: all non-system, non-view interfaces when ViewAll is present
const subIfaceIds = computed(() => {
  if (!viewAllId.value || !menu.value.ifnames) return [];
  const sysId = menu.value.system_ifid;
  return Object.keys(menu.value.ifnames).filter(id =>
    id !== viewAllId.value && id !== sysId
  ).sort((a, b) => {
    const na = menu.value.ifHdescr?.[a] || menu.value.ifnames[a] || a;
    const nb = menu.value.ifHdescr?.[b] || menu.value.ifnames[b] || b;
    return na.localeCompare(nb);
  });
});

const hasBlogPosts = computed(() =>
  Array.isArray(menu.value.blog_posts) && menu.value.blog_posts.length > 0
);

const hasAdminNotifications = computed(() =>
  (menu.value.new_posts_counter > 0) ||
  updateStatus.value === "update-avail" ||
  updateStatus.value === "upgrade-failure"
);

const searchCtx = computed(() => ({
  ifid: ctx.value.ifid || (typeof interfaceID !== "undefined" ? interfaceID : 0),
}));

const manageUserLabel = computed(() => {
  const tpl =_i18n("manage_users.manage_user_x");
  return tpl.replace ? tpl.replace(/%\{user\}/g, menu.value.username || "") : tpl;
});

// Panel open/close logic
// Hover opens transiently. Click locks open (toggle). Mouse leaving both
// rail and panel closes only if NOT locked.
let railLeaveTimer  = null;
let panelLeaveTimer = null;

function onRailEnter() {
  clearTimeout(railLeaveTimer);
  clearTimeout(panelLeaveTimer);
  railHovered.value = true;
  ifaceOpen.value = false;
}

function onRailLeave() {
  if (isPanelOpen.value) return;   // keep labels visible while panel is open
  railHovered.value = false;
  if (lockedSection.value) return;
  railLeaveTimer = setTimeout(() => {
    isPanelOpen.value = false;
    hoveredSection.value = null;
  }, 120);
}

function onPanelEnter() {
  clearTimeout(railLeaveTimer);
  clearTimeout(panelLeaveTimer);
}

function onPanelLeave() {
  if (lockedSection.value) return; // locked — never close on panel leave
  panelLeaveTimer = setTimeout(() => {
    isPanelOpen.value = false;
    hoveredSection.value = null;
    railHovered.value = false;    // collapse labels once panel fully closes
  }, 120);
}

function sectionHasPanel(section) {
  return hasEntries(section) || section.key === "about";
}

function onSectionHover(section) {
  clearTimeout(railLeaveTimer);
  clearTimeout(panelLeaveTimer);
  userPopupOpen.value = false;
  hoveredSection.value = section;
  if (sectionHasPanel(section)) {
    isPanelOpen.value = true;
  } else {
    if (!lockedSection.value) {
      isPanelOpen.value = false;
    }
  }
}

function onSectionClick(section) {
  userPopupOpen.value = false;
  if (!sectionHasPanel(section)) {
    if (section.url) window.location.href = section.url;
    return;
  }
  // Toggle lock
  if (lockedSection.value?.key === section.key) {
    lockedSection.value = null;
    isPanelOpen.value = false;
    hoveredSection.value = null;
  } else {
    lockedSection.value = section;
    hoveredSection.value = section;
    isPanelOpen.value = true;
  }
}

function closePanel() {
  lockedSection.value = null;
  isPanelOpen.value = false;
  hoveredSection.value = null;
}

// User popup
let avatarLeaveTimer = null;

function onAvatarEnter() {
  clearTimeout(avatarLeaveTimer);
  userPopupOpen.value = true;
  isPanelOpen.value = false;
}

function onAvatarLeave() {
  avatarLeaveTimer = setTimeout(() => { userPopupOpen.value = false; }, 200);
}

function applyLayout() {
  const html = document.documentElement;
  // Override --sidebar-width so sidebar.scss calc(var(--sidebar-width)+1rem) = 1rem
  // which our padding-left:0 below then kills completely.
  // Inline style on html beats any stylesheet including white-mode.css.
  html.style.setProperty("--sidebar-width", "0px");
  html.style.setProperty("--sb-rail-w",    "4rem");
  html.style.setProperty("--sb-rail-exp",  "14.5rem");
  html.style.setProperty("--sb-navbar-h",  "3rem");

  const ct = document.getElementById("n-container");
  if (ct) {
    const p = (k, v) => ct.style.setProperty(k, v, "important");
    p("padding-left",  "0.75rem");
    p("padding-right", "0.75rem");
    p("padding-top",   "calc(3rem + 0.5rem)");
    p("margin-left",   "4rem");
    p("margin-right",  "0");
    p("margin-top",    "0");
    p("width",         "auto");
    p("max-width",     "none");
    p("display",       "block");
    p("box-sizing",    "border-box");
  }

  // Kill .body padding-top from white-mode.scss (4.5rem)
  document.querySelectorAll(".body").forEach(el => {
    el.style.setProperty("padding-top", "0", "important");
  });
}

// Click outside
function handleOutsideClick(e) {
  const inRail  = e.target.closest("#n-sidebar");
  const inPanel = e.target.closest(".sb-panel");
  const inPopup = e.target.closest(".sb-user-popup");

  if (!inRail && !inPanel) {
    lockedSection.value = null;
    isPanelOpen.value = false;
    hoveredSection.value = null;
  }
  if (!inRail && !inPopup) {
    userPopupOpen.value = false;
  }
  if (!e.target.closest(".sb-iface-selector") && !e.target.closest(".sb-iface-menu")) {
    ifaceOpen.value = false;
  }
}

// Sparklines d3v7
let pollTimer = null;
const SPARK_W = 100;
const SPARK_H = 30;
const MAX_PTS = 30;

const svgCombined = ref(null);
const sparkLabels  = ref({ up: "", dn: "" });

let spark  = null;
let seeded = false;

function buildCombinedSparkline(svgEl) {
  if (!svgEl || !window.d3v7) return null;
  const d3 = d3v7;
  const dataUp = [];
  const dataDn = [];

  const svg = d3.select(svgEl).attr("width", SPARK_W).attr("height", SPARK_H);

  svg.append("line").attr("class", "spark-center")
    .attr("x1", 0).attr("x2", SPARK_W)
    .attr("y1", SPARK_H / 2).attr("y2", SPARK_H / 2)
    .attr("stroke", "rgba(128,128,128,0.25)").attr("stroke-width", 0.5);

  svg.append("path").attr("class", "spark-up-area")
    .attr("fill", "rgba(86,204,242,0.18)").attr("stroke", "none");
  svg.append("path").attr("class", "spark-up-line")
    .attr("fill", "none").attr("stroke", "#56CCF2")
    .attr("stroke-width", 1.5).attr("stroke-linejoin", "round");

  svg.append("path").attr("class", "spark-dn-area")
    .attr("fill", "rgba(111,207,151,0.22)").attr("stroke", "none");
  svg.append("path").attr("class", "spark-dn-line")
    .attr("fill", "none").attr("stroke", "#6FCF97")
    .attr("stroke-width", 1.5).attr("stroke-linejoin", "round");

  function redraw() {
    const n   = Math.max(dataUp.length, dataDn.length, 2);
    const max = Math.max(d3.max(dataUp) || 0, d3.max(dataDn) || 0, 1);

    const xScale = d3.scaleLinear().domain([0, n - 1]).range([0, SPARK_W]);
    const yUp    = d3.scaleLinear().domain([0, max]).range([SPARK_H / 2, 0]);
    const yDn    = d3.scaleLinear().domain([0, max]).range([SPARK_H / 2, SPARK_H]);

    const lineUp  = d3.line().x((_, i) => xScale(i)).y(d => yUp(d)).curve(d3.curveMonotoneX);
    const lineDn  = d3.line().x((_, i) => xScale(i)).y(d => yDn(d)).curve(d3.curveMonotoneX);
    const areaUp  = d3.area().x((_, i) => xScale(i)).y0(SPARK_H / 2).y1(d => yUp(d)).curve(d3.curveMonotoneX);
    const areaDn  = d3.area().x((_, i) => xScale(i)).y0(SPARK_H / 2).y1(d => yDn(d)).curve(d3.curveMonotoneX);

    svg.select(".spark-up-area").datum(dataUp).attr("d", areaUp);
    svg.select(".spark-up-line").datum(dataUp).attr("d", lineUp);
    svg.select(".spark-dn-area").datum(dataDn).attr("d", areaDn);
    svg.select(".spark-dn-line").datum(dataDn).attr("d", lineDn);
  }

  return {
    seedUp(arr) { arr.slice(-MAX_PTS).forEach(v => dataUp.push(v)); },
    seedDn(arr) { arr.slice(-MAX_PTS).forEach(v => dataDn.push(v)); },
    pushBoth(u, dn) {
      dataUp.push(u);  if (dataUp.length > MAX_PTS) dataUp.shift();
      dataDn.push(dn); if (dataDn.length > MAX_PTS) dataDn.shift();
      redraw();
    },
    redraw,
  };
}

function tryInitSpark() {
  if (spark || !window.d3v7 || !svgCombined.value) return;
  spark = buildCombinedSparkline(svgCombined.value);
}

async function pollIface() {
  tryInitSpark();
  const ifid = ctx.value.ifid || (typeof interfaceID !== "undefined" ? interfaceID : 0);
  try {
    const d = await ntopng_utility.http_request(
      `${pfx.value}/lua/rest/v2/get/interface/data.lua?ifid=${ifid}`
    );
    if (!d) return;
    const r = d.rsp || d;

    // Seed history on first response (C++ stores KB/s -> convert to bps)
    if (!seeded && spark) {
      const histUp = (r.download_upload_chart?.upload   || []).map(v => v * 8000);
      const histDn = (r.download_upload_chart?.download || []).map(v => v * 8000);
      if (histUp.length || histDn.length) {
        spark.seedUp(histUp);
        spark.seedDn(histDn);
        spark.redraw();
      }
      seeded = true;
    }

    const upBps = r.throughput?.upload?.bps * 8   ?? r.bytes_upload;
    const dnBps = r.throughput?.download?.bps * 8 ?? r.bytes_download;
    if (upBps != null && dnBps != null) {
      spark?.pushBoth(upBps, dnBps);
      sparkLabels.value.up = NtopUtils.bitsToSize(upBps, 1000);
      sparkLabels.value.dn = NtopUtils.bitsToSize(dnBps, 1000);
    }

    if (window.ntopng_events_manager && window.ntopng_custom_events)
      ntopng_events_manager.emit_custom_event(ntopng_custom_events.GET_INTERFACE_DATA, r);

    buildNetworkLoad(r);
  } catch (_) {}
}

// Network load badges
function buildNetworkLoad(r) {
  const el = document.querySelector(".network-load");
  if (!el) return;

  const isSys    = currentIfid.value === String(menu.value.system_ifid || "");
  const pfxVal   = pfx.value;
  const ifidVal  = ctx.value.ifid || (typeof interfaceID !== "undefined" ? interfaceID : 0);
  const ALARM_LO = 60;
  const ALARM_HI = 90;
  const fmt      = (v) => window.NtopUtils ? NtopUtils.formatValue(v, 1) : String(v);
  const tooltip  = (text) => `data-bs-toggle="tooltip" data-bs-placement="bottom" title="${text}"`;

  let msg = `<div class='d-flex gap-1 navbar-main-badges flex-nowrap'>`;

  if (r.out_of_maintenance) {
    msg += `<a href='https://www.ntop.org/support/faq/how-can-i-renew-maintenance-for-commercial-products/' target='_blank'>
      <span class='badge bg-warning'>${_i18n("about.maintenance_expired")} <i class="fas fa-external-link-alt"></i></span></a>`;
  }

  if (r.degraded_performance) {
    msg += `<a href='${pfxVal}/lua/system_interfaces_stats.lua?page=internals&tab=periodic_activities&periodic_script_issue=any_issue'>
      <span class='badge bg-warning' ${tooltip(_i18n("internals.degraded_performance"))}><i class='fas fa-exclamation-triangle'></i></span></a>`;
  }

  if (r.engaged_alerts > 0) {
    let cls = "bg-info";
    if (r.engaged_alerts_error > 0)        cls = "bg-danger";
    else if (r.engaged_alerts_warning > 0) cls = "bg-warning";
    msg += `<a href='${pfxVal}/lua/alert_stats.lua?ifid=${ifidVal}&status=engaged'>
      <span class="badge ${cls}" ${tooltip(_i18n("graphs.engaged_alerts"))}><i class="fas fa-exclamation-triangle"></i> ${fmt(r.engaged_alerts)}</span></a>`;
  }

  if (!isSys) {
    if (r.alerted_flows_warning > 0) {
      msg += `<a href='${pfxVal}/lua/flows_stats.lua?status=warning'>
        <span class="badge bg-warning" ${tooltip(_i18n("flow_details.alerted_flows"))}>${fmt(r.alerted_flows_warning)} <i class="fas fa-stream"></i> <i class="fas fa-exclamation-triangle"></i></span></a>`;
    }
    if (r.alerted_flows_error > 0) {
      msg += `<a href='${pfxVal}/lua/flows_stats.lua?status=error'>
        <span class="badge bg-danger" ${tooltip(_i18n("flow_details.dangerous_flows"))}>${fmt(r.alerted_flows_error)} <i class="fas fa-stream"></i> <i class="fas fa-exclamation-triangle"></i></span></a>`;
    }
    if (r.active_discovery_active === true) {
      msg += `<a href='${pfxVal}/lua/discover.lua'>
        <span class="badge bg-warning" ${tooltip(_i18n("prefs.network_discovery_running"))}><i class="fas fa-project-diagram"></i></span></a>`;
    }
    if (r.ts_alerts?.influxdb) {
      msg += `<a href='${pfxVal}/lua/monitor/influxdb_monitor.lua?ifid=${ifidVal}&page=alerts#tab-table-engaged-alerts'>
        <span class="badge bg-danger" ${tooltip(_i18n("alerts_dashboard.influxdb_error"))}><i class="fas fa-database"></i></span></a>`;
    }
    if (r.num_local_hosts > 0) {
      msg += `<a href='${pfxVal}/lua/hosts_stats.lua?mode=local'>
        <span class="badge bg-success" ${tooltip(_i18n("local_hosts"))}>${fmt(r.num_local_hosts)}`;
      if (r.num_local_rcvd_only_hosts > 0) msg += ` (${fmt(r.num_local_rcvd_only_hosts)})`;
      msg += ` <i class="fas fa-laptop"></i></span></a>`;
    }
    const numRemote = (r.num_hosts || 0) - (r.num_local_hosts || 0);
    if (numRemote > 0) {
      let cls = r.hosts_pctg >= ALARM_HI ? "bg-danger" : r.hosts_pctg >= ALARM_LO ? "bg-warning" : "bg-secondary";
      msg += `<a href='${pfxVal}/lua/hosts_stats.lua?mode=remote'>
        <span class="badge ${cls}" ${tooltip(_i18n("remote_hosts"))}>${fmt(numRemote)}`;
      const remRcvd = (r.num_rcvd_only_hosts || 0) - (r.num_local_rcvd_only_hosts || 0);
      if (remRcvd > 0) msg += ` (${fmt(remRcvd)})`;
      msg += ` <i class="fas fa-laptop"></i></span></a>`;
    }
    if (r.num_devices > 0) {
      let cls = r.macs_pctg >= ALARM_HI ? "bg-danger" : r.macs_pctg >= ALARM_LO ? "bg-warning" : "bg-secondary";
      msg += `<a href='${pfxVal}/lua/macs_stats.lua?devices_mode=source_macs_only'>
        <span class="badge ${cls}" ${tooltip(_i18n("mac_stats.layer_2_source_devices").replace("%{device_type}", fmt(r.num_devices)))}>${fmt(r.num_devices)} <i class="fas fa-ethernet"></i></span></a>`;
    }
    if (r.num_flows > 0) {
      let cls = r.flows_pctg >= ALARM_HI ? "bg-danger" : r.flows_pctg >= ALARM_LO ? "bg-warning" : "bg-secondary";
      msg += `<a href='${pfxVal}/lua/flows_stats.lua'>
        <span class="badge ${cls}" ${tooltip(_i18n("live_flows"))}>${fmt(r.num_flows)} <i class="fas fa-stream"></i></span></a>`;
      if (r.db?.flow_export_drops > 0) {
        const pctg = r.db.flow_export_drops / (r.db.flow_export_count + r.db.flow_export_drops + 1);
        if (pctg > 0.05) {
          const bc = pctg <= 0.1 ? "warning" : "danger";
          msg += `<a href='${pfxVal}/lua/if_stats.lua'>
            <span class="badge bg-${bc}" ${tooltip(_i18n("flow_export_drops"))}><i class="fas fa-exclamation-triangle"></i> ${fmt(r.db.flow_export_drops)} DB drop${r.db.flow_export_drops > 1 ? "s" : ""}</span></a>`;
        }
      }
      if (r.dropped_zmq_msg > 0) {
        msg += `<a href='${pfxVal}/lua/if_stats.lua'>
          <span class="badge bg-warning" ${tooltip(_i18n("dropping_zmq_msg"))}><i class="fas fa-tint"></i> ${fmt(r.dropped_zmq_msg)} ZMQ</span></a>`;
      }
      if (r.dropped_flows > 0) {
        msg += `<a href='${pfxVal}/lua/if_stats.lua'>
          <span class="badge bg-warning" ${tooltip(_i18n("dropping_flows"))}><i class="fas fa-tint"></i> ${fmt(r.dropped_flows)} Flows Drops</span></a>`;
      }
    }
    if (r.num_live_captures > 0) {
      msg += `<a href='${pfxVal}/lua/live_capture_stats.lua'>
        <span class="badge bg-primary" ${tooltip(_i18n("live_capture.active_live_captures"))}>${window.NtopUtils ? NtopUtils.addCommas(r.num_live_captures) : r.num_live_captures} <i class="fas fa-download fa-lg"></i></span></a>`;
    }
    if (r.traffic_recording !== undefined) {
      const cls = r.traffic_recording === "recording" ? "bg-primary" : "bg-danger";
      const lbl = r.traffic_recording === "recording" ?_i18n("traffic_recording.recording") :_i18n("traffic_recording.failure");
      msg += `<a href='${pfxVal}/lua/if_stats.lua?ifid=${ifidVal}&page=traffic_recording&tab=status'>
        <span class="badge ${cls}" ${tooltip(lbl)}><i class="fas fa-hdd fa-lg"></i></span></a>`;
    }
    if (r.traffic_extraction !== undefined) {
      const cls = r.traffic_extraction === "ready" ? "bg-primary" : "bg-secondary";
      msg += `<a href='${pfxVal}/lua/if_stats.lua?ifid=${ifidVal}&page=traffic_recording&tab=jobs'>
        <span class="badge ${cls}" ${tooltip(_i18n("traffic_recording.traffic_extraction_jobs"))}>${r.traffic_extraction_num_tasks || 0} <i class="fas fa-tasks fa-lg"></i></span></a>`;
    }
    if (r.vs_in_progress > 0) {
      msg += `<a href='${pfxVal}/lua/vulnerability_scan.lua'>
        <span class="badge bg-primary" ${tooltip(_i18n("vulnerability_scan.vulnerability_scan_in_progress"))}>${window.NtopUtils ? NtopUtils.addCommas(r.vs_in_progress) : r.vs_in_progress} <i class="fas fa-satellite-dish"></i></span></a>`;
    }
  }

  if (r.is_loading === true) {
    msg += `<span class="badge bg-primary"><i class="fas fa-spinner fa-spin"></i> ${_i18n("loading")}</span>`;
  }

  msg += `</div>`;
  el.innerHTML = msg;

  if (window.bootstrap) {
    el.querySelectorAll("[data-bs-toggle='tooltip']").forEach(node => {
      try { new bootstrap.Tooltip(node); } catch (_) {}
    });
  }
}

// Theme toggle
function applyTheme(dark) {
  const html  = document.documentElement;
  const body  = document.body;
  const sheet = document.getElementById("dark-mode-css");

  html.setAttribute("data-theme",    dark ? "dark" : "light");
  html.setAttribute("data-bs-theme", dark ? "dark" : "light");
  body?.classList.toggle("dark",      dark);
  body?.classList.toggle("dark-mode", dark);
  if (sheet) sheet.disabled = !dark;
}

function toggleTheme() {
  const nextDark = !isDark.value;
  isDark.value = nextDark;
  applyTheme(nextDark);

  // Persist preference in the background — no reload needed
  ntopng_utility.http_request(`${pfx.value}/lua/update_prefs.lua`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      action: "toggle_theme",
      toggle_dark_theme: nextDark ? "true" : "false",
      csrf: ctx.value.csrf || window.__CSRF_DATATABLE__ || "",
    }),
  }).catch(() => {});
}

// nEdge power off / reboot
let nedgePowerOffModal = null;
let nedgeRebootModal   = null;

function confirmNedgePowerOff() {
  userPopupOpen.value = false;
  if (!nedgePowerOffModal) {
    const el = document.getElementById("poweroff_dialog");
    if (el && window.bootstrap) nedgePowerOffModal = new bootstrap.Modal(el);
  }
  nedgePowerOffModal?.show();
}

function confirmNedgeReboot() {
  userPopupOpen.value = false;
  if (!nedgeRebootModal) {
    const el = document.getElementById("reboot_dialog");
    if (el && window.bootstrap) nedgeRebootModal = new bootstrap.Modal(el);
  }
  nedgeRebootModal?.show();
}

// Restart
let restartModal = null;

function confirmRestart() {
  if (!restartModal) {
    const el = document.getElementById("restart-modal");
    if (el && window.bootstrap) restartModal = new bootstrap.Modal(el);
  }
  restartModal?.show();
}

async function doRestart() {
  restartModal?.hide();
  try {
    await ntopng_utility.http_request(`${pfx.value}/lua/admin/service_restart.lua`, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ csrf: ctx.value.csrf || window.__CSRF_DATATABLE__ || "" }),
    });
    setTimeout(() => window.location.reload(), 4000);
  } catch (_) {}
}

// Logout
let logoutModal = null;

function confirmLogout() {
  if (!logoutModal) {
    const el = document.getElementById("logout-modal");
    if (el && window.bootstrap) logoutModal = new bootstrap.Modal(el);
  }
  logoutModal?.show();
}

function doLogout() {
  logoutModal?.hide();
  window.location.href = `${pfx.value}/lua/ntopng_logout.lua`;
}

function triggerPasswordDialog(username) {
  if (typeof window.reset_pwd_dialog === "function") window.reset_pwd_dialog(username);
}

// Info tooltip: clock + license copy
const currentTime   = ref("");
const currentUptime = ref("");
const copiedLicense = ref(false);
let clockTimer      = null;
let clockEpochBase  = 0;   // server epoch at menu load time
let clockLoadedAt   = 0;   // client ms when menu was loaded
let uptimeBase      = 0;   // server uptime seconds at menu load time

function formatUptime(secs) {
  const d = Math.floor(secs / 86400);
  const h = Math.floor((secs % 86400) / 3600);
  const m = Math.floor((secs % 3600) / 60);
  const s = secs % 60;
  if (d > 0) return `${d}d ${h}h ${m}m ${s}s`;
  if (h > 0) return `${h}h ${m}m ${s}s`;
  if (m > 0) return `${m}m ${s}s`;
  return `${s}s`;
}

function updateClock() {
  const elapsed = clockLoadedAt ? Math.floor((Date.now() - clockLoadedAt) / 1000) : 0;
  const d = clockEpochBase ? new Date((clockEpochBase + elapsed) * 1000) : new Date();
  const tz = menu.value?.tzname || undefined;
  const fmt = menu.value?.date_format || 'middle_endian';

  // Map ntopng date_format pref → Intl locale that gives the right day/month/year order
  // little_endian = d/m/y  → en-GB
  // middle_endian = m/d/y  → en-US (default)
  // big_endian    = y/m/d  → sv-SE (ISO 8601 order)
  const localeMap = { little_endian: 'en-GB', middle_endian: 'en-US', big_endian: 'sv-SE' };
  const locale = localeMap[fmt] || 'en-US';

  const opts = { hour: '2-digit', minute: '2-digit', second: '2-digit',
                 year: 'numeric', month: '2-digit', day: '2-digit' };
  if (tz) opts.timeZone = tz;

  currentTime.value = d.toLocaleString(locale, opts);
  if (uptimeBase) currentUptime.value = formatUptime(uptimeBase + elapsed);
}

function copyLicenseLink() {
  const text = menu.value.license_badge?.label || (window.location.origin + pfx.value + "/lua/license.lua");
  navigator.clipboard?.writeText(text).then(() => {
    copiedLicense.value = true;
    setTimeout(() => { copiedLicense.value = false; }, 1500);
  });
}

// Blog
async function markPostRead(postId) {
  try {
    await ntopng_utility.http_request(
      `${pfx.value}/lua/rest/v2/set/ntopng/blog_post_read.lua`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          post_id: postId,
          csrf: window.__BLOG_NOTIFICATION_CSRF__ || ctx.value.csrf || "",
        }),
      }
    );
  } catch (_) {}
}

// Package update logic
let updatesLastCheck = 0;
let updatesTimer     = null;

function onUpdateStatusEvent(e) {
  const d = e.detail || {};
  updateStatus.value  = d.status  || "";
  updateVersion.value = d.version || "";
}

async function updatesRefresh() {
  const now    = Date.now() / 1000;
  const status = updateStatus.value;

  // If an update is available or upgrade failed, no need to keep polling
  if (status === "update-avail" || status === "upgrade-failure") return;

  const checkIntervalSec = (status === "installing" || status === "checking") ? 10 : 300;
  if (now < updatesLastCheck + checkIntervalSec) return;
  updatesLastCheck = now;

  try {
    const rsp = await ntopng_utility.http_request(`${pfx.value}/lua/check_update.lua`);
    if (rsp && rsp.status) {
      updateStatus.value  = rsp.status;
      updateVersion.value = rsp.version || "";
    }
  } catch (e) { console.error("[updates] GET check_update.lua error:", e); }
}

async function dismissUpdate() {
  const ver = updateVersion.value;
  if (!ver) return;
  dismissedUpdateVersion.value = ver;
  try {
    await ntopng_utility.http_request(
      `${pfx.value}/lua/rest/v2/set/ntopng/update_dismissed.lua`,
      { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          csrf:           ctx.value.csrf,
          update_version: ver,
        }) }
    );
  } catch (_) {}
}

function openUpdatePopup() {
  dismissUpdate();
  userPopupOpen.value = true;
}

async function doInstallUpdate() {
  if (!confirm(_i18n("updates.install_confirm"))) return;
  try {
    await ntopng_utility.http_request(
      `${pfx.value}/lua/install_update.lua`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({ csrf: ctx.value.csrf || window.__CSRF_DATATABLE__ }),
      }
    );
    updateStatus.value  = "installing";
    updatesLastCheck    = 0;
  } catch (_) {}
}

async function doCheckForUpdates() {
  updateStatus.value = "checking";
  updatesLastCheck   = 0;
  try {
    const postRsp = await ntopng_utility.http_request(
      `${pfx.value}/lua/check_update.lua`,
      {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          csrf: ctx.value.csrf || window.__CSRF_DATATABLE__,
          search: "true",
        }),
      }
    );

    // Immediately fetch updated status
    updatesLastCheck = 0;
    await updatesRefresh();
  } catch (_) {}
}

onMounted(async () => {
  document.addEventListener("ntopng-update-status", onUpdateStatusEvent);
  document.addEventListener("ntopng-preferences-saved", loadMenu);
  applyLayout();
  document.addEventListener("click", handleOutsideClick);
  await loadMenu();
  // Wait for v-if DOM (sparkline SVGs) to appear after menu data loads
  await nextTick();
  checkNavOverflow();
  if (railNav.value) {
    railNavObserver = new ResizeObserver(checkNavOverflow);
    railNavObserver.observe(railNav.value);
  }
  await pollIface();
  pollTimer  = setInterval(pollIface, 7000);
  updateClock();
  clockTimer = setInterval(updateClock, 1000);

  if (menu.value.has_updates_support) {
    try {
      const dismissed = await ntopng_utility.http_request(
        `${pfx.value}/lua/rest/v2/get/ntopng/update_dismissed.lua`
      );
      if (dismissed?.version) dismissedUpdateVersion.value = dismissed.version;
    } catch (_) {}
    await updatesRefresh();
    updatesTimer = setInterval(updatesRefresh, 5000);
  }
});

onBeforeUnmount(() => {
  document.removeEventListener("ntopng-update-status", onUpdateStatusEvent);
  document.removeEventListener("ntopng-preferences-saved", loadMenu);
  document.removeEventListener("click", handleOutsideClick);
  clearTimeout(railLeaveTimer);
  clearTimeout(panelLeaveTimer);
  if (pollTimer)    clearInterval(pollTimer);
  if (clockTimer)   clearInterval(clockTimer);
  if (updatesTimer) clearInterval(updatesTimer);
  railNavObserver?.disconnect();
});

watch(() => ctx.value.ifid, async (next, prev) => {
  if (next && next !== prev) {
    spark  = null;
    seeded = false;
    await loadMenu();   // keeps old menu.value until response arrives
    await nextTick();
    await pollIface();
  }
});

// Init spark as soon as the SVG ref appears in the DOM
watch(svgCombined, (el) => { if (el) tryInitSpark(); });

// Re-check nav overflow whenever sections change (menu data arrives or updates)
watch(visibleSections, () => nextTick(checkNavOverflow));

// Sync isDark from authoritative server preference once menu loads
watch(() => menu.value.theme, (theme) => {
  if (!theme) return;
  const serverDark = theme === "dark";
  if (serverDark !== isDark.value) {
    isDark.value = serverDark;
    applyTheme(serverDark);
  }
});

// Auto-expand blog section when there are unread posts
watch(() => menu.value.new_posts_counter, (n) => {
  if (n > 0) blogExpanded.value = true;
});
</script>

<style>
:root {
  --sb-rail-w:            5rem;
  --sb-rail-exp:          14.5rem;
  --sidebar-width:        5rem;
  --sb-rail-bg:           #212529;
  --sb-rail-border:       rgba(255,255,255,0.06);
  --sb-btn-hover-bg:      #2c3034;
  --sb-panel-bg:          #212529;
  --sb-panel-border:      rgba(255,255,255,0.06);
  --sb-link-color:        rgba(226,226,226,0.82);
  --sb-link-hover-bg:     #2c3034;
  --sb-link-active-color: #FF7500;
  --sb-divider:           rgba(255,255,255,0.07);
  --sb-muted:             rgba(226,226,226,0.45);
  --sb-orange:            #FF7500;
}

:root {
  --sb-navbar-h: 3rem;
}

html {
  --sidebar-width: 0px;
}

/* Reset Bootstrap .px-md-4 and set proper inner page padding */
body main#n-container,
body div#n-container,
main#n-container,
div#n-container {
  display: block !important;
  width: auto !important;
  max-width: none !important;
  padding-left: 0rem !important;
  padding-right: 0.75rem !important;
  margin-left: 0rem !important;
  margin-right: 0 !important;
  margin-top: 0 !important;
  padding-top: calc(var(--sb-navbar-h) + 0.5rem) !important;
  box-sizing: border-box !important;
}

/* Kill .body { padding-top: 4.5rem } */
.body {
  padding-top: 0 !important;
}

/* Navbar: fixed at top, right of the rail, full remaining width */
#n-navbar {
  position: fixed !important;
  top: 0 !important;
  left: var(--sb-rail-w) !important;
  width: calc(100% - var(--sb-rail-w)) !important;
  height: var(--sb-navbar-h) !important;
  z-index: 1029 !important;
  margin: 0 !important;
  padding: 0 0.75rem !important;
  box-sizing: border-box !important;
  background: var(--sb-topbar-bg, #fff) !important;
  border-bottom: 1px solid var(--sb-topbar-border, rgba(0,0,0,0.08)) !important;
  display: flex !important;
  align-items: center !important;
  justify-content: space-between !important;
  gap: 0.5rem !important;
}

:root {
  --sb-topbar-bg: #fff;
  --sb-topbar-border: rgba(0,0,0,0.08);
  --sb-topbar-fg: #333;
  --sb-iface-border: rgba(0,0,0,0.2);
  /* sidebar panel (always dark) */
  --sb-panel-bg: #fff;
  --sb-panel-border: rgba(0,0,0,0.12);
  --sb-panel-fg: #333;
  --sb-panel-item-hover: rgba(0,0,0,0.06);
  --sb-panel-label-color: rgba(0,0,0,0.45);
  /* interface dropdown — follows page theme */
  --sb-dropdown-bg:     #fff;
  --sb-dropdown-border: rgba(0,0,0,0.12);
  --sb-dropdown-fg:     #212529;
  --sb-dropdown-muted:  rgba(0,0,0,0.45);
  --sb-dropdown-hover:  rgba(0,0,0,0.05);
  --sb-dropdown-icon:   #6c757d;
  --sb-tag-sys:         #6c757d;
}
[data-bs-theme="dark"],
[data-theme="dark"],
body.dark {
  --sb-topbar-bg: #1a1d21;
  --sb-topbar-border: rgba(255,255,255,0.07);
  --sb-topbar-fg: rgba(226,226,226,0.85);
  --sb-iface-border: rgba(255,255,255,0.18);
  /* sidebar panel (always dark) */
  --sb-panel-bg: #212529;
  --sb-panel-border: rgba(255,255,255,0.10);
  --sb-panel-fg: rgba(226,226,226,0.85);
  --sb-panel-item-hover: rgba(255,255,255,0.07);
  --sb-panel-label-color: rgba(255,255,255,0.35);
  /* interface dropdown — follows page theme */
  --sb-dropdown-bg:     #1e2226;
  --sb-dropdown-border: rgba(255,255,255,0.10);
  --sb-dropdown-fg:     rgba(226,226,226,0.88);
  --sb-dropdown-muted:  rgba(255,255,255,0.35);
  --sb-dropdown-hover:  rgba(255,255,255,0.07);
  --sb-dropdown-icon:   rgba(180,200,220,0.65);
  --sb-tag-sys:         #9ca3af;
}

/*
  The expandable sb-panel always uses the same dark palette as the rail,
  regardless of the page theme. Override panel-specific tokens inline.
*/
.sb-panel {
  --sb-panel-bg:          #212529;
  --sb-panel-border:      rgba(255,255,255,0.08);
  --sb-panel-fg:          rgba(226,226,226,0.85);
  --sb-panel-item-hover:  rgba(255,255,255,0.07);
  --sb-panel-label-color: rgba(255,255,255,0.35);
  --sb-link-color:        rgba(226,226,226,0.82);
  --sb-link-hover-bg:     #2c3034;
  --sb-link-active-color: #FF7500;
  --sb-divider:           rgba(255,255,255,0.07);
  --sb-muted:             rgba(226,226,226,0.45);
}

/* Dark mode: navbar bg follows theme */
[data-bs-theme="dark"] #n-navbar,
[data-theme="dark"] #n-navbar,
body.dark #n-navbar,
.dark-mode #n-navbar {
  --sb-topbar-bg: #1a1d21;
  --sb-topbar-border: rgba(255,255,255,0.07);
  --sb-topbar-fg: rgba(226,226,226,0.85);
  background: #1a1d21 !important;
  color: rgba(226,226,226,0.85) !important;
  border-bottom-color: rgba(255,255,255,0.07) !important;
}

/* Allow horizontal scroll rather than reflowing the grid */
div.wrapper {
  overflow-x: auto;
}

/* Sidebar: always fixed to viewport, never moved by layout changes */
#n-sidebar {
  position: fixed !important;
  left: 0 !important;
  top: 0 !important;
  height: 100vh !important;
  z-index: 1041 !important;
}

@media (max-width: 575.98px) {
  #n-container .col-sm-1  { flex: 0 0 auto !important; width: 8.33333% !important; }
  #n-container .col-sm-2  { flex: 0 0 auto !important; width: 16.66667% !important; }
  #n-container .col-sm-3  { flex: 0 0 auto !important; width: 25% !important; }
  #n-container .col-sm-4  { flex: 0 0 auto !important; width: 33.33333% !important; }
  #n-container .col-sm-5  { flex: 0 0 auto !important; width: 41.66667% !important; }
  #n-container .col-sm-6  { flex: 0 0 auto !important; width: 50% !important; }
  #n-container .col-sm-8  { flex: 0 0 auto !important; width: 66.66667% !important; }
  #n-container .col-sm-12 { flex: 0 0 auto !important; width: 100% !important; }
}
@media (max-width: 767.98px) {
  #n-container .col-md-1  { flex: 0 0 auto !important; width: 8.33333% !important; }
  #n-container .col-md-2  { flex: 0 0 auto !important; width: 16.66667% !important; }
  #n-container .col-md-3  { flex: 0 0 auto !important; width: 25% !important; }
  #n-container .col-md-4  { flex: 0 0 auto !important; width: 33.33333% !important; }
  #n-container .col-md-5  { flex: 0 0 auto !important; width: 41.66667% !important; }
  #n-container .col-md-6  { flex: 0 0 auto !important; width: 50% !important; }
  #n-container .col-md-7  { flex: 0 0 auto !important; width: 58.33333% !important; }
  #n-container .col-md-8  { flex: 0 0 auto !important; width: 66.66667% !important; }
  #n-container .col-md-9  { flex: 0 0 auto !important; width: 75% !important; }
  #n-container .col-md-10 { flex: 0 0 auto !important; width: 83.33333% !important; }
  #n-container .col-md-11 { flex: 0 0 auto !important; width: 91.66667% !important; }
  #n-container .col-md-12 { flex: 0 0 auto !important; width: 100% !important; }
}
@media (max-width: 991.98px) {
  #n-container .col-lg-1  { flex: 0 0 auto !important; width: 8.33333% !important; }
  #n-container .col-lg-2  { flex: 0 0 auto !important; width: 16.66667% !important; }
  #n-container .col-lg-3  { flex: 0 0 auto !important; width: 25% !important; }
  #n-container .col-lg-4  { flex: 0 0 auto !important; width: 33.33333% !important; }
  #n-container .col-lg-6  { flex: 0 0 auto !important; width: 50% !important; }
  #n-container .col-lg-8  { flex: 0 0 auto !important; width: 66.66667% !important; }
  #n-container .col-lg-12 { flex: 0 0 auto !important; width: 100% !important; }
}
</style>

<style scoped>
.sb-rail {
  position: fixed;
  top: 0; left: 0;
  height: 100vh;
  width: var(--sb-rail-w);
  background: var(--sb-rail-bg);
  border-right: 1px solid var(--sb-rail-border);
  display: flex;
  flex-direction: column;
  z-index: 1041;
  overflow-x: hidden;
  overflow-y: hidden;
}

/* Logo */
.sb-rail__logo {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 2.75rem;
  flex-shrink: 0;
  border-bottom: 1px solid var(--sb-rail-border);
  text-decoration: none;
  overflow: hidden;
  transition: background 0.13s;
}
.sb-rail__logo:hover { background: var(--sb-btn-hover-bg); }
.sb-rail__logo-img { object-fit: contain; }

/* Scrollable nav area wrapper — holds scroll container + fade overlay */
.sb-rail__nav-wrap {
  flex: 1;
  min-height: 0;
  position: relative;   /* fade positions absolute inside this */
  display: flex;
  flex-direction: column;
}

/* Scrollable nav area */
.sb-rail__nav {
  flex: 1;
  min-height: 0;        /* flex child must have min-height:0 to shrink and scroll */
  padding: 0.25rem 0;
  overflow-y: auto;
  overflow-x: hidden;
  scrollbar-width: none;
}
.sb-rail__nav::-webkit-scrollbar { display: none; }

/* Bottom-fade — absolute over the nav wrap, covers both icon + label */
.sb-rail__nav-fade {
  position: absolute;
  bottom: 0;
  left: 0; right: 0;
  height: 2.5rem;
  background: linear-gradient(to bottom, transparent, var(--sb-rail-bg, #212529));
  pointer-events: none;
}

/* Scroll indicator arrows — appear/disappear based on scroll position */
.sb-rail__scroll-hint {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  height: 1.25rem;
  color: #fff;
  font-size: 0.55rem;
  pointer-events: none;
}

/* ── Button: fixed height, column layout — icon + label always in flow */
.sb-rail__btn {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 0.2rem;
  width: 100%;
  height: 3.25rem;        /* fixed — never changes */
  padding: 0.3rem 0;
  border: none;
  background: transparent;
  color: rgba(255,255,255,0.38);
  cursor: pointer;
  transition: background 0.15s, color 0.13s;
  overflow: visible;
  white-space: nowrap;
}
.sb-rail__btn:hover { background: var(--sb-btn-hover-bg); color: rgba(255,255,255,0.9); }

/* Orange pill */
.sb-rail__pill {
  position: absolute;
  left: 0; top: 20%; bottom: 20%;
  width: 3px;
  border-radius: 0 3px 3px 0;
  background: var(--sb-orange);
  opacity: 0;
  transform: scaleY(0.3);
  transition: opacity 0.14s, transform 0.14s;
  flex-shrink: 0;
}
.sb-rail__btn--current .sb-rail__pill,
.sb-rail__btn--open    .sb-rail__pill { opacity: 1; transform: scaleY(1); }

/* State colors */
.sb-rail__btn--current  { color: var(--sb-orange); }
.sb-rail__btn--open     { background: rgba(255,117,0,0.09); color: var(--sb-orange); }
.sb-rail__btn--open:hover { background: rgba(255,117,0,0.14); }
.sb-rail__btn--hovering { background: var(--sb-btn-hover-bg); color: rgba(255,255,255,0.85); }

/* Icon: static, no transform */
.sb-rail__icon {
  font-size: 1rem;
  line-height: 1;
  flex-shrink: 0;
  text-align: center;
  transition: color 0.13s;
}

/* Active/open overrides keep the orange accent */
.sb-rail__btn--current .sb-rail__icon,
.sb-rail__btn--open    .sb-rail__icon { color: var(--sb-orange); }

/* Avatar cell: static */
.sb-rail__avatar-cell {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}
.sb-avatar-dot {
  position: absolute;
  top: -0.1rem; right: -0.1rem;
  width: 0.55rem; height: 0.55rem;
  border-radius: 50%;
  background: #dc3545;
  pointer-events: none;
}
.sb-avatar-dot--update {
  width: 0.65rem; height: 0.65rem;
  top: -0.15rem; right: -0.15rem;
}

/*
  Label: always in flow (takes space), so button height never shifts.
  Inherits color from .sb-rail__btn so hover/active states propagate automatically.
*/
.sb-rail__label {
  font-size: 0.6rem;
  font-weight: 500;
  letter-spacing: 0.01em;
  white-space: nowrap;
  overflow: visible;
  padding: 0 0.2rem;
  text-align: center;
  color: transparent;
  transition: color 0.16s ease;
  pointer-events: none;
  line-height: 1;
  flex-shrink: 0;
}

.sb-rail--expanded .sb-rail__label { color: inherit; }

/* Bottom strip */
.sb-rail__bottom {
  flex-shrink: 0;
  border-top: 1px solid var(--sb-rail-border);
  padding: 0.25rem 0;
}

.sb-topbar__left {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  min-width: 0;
  position: relative;   /* anchor for ::after fade overlay */
  overflow: visible;    /* parent does NOT scroll — only .network-load does */
}

/* Fade hint at right edge of badge scroll area — kept narrow so it doesn't hide badges */
.sb-topbar__left::after {
  content: '';
  position: absolute;
  right: 0; top: 0; height: 100%;
  width: 1rem;
  background: linear-gradient(to right, transparent, var(--sb-topbar-bg, #fff));
  pointer-events: none;
  z-index: 3;
}

.sb-topbar__right {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  flex-shrink: 0;
  position: relative;
  z-index: 4;  /* sits above the fade overlay */
}

.sb-topbar__icon-btn {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border: none;
  border-radius: 6px;
  background: transparent;
  color: var(--sb-topbar-fg, #333);
  cursor: pointer;
  font-size: 0.85rem;
  transition: background 0.12s, color 0.12s;
}
.sb-topbar__icon-btn:hover,
.sb-topbar__icon-btn.open { background: rgba(0,0,0,0.07); }
.sb-topbar__badge {
  position: absolute;
  top: 0.1rem; right: 0.1rem;
  min-width: 0.95rem; height: 0.95rem;
  border-radius: 999px;
  background: #dc3545;
  color: #fff;
  font-size: 0.5rem;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 0.15rem;
  pointer-events: none;
}
.sb-topbar__btn-wrap { position: relative; }

.sb-iface-selector { position: relative; }
.sb-iface-btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  height: 2rem;
  padding: 0 0.6rem;
  border: 1px solid var(--sb-iface-border, rgba(0,0,0,0.2));
  border-radius: 6px;
  background: transparent;
  color: var(--sb-topbar-fg, #333);
  font-size: 0.8rem;
  font-weight: 500;
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s;
  max-width: 14rem;
  white-space: nowrap;
  overflow: hidden;
}
.sb-iface-btn:hover,
.sb-iface-btn.open { background: rgba(0,0,0,0.07); }
.sb-iface-btn__icon { font-size: 0.75rem; opacity: 0.7; flex-shrink: 0; }
.sb-iface-btn__name { flex: 1; overflow: hidden; text-overflow: ellipsis; }
.sb-iface-btn__warn { color: #f6c23e; font-size: 0.7rem; flex-shrink: 0; }
.sb-iface-btn__zmq {
  flex-shrink: 0;
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0.03em;
  padding: 0.05rem 0.3rem;
  border-radius: 3px;
  background: rgba(255,163,0,0.15);
  color: #ffa300;
  border: 1px solid rgba(255,163,0,0.35);
  line-height: 1.4;
}
.sb-iface-btn__caret {
  font-size: 0.55rem; opacity: 0.5; flex-shrink: 0; transition: transform 0.15s;
}
.sb-iface-btn__caret.rotated { transform: rotate(180deg); }

.sb-iface-menu {
  position: fixed;
  min-width: 16rem; max-width: 22rem; max-height: 70vh;
  overflow-y: auto;
  background: var(--sb-dropdown-bg);
  border: 1px solid var(--sb-dropdown-border);
  border-radius: 8px;
  box-shadow: 0 8px 32px rgba(0,0,0,0.18);
  z-index: 1055;
  padding: 0.4rem 0;
  scrollbar-width: thin;
  color: var(--sb-dropdown-fg);
}
.sb-iface-menu__section { padding: 0; }
.sb-iface-menu__label {
  font-size: 0.6rem; font-weight: 700; letter-spacing: 0.1em;
  text-transform: uppercase; color: var(--sb-dropdown-muted);
  padding: 0.5rem 0.85rem 0.2rem;
}
.sb-iface-menu__divider { height: 1px; background: var(--sb-dropdown-border); margin: 0.25rem 0; }
.sb-iface-item {
  display: flex; align-items: center; gap: 0.6rem;
  padding: 0.45rem 0.85rem;
  text-decoration: none; color: var(--sb-dropdown-fg); font-size: 0.8rem;
  transition: background 0.1s, color 0.1s; cursor: pointer;
}
.sb-iface-item:hover { background: var(--sb-dropdown-hover); text-decoration: none; }
.sb-iface-item--active { color: #FF7500; background: rgba(255,117,0,0.08); }
.sb-iface-item--active:hover { background: rgba(255,117,0,0.13); }
.sb-iface-item--system { opacity: 0.9; }
.sb-iface-menu .text-muted,
.sb-iface-menu .text-secondary { color: var(--sb-dropdown-icon) !important; }

.sb-iface-item__icon { width: 1rem; text-align: center; flex-shrink: 0; font-size: 0.75rem; color: var(--sb-dropdown-icon); }
.sb-iface-item__info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 0.1rem; }
.sb-iface-item__name { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sb-iface-item__check { font-size: 0.65rem; color: #FF7500; flex-shrink: 0; }

.sb-iface-tree-branch {
  display: inline-flex; align-items: center;
  width: 1.6rem; flex-shrink: 0; position: relative; align-self: stretch;
}
.sb-iface-tree-branch::before {
  content: ""; position: absolute; left: 0.5rem; top: 50%;
  width: 0.8rem; height: 2px; background: var(--sb-dropdown-icon);
}
.sb-iface-tree-branch::after {
  content: ""; position: absolute; left: 0.5rem; top: 0;
  width: 2px; height: calc(50% + 1px); background: var(--sb-dropdown-icon);
}
.sb-iface-tree-branch--spacer::before,
.sb-iface-tree-branch--spacer::after { display: none; }
.sb-iface-item__tags { display: flex; gap: 0.2rem; flex-wrap: wrap; }
.sb-iface-tag {
  font-size: 0.5rem; font-weight: 600; letter-spacing: 0.05em;
  text-transform: uppercase; padding: 0.05rem 0.3rem; border-radius: 3px;
}
.sb-iface-tag--sys  { background: rgba(108,117,125,0.15); color: var(--sb-tag-sys); }
.sb-iface-tag--view { background: rgba(13,202,240,0.12);  color: #0a9dba; }
.sb-iface-tag--rec  { background: rgba(220,53,69,0.15);   color: #dc3545; }
.sb-iface-tag--pcap { background: rgba(108,117,125,0.15); color: var(--sb-tag-sys); }
.sb-iface-tag--zmq  { background: rgba(255,163,0,0.12);   color: #e08000; }
.sb-iface-tag--drop { background: rgba(220,53,69,0.15);   color: #dc3545; }

.sb-popup-blog-header {
  padding: 0.45rem 1rem 0.2rem;
  font-size: 0.68rem; color: var(--sb-muted);
  display: flex; align-items: center; gap: 0.3rem;
}
.sb-popup-blog-header b { color: var(--sb-link-color); }
.sb-popup-blog-item {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.4rem 1rem; font-size: 0.75rem;
  color: var(--sb-link-color); text-decoration: none; transition: background 0.1s;
}
.sb-popup-blog-item:hover { background: var(--sb-link-hover-bg); color: #fff; text-decoration: none; }
.sb-popup-blog-item__body { flex: 1; min-width: 0; }
.sb-popup-blog-item__desc { font-size: 0.67rem; color: var(--sb-muted); margin-top: 0.1rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sb-popup-blog-empty { padding: 0.4rem 1rem 0.6rem; font-size: 0.75rem; color: var(--sb-muted); font-style: italic; }
.sb-blog-menu {
  position: fixed; min-width: 17rem; max-width: 22rem;
  background: #212529; border: 1px solid rgba(255,255,255,0.1);
  border-radius: 8px; box-shadow: 0 8px 32px rgba(0,0,0,0.35);
  z-index: 1055; overflow: hidden;
}
.sb-blog-item {
  display: flex; align-items: flex-start; gap: 0.5rem;
  padding: 0.5rem 0.85rem; font-size: 0.78rem;
  color: rgba(226,226,226,0.8); text-decoration: none; transition: background 0.1s;
}
.sb-blog-item:hover { background: rgba(255,255,255,0.07); color: #fff; text-decoration: none; }
.sb-blog-empty { padding: 0.6rem 0.85rem; font-size: 0.78rem; color: rgba(226,226,226,0.45); }
.sb-blog-item__left { flex-shrink: 0; padding-top: 0.2rem; }
.sb-blog-item__body { flex: 1; min-width: 0; }
.sb-blog-item__desc { font-size: 0.7rem; color: rgba(226,226,226,0.5); margin-top: 0.15rem; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.sb-blog-item__ext { font-size: 0.55rem; flex-shrink: 0; opacity: 0.4; margin-top: 0.2rem; }

.sb-about-block { padding: 0.85rem 1rem 0.7rem; user-select: text; }
.sb-about-block__product {
  font-size: 0.85rem; font-weight: 700; color: var(--sb-panel-fg, #fff); margin-bottom: 0.3rem;
}
.sb-about-block__version {
  font-size: 0.72rem; color: var(--sb-panel-fg, #fff); margin-bottom: 0.3rem; word-break: break-all;
}
.sb-about-block__version a { color: var(--sb-panel-fg, #fff); }
.sb-about-block__version a:hover { color: var(--sb-orange); }
.sb-about-block__divider {
  height: 1px; background: var(--sb-panel-border, rgba(255,255,255,0.07)); margin: 0.45rem 0;
}
.sb-about-block__line {
  display: flex; align-items: center; gap: 0.4rem;
  font-size: 0.7rem; color: var(--sb-panel-fg, #fff); margin-bottom: 0.2rem;
}
.sb-about-block__line i { font-size: 0.6rem; opacity: 0.75; flex-shrink: 0; width: 0.7rem; text-align: center; }
.sb-about-block__line a { color: var(--sb-link-color); text-decoration: none; }
.sb-about-block__line a:hover { color: var(--sb-orange); text-decoration: underline; }
.sb-about-copy-btn {
  margin-left: auto; display: inline-flex; align-items: center; justify-content: center;
  width: 1.3rem; height: 1.3rem; border: none; border-radius: 3px;
  background: rgba(255,255,255,0.08); color: rgba(226,226,226,0.6);
  cursor: pointer; font-size: 0.6rem; flex-shrink: 0; transition: background 0.1s, color 0.1s;
}
.sb-about-copy-btn:hover { background: rgba(255,255,255,0.16); color: #fff; }
.sb-about-block__copy {
  font-size: 0.6rem; color: var(--sb-muted); margin-top: 0.45rem;
  border-top: 1px solid var(--sb-panel-border, rgba(255,255,255,0.06)); padding-top: 0.35rem;
}

.sb-drop-anim-enter-active { transition: opacity 0.13s ease, transform 0.13s cubic-bezier(.4,0,.2,1); }
.sb-drop-anim-leave-active { transition: opacity 0.09s ease, transform 0.09s ease; }
.sb-drop-anim-enter-from   { opacity: 0; transform: translateY(-4px); }
.sb-drop-anim-leave-to     { opacity: 0; transform: translateY(-2px); }

.sb-panel {
  --sb-panel-bg:          #212529;
  --sb-panel-border:      rgba(255,255,255,0.08);
  --sb-panel-fg:          rgba(226,226,226,0.85);
  --sb-panel-item-hover:  rgba(255,255,255,0.07);
  --sb-panel-label-color: rgba(255,255,255,0.35);
  --sb-link-color:        rgba(226,226,226,0.82);
  --sb-link-hover-bg:     #2c3034;
  --sb-link-active-color: #FF7500;
  --sb-divider:           rgba(255,255,255,0.07);
  --sb-muted:             rgba(226,226,226,0.45);
  position: fixed; left: var(--sb-rail-w); top: 0; height: 100vh;
  width: max-content; min-width: 9rem;
  max-width: min(16rem, calc(100vw - var(--sb-rail-w)));
  background: var(--sb-panel-bg); border-right: 1px solid var(--sb-panel-border);
  display: flex; flex-direction: column;
  z-index: 1050; box-shadow: 2px 0 14px rgba(0,0,0,0.45); overflow: hidden;
}
.sb-panel__header {
  flex-shrink: 0; height: 2.75rem; display: flex; align-items: center;
  justify-content: space-between; padding: 0 0.625rem;
  border-bottom: 1px solid var(--sb-divider); gap: 0.5rem;
}
.sb-panel__toggle {
  width: 1.5rem; height: 1.5rem; flex-shrink: 0;
  display: inline-flex; align-items: center; justify-content: center;
  border: none; border-radius: 4px; background: transparent;
  color: var(--sb-muted); cursor: pointer; transition: background 0.12s, color 0.12s;
}
.sb-panel__toggle:hover { background: var(--sb-link-hover-bg); color: #fff; }
.sb-panel__nav {
  flex: 1; overflow-y: auto; overflow-x: hidden;
  padding: 0.35rem 0 1rem; scrollbar-width: thin;
  scrollbar-color: rgba(255,255,255,0.1) transparent;
}
.sb-panel__nav::-webkit-scrollbar { width: 3px; }
.sb-panel__nav::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 3px; }
.sb-nav-link {
  position: relative; display: flex; align-items: center; gap: 0.375rem;
  padding: 0.44rem 1rem 0.44rem 1.25rem;
  font-size: 0.78rem; font-weight: 400; color: var(--sb-link-color);
  text-decoration: none; white-space: nowrap; width: 100%;
  transition: background 0.11s, color 0.11s; list-style: none;
}
.sb-nav-link::before {
  content: ""; position: absolute; left: 0; top: 20%; bottom: 20%;
  width: 3px; border-radius: 0 3px 3px 0; background: var(--sb-orange);
  opacity: 0; transform: scaleY(0.3); transition: opacity 0.13s, transform 0.13s;
}
.sb-nav-link:hover { background: var(--sb-link-hover-bg); color: #fff; text-decoration: none; }
.sb-nav-link:hover::before { opacity: 0.35; transform: scaleY(1); }
.sb-nav-link--active {
  color: var(--sb-link-active-color); font-weight: 500; background: rgba(255,117,0,0.09);
}
.sb-nav-link--active::before { opacity: 1; transform: scaleY(1); }
.sb-nav-link--active:hover { background: rgba(255,117,0,0.13); color: var(--sb-link-active-color); }
.sb-panel-divider { height: 1px; background: var(--sb-divider); margin: 0.35rem 1rem 0; }
.sb-panel-group-label {
  font-size: 0.6rem; font-weight: 700; letter-spacing: 0.1em;
  text-transform: uppercase; color: var(--sb-muted);
  padding: 0.4rem 1.25rem 0.15rem;
}
.sb-nav-link__icon {
  width: 1rem; text-align: center; flex-shrink: 0;
  font-size: 0.72rem; opacity: 0.75;
}

.sb-panel-anim-enter-active { transition: opacity 0.15s ease, transform 0.15s cubic-bezier(.4,0,.2,1); }
.sb-panel-anim-leave-active { transition: opacity 0.1s ease, transform 0.1s ease; }
.sb-panel-anim-enter-from   { opacity: 0; transform: translateX(-6px); }
.sb-panel-anim-leave-to     { opacity: 0; transform: translateX(-4px); }

.sb-user-popup {
  --sb-panel-bg:      #212529;
  --sb-panel-border:  rgba(255,255,255,0.1);
  --sb-link-color:    rgba(226,226,226,0.85);
  --sb-link-hover-bg: #2c3034;
  --sb-divider:       rgba(255,255,255,0.07);
  --sb-muted:         rgba(226,226,226,0.45);
  position: fixed; left: 0; min-width: 15rem; width: 16rem;
  background: var(--sb-panel-bg);
  border: 1px solid var(--sb-panel-border); border-left: 3px solid var(--sb-orange);
  border-radius: 0 0.5rem 0.5rem 0.5rem;
  box-shadow: 4px -4px 24px rgba(0,0,0,0.55); z-index: 1060; overflow: hidden;
}
.sb-user-card {
  display: flex; align-items: center; gap: 0.75rem; padding: 1rem;
  background: linear-gradient(135deg, #2a2e35 0%, #1c1f25 100%);
  border-bottom: 2px solid var(--sb-orange);
}
.sb-user-card__info { flex: 1; min-width: 0; }
.sb-user-card__name {
  font-size: 0.85rem; font-weight: 600; color: #fff;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.sb-user-card__role {
  font-size: 0.67rem; color: var(--sb-muted); margin-top: 2px;
  text-transform: uppercase; letter-spacing: 0.06em;
}
.sb-popup-divider { height: 1px; background: var(--sb-divider); }
.sb-popup-item {
  display: flex; align-items: center; gap: 0.6rem; padding: 0.55rem 1rem;
  font-size: 0.8rem; color: var(--sb-link-color); text-decoration: none;
  background: transparent; border: none; width: 100%; text-align: left;
  cursor: pointer; transition: color 0.11s, background 0.11s;
}
.sb-popup-item:hover { color: #fff; background: var(--sb-link-hover-bg); text-decoration: none; }
.sb-popup-item--text { cursor: default; }
.sb-popup-item--text:hover { background: transparent; color: var(--sb-link-color); }
.sb-popup-item--danger:hover { color: #ff6b6b; background: rgba(255,107,107,0.1); }
.sb-popup-icon { width: 1rem; text-align: center; flex-shrink: 0; opacity: 0.6; }
.sb-toggle-switch {
  margin-left: auto; width: 2rem; height: 1rem; border-radius: 1rem;
  background: rgba(255,255,255,0.15); position: relative; flex-shrink: 0;
  transition: background 0.2s;
}
.sb-toggle-switch.on { background: #28a745; }
.sb-toggle-thumb {
  position: absolute; top: 0.125rem; left: 0.125rem;
  width: 0.75rem; height: 0.75rem; border-radius: 50%;
  background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,.3);
  transition: transform 0.2s cubic-bezier(.4,0,.2,1);
}
.sb-toggle-switch.on .sb-toggle-thumb { transform: translateX(1rem); }

.sb-popup-anim-enter-active { transition: opacity 0.14s ease, transform 0.14s cubic-bezier(.4,0,.2,1); }
.sb-popup-anim-leave-active { transition: opacity 0.09s ease, transform 0.09s ease; }
.sb-popup-anim-enter-from   { opacity: 0; transform: translateY(6px); }
.sb-popup-anim-leave-to     { opacity: 0; transform: translateY(4px); }

.sb-avatar {
  width: 1.75rem; height: 1.75rem; aspect-ratio: 1; border-radius: 50%;
  background: var(--sb-orange); color: #1a1a1a;
  display: flex; align-items: center; justify-content: center;
  font-size: 0.6rem; font-weight: 700; flex-shrink: 0; line-height: 1;
}
.sb-avatar--lg {
  width: 2.5rem; height: 2.5rem; aspect-ratio: 1;
  font-size: 0.82rem; border: 2px solid rgba(255,117,0,0.3);
}
.sb-ext-icon { font-size: 0.55rem; margin-left: auto; }
.iface-type-icon { width: 1rem; text-align: center; flex-shrink: 0; }

.sb-sparklines { display: flex; align-items: center; }
.sb-spark-combined { display: flex; align-items: center; gap: 0.4rem; }
.sb-spark { display: block; width: 100px; height: 30px; }
.sb-spark-labels { display: flex; flex-direction: column; gap: 0; }
.sb-spark-val {
  display: flex; align-items: center; gap: 0.25rem;
  font-size: 0.72rem; white-space: nowrap; color: var(--sb-topbar-fg, #333);
}
.sb-spark-arrow { font-size: 0.65rem; }

.sb-license-badge { text-decoration: none; }

/* Network-load badge strip: fills remaining topbar, single scrollable row */
:deep(.network-load) {
  display: flex;
  align-items: center;
  overflow-x: auto;
  scrollbar-width: none;   /* Firefox */
  flex: 1 1 0;             /* grow to fill remaining .sb-topbar__left width */
  min-width: 3rem;         /* never collapse fully */
}
:deep(.network-load)::-webkit-scrollbar { display: none; }
:deep(.navbar-main-badges) {
  display: flex;
  flex-wrap: nowrap;
  gap: 0.25rem;
  align-items: center;
  white-space: nowrap;
  padding-right: 0.5rem;
}

/* ── Update banner ── */
.sb-update-banner {
  position: fixed;
  top: var(--sb-navbar-h);
  left: var(--sb-rail-w);
  width: calc(100% - var(--sb-rail-w));
  z-index: 1028;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.45rem 1rem;
  background: #198754;
  color: #fff;
  font-size: 0.82rem;
  box-shadow: 0 2px 8px rgba(0,0,0,0.2);
}
.sb-update-banner__icon { font-size: 1rem; flex-shrink: 0; }
.sb-update-banner__text { flex: 1; }
.sb-update-banner__action {
  flex-shrink: 0;
  padding: 0.25rem 0.75rem;
  border: 1px solid rgba(255,255,255,0.6);
  border-radius: 4px;
  background: rgba(255,255,255,0.15);
  color: #fff;
  font-size: 0.78rem;
  font-weight: 600;
  cursor: pointer;
  transition: background 0.15s;
}
.sb-update-banner__action:hover { background: rgba(255,255,255,0.28); }
.sb-update-banner__close {
  flex-shrink: 0;
  width: 1.5rem; height: 1.5rem;
  display: flex; align-items: center; justify-content: center;
  border: none; border-radius: 4px;
  background: rgba(255,255,255,0.12);
  color: rgba(255,255,255,0.8);
  cursor: pointer; font-size: 0.75rem;
  transition: background 0.12s;
}
.sb-update-banner__close:hover { background: rgba(255,255,255,0.25); color: #fff; }

.sb-banner-anim-enter-active { transition: opacity 0.2s, transform 0.2s; }
.sb-banner-anim-leave-active { transition: opacity 0.15s, transform 0.15s; }
.sb-banner-anim-enter-from,
.sb-banner-anim-leave-to    { opacity: 0; transform: translateY(-100%); }

/* ── Footer ── */
#n-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-top: 0.75rem;
  padding: 0.35rem 0;
  border-top: 1px solid var(--bs-border-color, rgba(0,0,0,0.15));
  font-size: 0.7rem;
  color: var(--bs-body-color, #333);
}
#n-footer a {
  color: inherit;
  text-decoration: none;
}
#n-footer a:hover { color: var(--sb-orange, #FF7500); text-decoration: underline; }
.sb-footer__col { flex: 1; display: flex; align-items: center; gap: 0.35rem; }
.sb-footer__col--center { justify-content: center; }
.sb-footer__col--right  { justify-content: flex-end; }
.sb-footer__sep { opacity: 0.35; }
</style>

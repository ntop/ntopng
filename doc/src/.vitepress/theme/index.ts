import DefaultTheme from 'vitepress/theme'
import { h, onMounted, watch, nextTick } from 'vue'
import { useRoute } from 'vitepress'
import mediumZoom from 'medium-zoom'
import './style.css'

const SHOP_URL = 'https://shop.ntop.org/'
const SHOP_LABEL = 'Get a License'
const CART_ICON = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="9" cy="21" r="1"/><circle cx="20" cy="21" r="1"/><path d="M1 1h4l2.7 13.4a2 2 0 0 0 2 1.6h9.7a2 2 0 0 0 2-1.6L23 6H6"/></svg>'

export default {
  extends: DefaultTheme,
  // always visible in the navbar, also on phones (the other links collapse in the menu)
  Layout: () => h(DefaultTheme.Layout, null, {
    'nav-bar-content-after': () => h('a', { class: 'shop-cta', href: SHOP_URL, target: '_blank', rel: 'noopener', title: SHOP_LABEL, 'aria-label': SHOP_LABEL }, [
      h('span', { class: 'shop-cta-icon', innerHTML: CART_ICON }),
      h('span', { class: 'shop-cta-text' }, SHOP_LABEL),
    ]),
  }),
  setup() {
    const route = useRoute()
    const init = () => mediumZoom('.vp-doc figure img, .vp-doc p > img', { background: 'rgba(0,0,0,.85)' })
    onMounted(init)
    watch(() => route.path, () => nextTick(init))
  },
}

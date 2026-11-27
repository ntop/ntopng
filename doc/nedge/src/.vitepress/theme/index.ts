import DefaultTheme from 'vitepress/theme'
import { onMounted, watch, nextTick } from 'vue'
import { useRoute } from 'vitepress'
import mediumZoom from 'medium-zoom'
import './style.css'

export default {
  extends: DefaultTheme,
  setup() {
    const route = useRoute()
    const init = () => mediumZoom('.vp-doc figure img, .vp-doc p > img', { background: 'rgba(0,0,0,.85)' })
    onMounted(init)
    watch(() => route.path, () => nextTick(init))
  },
}

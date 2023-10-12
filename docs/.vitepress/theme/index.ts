// https://vitepress.dev/guide/custom-theme
import { h } from 'vue'
import Theme from 'vitepress/theme-without-fonts'
import './style.css'

export default {
  extends: Theme,
  Layout: () => {
    return h(Theme.Layout, null, {
      // https://vitepress.dev/guide/extending-default-theme#layout-slots
    })
  },
  enhanceApp({ app, router, siteData }) {
    app.config.globalProperties.$formatDate = (date: string) => {
      return new Intl.DateTimeFormat('en-US', { dateStyle: 'full' }).format(new Date(date))
    }
  }
}

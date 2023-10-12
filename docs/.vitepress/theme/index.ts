// https://vitepress.dev/guide/custom-theme
import { h } from 'vue'
import Theme from 'vitepress/theme-without-fonts'
import './style.css'
import { DateTime } from 'luxon'

export default {
  extends: Theme,
  Layout: () => {
    return h(Theme.Layout, null, {
      // https://vitepress.dev/guide/extending-default-theme#layout-slots
    })
  },
  enhanceApp({ app, router, siteData }) {
    app.config.globalProperties.$formatDate = (date: string) => {
      return DateTime.fromISO(date)
        .toLocaleString(DateTime.DATE_HUGE, { locale: 'en-US' })
    }
  }
}

<template>
  <div
    class="section"
  >
    <h2 class="title">
      {{ hoverTitle }}

      <small class="result">
        {{ hoverLabel }}
      </small>
    </h2>

    <div class="container">
      <canvas
        class="chart"
        ref="chart"
        @mouseleave="hoverIndex = null"
      ></canvas>
    </div>
  </div>
</template>

<script lang="ts">
import { computed, defineComponent } from 'vue'
import Chart from 'chart.js/auto'

type DownloadsItem = { week: string, count: number }

export default defineComponent({
  data() {
    return {
      downloads: [] as DownloadsItem[],
      hoverIndex: null as number | null,
      defaultLabel: 'loading...'
    }
  },

  computed: {
    labels(): string[] {
      return this.downloads.map(({ week }) => week)
    },

    series(): number[] {
      return this.downloads.map(({ count }) => count)
    },

    hoverDownload(): DownloadsItem | undefined {
      return this.downloads[this.hoverIndex]
    },

    hoverLabel(): string {
      if (this.hoverDownload === undefined) {
        return this.defaultLabel
      }

      return this.formatNumber(this.hoverDownload.count)
    },

    hoverTitle(): string {
      if (this.hoverDownload === undefined) {
        return 'Weekly downloads:'
      }

      const start = new Date(this.hoverDownload.week + 'Z')
      const end = new Date(start)

      end.setDate(start.getDate() + 6)

      return this.formatDate(start) + ' to ' + this.formatDate(end) + ':'
    }
  },

  methods: {
    formatDate(date: Date): string {
      return date.toISOString().slice(0, 10)
    },

    formatNumber(number: number): string {
      return number.toLocaleString('es-ES', {
        maximumFractionDigits: 0,
        useGrouping: true,
      })
    }
  },

  async mounted() {
    const response = await fetch('https://bashunit.typeddevs.com/downloads')

    this.downloads = (await response.json()).reverse()

    let dataCount = 0
    let totalCount = 0

    this.downloads.forEach(({ count }) => {
      dataCount++
      totalCount += count
    })

    if (totalCount !== 0) {
      this.defaultLabel = this.formatNumber(totalCount / dataCount)
    }

    const chart = new Chart(this.$refs.chart as HTMLCanvasElement, {
      type: 'line',
      data: {
        labels: this.labels,
        datasets: [{
          label: 'Downloads',
          data: this.series,
          borderColor: '#6cbe1d',
          borderWidth: 3,
          pointRadius: 0,
          pointHoverRadius: 0,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          tooltip: { enabled: false },
          legend: { display: false },
        },
        scales: {
          x: { display: false },
          y: { display: false },
        },
        interaction: {
          mode: 'index',
          intersect: false,
        },
        onHover: (_event, elements) => {
          if (elements.length > 0) {
            this.hoverIndex = elements[0].index
          } else {
            this.hoverIndex = null
          }
        }
      }
    });
  }
})
</script>

<style scoped lang="css">
.title {
  border: none;
  padding: 0;
  font-variant-numeric: tabular-nums;
}

.result {
  display: block;
  font-family: var(--vp-font-family-base);
  font-weight: normal;
  font-size: 32px;
  font-variant-numeric: tabular-nums;
  padding-top: 6px;
}

.container {
  height: 200px;
}

.chart {
  background-color: var(--vp-c-bg-elv);
  border-radius: 12px;
  padding: 24px;
  width: 100%;
  height: 200px;
}
</style>

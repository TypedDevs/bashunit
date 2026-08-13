#!/usr/bin/env bash

# HTML coverage report: the index page.

function bashunit::coverage::generate_index_html() {
  # Set normal IFS for array operations throughout the function (Bash 3.0/4.3 compatible)
  local IFS=$' \t\n'
  local output_file="$1"
  local total_hit="$2"
  local total_executable="$3"
  local total_pct="$4"
  local tests_total="$5"
  local tests_passed="$6"
  local tests_failed="$7"
  shift 7
  # Handle array passed as arguments - Bash 3.0 compatible
  local -a file_data=()
  local file_count=0
  if [ $# -gt 0 ]; then
    file_data=("$@")
    file_count=$#
  fi

  # Calculate uncovered lines and file count
  local total_uncovered=$((total_executable - total_hit))

  # Calculate gauge stroke offset (440 is full circle circumference)
  local gauge_offset=$((440 - (440 * total_pct / 100)))

  # Determine coverage level and colors for gauge
  local total_class gauge_color_start gauge_color_end gauge_text_gradient
  bashunit::coverage::class_to_slot "$total_pct"
  total_class="$_BASHUNIT_COVERAGE_CLASS_OUT"
  case "$total_class" in
  high)
    gauge_color_start="#10b981"
    gauge_color_end="#34d399"
    gauge_text_gradient="linear-gradient(135deg, #10b981 0%, #34d399 100%)"
    ;;
  medium)
    gauge_color_start="#f59e0b"
    gauge_color_end="#fbbf24"
    gauge_text_gradient="linear-gradient(135deg, #f59e0b 0%, #fbbf24 100%)"
    ;;
  low)
    gauge_color_start="#ef4444"
    gauge_color_end="#f87171"
    gauge_text_gradient="linear-gradient(135deg, #ef4444 0%, #f87171 100%)"
    ;;
  esac

  {
    cat <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Coverage Report | bashunit</title>
  <style>
    :root {
      --primary: #6366f1; --primary-dark: #4f46e5; --primary-light: #818cf8;
      --success: #10b981; --success-light: #34d399;
      --warning: #f59e0b; --warning-light: #fbbf24;
      --danger: #ef4444; --danger-light: #f87171;
      --bg-light: #ffffff; --bg-card: #f8fafc; --bg-hover: #f1f5f9;
      --text-primary: #0f172a; --text-secondary: #475569; --text-muted: #94a3b8;
      --border: #e2e8f0;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background: var(--bg-light); color: var(--text-primary); min-height: 100vh; line-height: 1.6; }
    .header { background: var(--bg-card); padding: 0; position: relative; overflow: hidden; border-bottom: 1px solid var(--border); }
    .header-content { position: relative; z-index: 1; max-width: 1400px; margin: 0 auto; padding: 40px 30px; }
    .header-top { display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; }
    .logo { display: flex; align-items: center; gap: 12px; }
    .logo img { width: 40px; height: 40px; }
    .logo-text { font-size: 1.5rem; font-weight: 700; letter-spacing: -0.5px; color: var(--text-primary); }
    .logo-text span { opacity: 0.6; font-weight: 400; }
    .header-badge { background: var(--bg-hover); padding: 8px 16px; border-radius: 20px; font-size: 0.85rem; font-weight: 500; color: var(--text-secondary); }
    .header-title { font-size: 2.5rem; font-weight: 800; margin-bottom: 8px; letter-spacing: -1px; color: var(--text-primary); }
    .header-subtitle { font-size: 1.1rem; opacity: 0.7; color: var(--text-secondary); }
    .main { max-width: 1400px; margin: 0 auto; padding: 40px 30px; }
    .gauge-section { background: var(--bg-card); border-radius: 20px; padding: 40px; margin-bottom: 30px; border: 1px solid var(--border); display: flex; align-items: center; gap: 60px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .gauge-container { position: relative; width: 200px; height: 200px; flex-shrink: 0; }
    .gauge-bg { fill: none; stroke: #e5e7eb; stroke-width: 20; }
    .gauge-fill { fill: none; stroke: url(#gaugeGradient); stroke-width: 20; stroke-linecap: round; transform: rotate(-90deg); transform-origin: center; animation: gaugeAnimation 1.5s ease-out forwards; }
    @keyframes gaugeAnimation { from { stroke-dashoffset: 440; } }
    @keyframes fadeInUp { from { opacity: 0; } to { opacity: 1 } }
    .gauge-text { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; width: 100%; }
EOF
    echo "    .gauge-percent { font-size: 3.5rem; font-weight: 800; background: ${gauge_text_gradient}; -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; line-height: 1; margin: 0; display: block; }"
    cat <<'EOF'
    .gauge-label { color: var(--text-secondary); font-size: 0.9rem; text-transform: uppercase; letter-spacing: 2px; margin: 0; display: block; }
    .gauge-info { flex: 1; }
    .gauge-title { font-size: 1.8rem; font-weight: 700; margin-bottom: 12px; }
    .gauge-description { color: var(--text-secondary); font-size: 1.05rem; margin-bottom: 24px; line-height: 1.7; }
    .breakdown-item { display: flex; align-items: center; gap: 6px; white-space: nowrap; }
    .breakdown-dot { width: 12px; height: 12px; border-radius: 50%; }
    .breakdown-dot.total { background: #94a3b8; }
    .breakdown-dot.covered { background: var(--success); }
    .breakdown-dot.uncovered { background: var(--danger); }
    .breakdown-dot.files { background: var(--warning); }
    .breakdown-dot.tests { background: #a78bfa; }
    .breakdown-dot.tests-passed { background: var(--success); }
    .breakdown-dot.tests-failed { background: var(--danger); }
    .breakdown-label { color: var(--text-secondary); font-size: 0.9rem; }
    .breakdown-value { font-weight: 600; color: var(--text-primary); }
    .compact-metrics { display: flex; flex-direction: column; gap: 10px; }
    .metrics-group { background: var(--bg-hover); padding: 12px 16px; border-radius: 8px; border-left: 3px solid var(--primary); }
    .metrics-group.coverage-group { border-left-color: var(--success); }
    .metrics-group.test-group { border-left-color: #a78bfa; }
    .metrics-group-title { font-size: 0.8rem; font-weight: 600; color: var(--text-secondary); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px; }
    .metrics-inline { display: flex; gap: 16px; flex-wrap: wrap; align-items: center; font-size: 0.9rem; }
    .metrics-inline .breakdown-item { margin: 0; }
    .section-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px; flex-wrap: wrap; gap: 16px; }
    .section-title { font-size: 1.5rem; font-weight: 700; display: flex; align-items: center; gap: 12px; }
    .legend { display: flex; gap: 20px; background: #f1f5f9; padding: 12px 20px; border-radius: 10px; }
    .legend-item { display: flex; align-items: center; gap: 8px; font-size: 0.85rem; color: var(--text-secondary); pointer-events: none; }
    .legend-color { width: 16px; height: 16px; border-radius: 4px; }
    .legend-color.high { background: var(--success); }
    .legend-color.medium { background: var(--warning); }
    .legend-color.low { background: var(--danger); }
    .files-table { background: var(--bg-card); border-radius: 16px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .files-table table { width: 100%; border-collapse: collapse; }
    .files-table th { background: #f8fafc; padding: 16px 24px; text-align: left; font-weight: 600; color: var(--text-secondary); font-size: 0.85rem; text-transform: uppercase; letter-spacing: 1px; border-bottom: 1px solid var(--border); }
    .files-table td { padding: 20px 24px; border-bottom: 1px solid var(--border); vertical-align: middle; }
    .files-table tr:last-child td { border-bottom: none; }
    .files-table tbody tr { transition: all 0.2s ease; animation: fadeInUp 0.5s ease-out forwards; opacity: 0; cursor: pointer; }
    .files-table tbody tr:hover { background: var(--bg-hover); }
    .file-info { display: flex; flex-direction: column; gap: 4px; }
    .file-name { font-weight: 600; color: var(--text-primary); text-decoration: none; font-size: 1rem; transition: color 0.2s; }
    .file-name:hover { color: var(--primary-light); }
    .file-path { color: var(--text-muted); font-size: 0.85rem; font-family: 'SF Mono', 'Consolas', 'Liberation Mono', Menlo, monospace; }
    .lines-info { text-align: center; }
    .lines-covered { font-weight: 700; font-size: 1.1rem; color: var(--text-primary); }
    .lines-total { color: var(--text-muted); font-size: 0.85rem; }
    .coverage-cell { width: 200px; }
    .coverage-bar-container { display: flex; align-items: center; gap: 16px; }
    .coverage-bar { flex: 1; height: 10px; background: var(--bg-hover); border-radius: 5px; overflow: hidden; }
    .coverage-bar-fill { height: 100%; border-radius: 5px; transition: width 1s ease-out; }
    .coverage-bar-fill.high { background: linear-gradient(90deg, var(--success) 0%, var(--success-light) 100%); }
    .coverage-bar-fill.medium { background: linear-gradient(90deg, var(--warning) 0%, var(--warning-light) 100%); }
    .coverage-bar-fill.low { background: linear-gradient(90deg, var(--danger) 0%, var(--danger-light) 100%); }
    .coverage-percent { font-weight: 700; font-size: 1rem; min-width: 50px; text-align: right; }
    .coverage-percent.high { color: var(--success); }
    .coverage-percent.medium { color: var(--warning); }
    .coverage-percent.low { color: var(--danger); }
    .view-btn { display: inline-flex; align-items: center; gap: 8px; padding: 10px 20px; background: var(--bg-hover); border: 1px solid var(--border); border-radius: 8px; color: var(--text-primary); text-decoration: none; font-size: 0.9rem; font-weight: 500; transition: all 0.2s; }
    .view-btn:hover { background: var(--primary); border-color: var(--primary); }
    .footer { max-width: 1400px; margin: 0 auto; padding: 40px 30px; text-align: center; border-top: 1px solid var(--border); }
    .footer-content { display: flex; justify-content: center; align-items: center; gap: 10px; flex-wrap: wrap; }
    .footer-text { color: var(--text-muted); font-size: 0.9rem; }
    .footer-link { color: var(--primary-light); text-decoration: none; font-weight: 500; transition: color 0.2s; }
    .footer-link:hover { color: var(--primary); }
    .footer-divider { width: 4px; height: 4px; background: var(--text-muted); border-radius: 50%; }
    @media (max-width: 768px) {
      .header-content { padding: 30px 20px; } .header-title { font-size: 1.8rem; }
      .main { padding: 30px 20px; }
      .gauge-section { flex-direction: column; padding: 30px; gap: 30px; }
      .gauge-container { width: 160px; height: 160px; }
      .gauge-text { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%); width: 100%; }
      .gauge-percent { font-size: 2.5rem; line-height: 1; margin: 0; }
      .gauge-label { font-size: 0.75rem; letter-spacing: 1.5px; margin: 0; }
      .metrics-inline { flex-direction: column; gap: 10px; align-items: flex-start; }
      .files-table th, .files-table td { padding: 15px; }
      .coverage-cell { width: auto; }
      .coverage-bar-container { flex-direction: column; align-items: flex-start; gap: 8px; }
      .coverage-bar { width: 100%; }
    }
  </style>
</head>
<body>
  <header class="header">
    <div class="header-content">
      <div class="header-top">
        <div class="logo">
          <img src="https://bashunit.com/logo.svg" alt="bashunit">
          <div class="logo-text">bashunit <span>coverage</span></div>
        </div>
EOF
    echo "        <div class=\"header-badge\">v${BASHUNIT_VERSION:-0.0.0}</div>"
    cat <<'EOF'
      </div>
      <h1 class="header-title">Code Coverage Report</h1>
      <p class="header-subtitle">Comprehensive line-by-line coverage analysis for your bash scripts</p>
    </div>
  </header>
  <main class="main">
    <section class="gauge-section">
      <div class="gauge-container">
        <svg viewBox="0 0 160 160" width="200" height="200">
          <defs>
            <linearGradient id="gaugeGradient" x1="0%" y1="0%" x2="100%" y2="0%">
EOF
    echo "              <stop offset=\"0%\" style=\"stop-color:${gauge_color_start}\"/>"
    echo "              <stop offset=\"100%\" style=\"stop-color:${gauge_color_end}\"/>"
    cat <<'EOF'
            </linearGradient>
          </defs>
          <circle class="gauge-bg" cx="80" cy="80" r="70"/>
EOF
    echo "          <circle class=\"gauge-fill\" cx=\"80\" cy=\"80\" r=\"70\" stroke-dasharray=\"440\" stroke-dashoffset=\"${gauge_offset}\"/>"
    cat <<'EOF'
        </svg>
        <div class="gauge-text">
EOF
    echo "          <div class=\"gauge-percent\">${total_pct}%</div>"
    cat <<'EOF'
          <div class="gauge-label">Coverage</div>
        </div>
      </div>
      <div class="gauge-info">
        <h2 class="gauge-title">Overall Code Coverage</h2>
EOF
    echo "        <p class=\"gauge-description\"><strong>${total_hit} of ${total_executable}</strong> executable lines covered across <strong>${file_count} files</strong>.</p>"
    cat <<'EOF'

        <div class="compact-metrics">
          <div class="metrics-group coverage-group">
            <div class="metrics-group-title">Coverage Metrics</div>
            <div class="metrics-inline">
              <div class="breakdown-item">
                <span class="breakdown-dot total"></span>
                <span class="breakdown-label">Total:</span>
EOF
    echo "                <span class=\"breakdown-value\">${total_executable} lines</span>"
    cat <<'EOF'
              </div>
              <div class="breakdown-item">
                <span class="breakdown-dot covered"></span>
                <span class="breakdown-label">Covered:</span>
EOF
    echo "                <span class=\"breakdown-value\">${total_hit} lines</span>"
    cat <<'EOF'
              </div>
              <div class="breakdown-item">
                <span class="breakdown-dot uncovered"></span>
                <span class="breakdown-label">Uncovered:</span>
EOF
    echo "                <span class=\"breakdown-value\">${total_uncovered} lines</span>"
    cat <<'EOF'
              </div>
            </div>
          </div>
          <div class="metrics-group test-group">
            <div class="metrics-group-title">Test Results</div>
            <div class="metrics-inline">
              <div class="breakdown-item">
                <span class="breakdown-dot files"></span>
                <span class="breakdown-label">Files:</span>
EOF
    echo "                <span class=\"breakdown-value\">${file_count}</span>"
    cat <<'EOF'
              </div>
              <div class="breakdown-item">
                <span class="breakdown-dot tests"></span>
                <span class="breakdown-label">Tests:</span>
EOF
    echo "                <span class=\"breakdown-value\">${tests_total} total</span>"
    cat <<'EOF'
              </div>
              <div class="breakdown-item">
                <span class="breakdown-dot tests-passed"></span>
                <span class="breakdown-label">Passed:</span>
EOF
    echo "                <span class=\"breakdown-value\">${tests_passed}</span>"
    cat <<'EOF'
              </div>
              <div class="breakdown-item">
                <span class="breakdown-dot tests-failed"></span>
                <span class="breakdown-label">Failed:</span>
EOF
    echo "                <span class=\"breakdown-value\">${tests_failed}</span>"
    cat <<'EOF'
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    <section>
      <div class="section-header">
        <h2 class="section-title">File Coverage Details</h2>
        <div class="legend">
          <div class="legend-item">
            <span class="legend-color high"></span>
EOF
    echo "            <span>≥${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH}% High</span>"
    cat <<'EOF'
          </div>
          <div class="legend-item">
            <span class="legend-color medium"></span>
EOF
    echo "            <span>${BASHUNIT_COVERAGE_THRESHOLD_LOW:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW}-${BASHUNIT_COVERAGE_THRESHOLD_HIGH:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_HIGH}% Medium</span>"
    cat <<'EOF'
          </div>
          <div class="legend-item">
            <span class="legend-color low"></span>
EOF
    echo "            <span>&lt;${BASHUNIT_COVERAGE_THRESHOLD_LOW:-$_BASHUNIT_DEFAULT_COVERAGE_THRESHOLD_LOW}% Low</span>"
    cat <<'EOF'
          </div>
        </div>
      </div>
      <div class="files-table">
        <table>
          <thead>
            <tr>
              <th>File</th>
              <th style="text-align: center;">Lines</th>
              <th>Coverage</th>
            </tr>
          </thead>
          <tbody>
EOF

    local data display_file hit executable pct safe_filename
    for data in ${file_data[@]+"${file_data[@]}"}; do
      IFS='|' read -r display_file hit executable pct safe_filename <<<"$data"

      local class
      bashunit::coverage::class_to_slot "$pct"
      class="$_BASHUNIT_COVERAGE_CLASS_OUT"

      echo "            <tr onclick=\"window.location='files/${safe_filename}.html'\">"
      echo "              <td>"
      echo "                <div class=\"file-info\">"
      echo "                  <a href=\"files/${safe_filename}.html\" class=\"file-name\">$(basename "$display_file")</a>"
      echo "                  <div class=\"file-path\">./${display_file}</div>"
      echo "                </div>"
      echo "              </td>"
      echo "              <td>"
      echo "                <div class=\"lines-info\">"
      echo "                  <div class=\"lines-covered\">${hit}</div>"
      echo "                  <div class=\"lines-total\">of ${executable} lines</div>"
      echo "                </div>"
      echo "              </td>"
      echo "              <td class=\"coverage-cell\">"
      echo "                <div class=\"coverage-bar-container\">"
      echo "                  <div class=\"coverage-bar\">"
      echo "                    <div class=\"coverage-bar-fill $class\" style=\"width: ${pct}%;\"></div>"
      echo "                  </div>"
      echo "                  <span class=\"coverage-percent $class\">${pct}%</span>"
      echo "                </div>"
      echo "              </td>"
      echo "            </tr>"
    done

    cat <<'EOF'
          </tbody>
        </table>
      </div>
    </section>
  </main>
  <footer class="footer">
    <div class="footer-content">
      <span class="footer-text">Generated by</span>
      <a href="https://bashunit.com" class="footer-link" target="_blank">bashunit</a>
      <span class="footer-divider"></span>
      <span class="footer-text">Documentation at</span>
      <a href="https://bashunit.com/coverage" class="footer-link" target="_blank">bashunit.com/coverage</a>
    </div>
  </footer>
</body>
</html>
EOF
  } >"$output_file"
}

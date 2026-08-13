#!/usr/bin/env bash

# HTML coverage report: the per-file page.

# The code table of one page, in one awk pass.
#
# The Bash loop that did this classified, looked up and echoed per source line:
# 8116ms for 128 pages over 22,405 lines, with no forks left in it -- Bash is
# simply the wrong tool for emitting 7MB of markup (#1098). Every input it
# needs is already a file: the aggregated hits, the per-line test list and the
# source itself.
#
# Composed with the classifier rules, which are included ahead of it.
# shellcheck disable=SC2016
_BASHUNIT_COVERAGE_AWK_HTML_ROWS='
FILENAME == hitsfile {
  hits[$1 + 0] = $2 + 0
  next
}

FILENAME == testsfile {
  # "<lineno>|<test_file>:<test_fn>", deduplicated, first-seen order kept.
  p = index($0, "|")
  if (p == 0) { next }
  tln = substr($0, 1, p - 1) + 0
  info = substr($0, p + 1)
  key = tln SUBSEP info
  if (key in seen) { next }
  seen[key] = 1
  tests[tln] = (tln in tests) ? tests[tln] "\n" info : info
  next
}

{
  total++
  sl[total] = $0
}

function escape(t) {
  gsub(/&/, "\\&amp;", t)
  gsub(/</, "\\&lt;", t)
  gsub(/>/, "\\&gt;", t)
  return t
}

END {
  # The DEBUG trap attributes a multi-line statement to its starting line, so
  # the count carries forward across the backslash chain (#722).
  carry = 0
  for (ln = 1; ln <= total; ln++) {
    h = (ln in hits) ? hits[ln] : 0
    if (carry > 0 && h < carry) { h = carry; hits[ln] = h }
    if (h > 0 && bu_ends_with_continuation(sl[ln])) { carry = h } else { carry = 0 }
  }

  for (ln = 1; ln <= total; ln++) {
    row_class = ""
    hits_display = ""

    if (bu_is_executable(sl[ln])) {
      h = (ln in hits) ? hits[ln] : 0
      if (h > 0) {
        row_class = "covered"
        if (ln in tests) {
          tooltip = "<div class=\"hits-tooltip\"><div class=\"hits-tooltip-title\">Tests hitting this line</div><ul class=\"hits-tooltip-list\">"
          n = split(tests[ln], entries, "\n")
          for (e = 1; e <= n; e++) {
            if (entries[e] == "") { continue }
            c = index(entries[e], ":")
            if (c == 0) { tfile = entries[e]; tfn = "" } else { tfile = substr(entries[e], 1, c - 1); tfn = substr(entries[e], c + 1) }
            sub(/^.*\//, "", tfile)
            tooltip = tooltip "<li><span class=\"hits-tooltip-file\">" tfile "</span>:<span class=\"hits-tooltip-fn\">" tfn "</span></li>"
          }
          tooltip = tooltip "</ul></div>"
          hits_display = "<span class=\"hits-badge has-tooltip\">" h times tooltip "</span>"
        } else {
          hits_display = "<span class=\"hits-badge\">" h times "</span>"
        }
      } else {
        row_class = "uncovered"
        hits_display = "<span class=\"hits-badge\">" h times "</span>"
      }
    }

    printf "          <tr id=\"line-%s\" class=\"%s line-anchor\">\n", ln, row_class
    printf "            <td class=\"line-num\">%s</td>\n", ln
    printf "            <td class=\"hits\">%s</td>\n", hits_display
    printf "            <td class=\"code\">%s</td>\n", escape(sl[ln])
    printf "          </tr>\n"
  }
}
'

##
# Emits the code-table rows of one page.
# Arguments: $1 - source file, $2 - file holding its per-line test list
##
function bashunit::coverage::html_code_rows() {
  local file="$1" tests_file="$2"

  bashunit::coverage::ensure_hits_aggregated
  bashunit::coverage::hits_file_for "$file"
  local hits_file="$_BASHUNIT_COVERAGE_HITS_FILE_OUT"
  if [ -z "$hits_file" ] || [ ! -f "$hits_file" ]; then
    hits_file="/dev/null"
  fi

  # The multiplication sign comes in as a value, not as an awk escape: `\x` is
  # not POSIX awk, so the byte sequence stays on the shell side.
  env LC_ALL=C "$AWK" -v hitsfile="$hits_file" -v testsfile="$tests_file" -v times="×" \
    "${_BASHUNIT_COVERAGE_AWK_RULES}${_BASHUNIT_COVERAGE_AWK_HTML_ROWS}" \
    "$hits_file" "$tests_file" "$file"
}

function bashunit::coverage::generate_file_html() {
  local file="$1"
  local output_file="$2"

  local display_file="${file#"$PWD"/}"
  local executable hit pct class stats
  stats=$(bashunit::coverage::get_cached_stats "$file")
  bashunit::coverage::split_stats "$stats"
  executable="$_BASHUNIT_COVERAGE_SPLIT_EXEC_OUT"
  hit="$_BASHUNIT_COVERAGE_SPLIT_HIT_OUT"
  pct="$_BASHUNIT_COVERAGE_SPLIT_PCT_OUT"
  class="$_BASHUNIT_COVERAGE_SPLIT_CLASS_OUT"
  local uncovered=$((executable - hit))

  # Pre-load all line hits into indexed array (performance optimization)
  bashunit::coverage::load_hits_by_line "$file"

  # Pre-load all file lines into indexed array (avoids sed per line)
  local -a file_lines=()
  local _fli=0 _fl
  while IFS= read -r _fl || [ -n "$_fl" ]; do
    file_lines[_fli]="$_fl"
    ((++_fli))
  done <"$file"

  # The per-line test list, for the tooltips. It goes to a file because the row
  # emitter below is one awk pass that reads it alongside the hits and the
  # source (#1098).
  local tests_file="${_BASHUNIT_COVERAGE_DATA_FILE%/*}/page-tests"
  if ! bashunit::coverage::get_all_line_tests "$file" >"$tests_file" 2>/dev/null; then
    : >"$tests_file"
  fi

  # Count total lines and functions
  local total_lines="${#file_lines[@]}"
  local non_executable=$((total_lines - executable))

  {
    bashunit::coverage::emit_block <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
EOF
    echo "  <title>${display_file##*/} | Coverage Report</title>"
    bashunit::coverage::emit_block <<'EOF'
  <style>
    :root {
      --primary: #6366f1; --primary-dark: #4f46e5; --primary-light: #818cf8;
      --success: #10b981; --success-bg: rgba(16, 185, 129, 0.1); --success-border: rgba(16, 185, 129, 0.2);
      --warning: #f59e0b;
      --danger: #ef4444; --danger-bg: rgba(239, 68, 68, 0.1); --danger-border: rgba(239, 68, 68, 0.2);
      --bg-light: #ffffff; --bg-card: #f8fafc; --bg-hover: #e1e5ea; --bg-code: #f6f8fa;
      --text-primary: #0f172a; --text-secondary: #475569; --text-muted: #94a3b8;
      --border: #e2e8f0; --line-number-bg: #f8fafc;
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background: var(--bg-light); color: var(--text-primary); min-height: 100vh; line-height: 1.6; }
    .header { background: var(--bg-card); border-bottom: 1px solid var(--border); padding: 20px 30px; position: sticky; top: 0; z-index: 100; backdrop-filter: blur(10px); box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
    .header-content { max-width: 1600px; margin: 0 auto; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 20px; }
    .nav-section { display: flex; align-items: center; gap: 20px; flex-wrap: wrap; }
    .back-btn { display: inline-flex; align-items: center; gap: 8px; padding: 12px 24px; background: #475569; border: 2px solid #475569; border-radius: 8px; color: #ffffff; text-decoration: none; font-size: 1rem; font-weight: 600; transition: all 0.2s; box-shadow: 0 2px 4px rgba(71, 85, 105, 0.2); }
    .back-btn:hover { background: #334155; border-color: #334155; box-shadow: 0 4px 12px rgba(51, 65, 85, 0.3); }
    .file-title { display: flex; align-items: center; gap: 12px; }
    .file-name { font-size: 1.3rem; font-weight: 700; font-family: 'SF Mono', 'Consolas', 'Liberation Mono', Menlo, monospace; }
    .stats-section { display: flex; align-items: center; gap: 30px; flex-wrap: wrap; }
    .stat-item { display: flex; align-items: center; gap: 10px; }
    .stat-badge { padding: 8px 16px; border-radius: 20px; font-weight: 600; font-size: 0.9rem; }
    .stat-badge.coverage.high { background: linear-gradient(135deg, var(--success) 0%, #34d399 100%); color: #000; }
    .stat-badge.coverage.medium { background: linear-gradient(135deg, var(--warning) 0%, #fbbf24 100%); color: #000; }
    .stat-badge.coverage.low { background: linear-gradient(135deg, var(--danger) 0%, #f87171 100%); color: #fff; }
    .stat-badge.lines { background: var(--bg-hover); color: var(--text-primary); }
    .stat-label { color: var(--text-secondary); font-size: 0.85rem; }
    .summary-bar { background: var(--bg-card); border-bottom: 1px solid var(--border); padding: 20px 30px; }
    .summary-content { max-width: 1600px; margin: 0 auto; display: flex; align-items: center; gap: 40px; flex-wrap: wrap; }
    .progress-section { flex: 1; min-width: 300px; }
    .progress-header { display: flex; justify-content: space-between; margin-bottom: 8px; }
    .progress-label { color: var(--text-secondary); font-size: 0.9rem; }
    .progress-percent { font-weight: 700; }
    .progress-percent.high { color: var(--success); }
    .progress-percent.medium { color: var(--warning); }
    .progress-percent.low { color: var(--danger); }
    .progress-bar { height: 12px; background: var(--bg-hover); border-radius: 6px; overflow: hidden; }
    .progress-fill { height: 100%; border-radius: 6px; transition: width 1s ease-out; }
    .progress-fill.high { background: linear-gradient(90deg, #059669 0%, #10b981 100%); }
    .progress-fill.medium { background: linear-gradient(90deg, #d97706 0%, #f59e0b 100%); }
    .progress-fill.low { background: linear-gradient(90deg, #dc2626 0%, #ef4444 100%); }
    .legend { display: flex; gap: 24px; flex-wrap: wrap; }
    .legend-item { display: flex; align-items: center; gap: 8px; font-size: 0.9rem; color: var(--text-secondary); pointer-events: none; }
    .legend-color { width: 16px; height: 16px; border-radius: 4px; }
    .legend-color.covered { background: var(--success); }
    .legend-color.uncovered { background: var(--danger); }
    .legend-color.neutral { background: var(--text-muted); }
    .code-container { max-width: 1600px; margin: 30px auto; padding: 0 30px; }
    .code-wrapper { background: var(--bg-code); border-radius: 16px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1); }
    .code-header { background: var(--line-number-bg); padding: 16px 24px; display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid var(--border); flex-wrap: wrap; gap: 12px; }
    .code-path { font-family: 'SF Mono', 'Consolas', 'Liberation Mono', Menlo, monospace; font-size: 0.9rem; color: var(--text-secondary); }
    .code-stats { display: flex; gap: 16px; font-size: 0.85rem; }
    .code-stats span { padding: 4px 12px; background: #e5e7eb; border-radius: 4px; color: var(--text-secondary); }
    .code-body { overflow-x: auto; }
    .code-table { width: 100%; border-collapse: collapse; font-family: 'SF Mono', 'Consolas', 'Liberation Mono', Menlo, monospace; font-size: 13px; line-height: 1.6; }
    .code-table tr { transition: background 0.15s; }
    .line-num { width: 60px; padding: 2px 16px; text-align: right; color: #9ca3af; background: var(--line-number-bg); border-right: 1px solid var(--border); user-select: none; vertical-align: top; }
    .hits { width: 60px; padding: 2px 12px; text-align: center; color: #9ca3af; background: var(--line-number-bg); border-right: 1px solid var(--border); font-size: 0.85em; vertical-align: top; }
    .hits-badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 0.8em; font-weight: 600; position: relative; }
    .hits-badge.has-tooltip { cursor: help; }
    .covered .hits-badge { background: var(--success-bg); color: var(--success); }
    .uncovered .hits-badge { background: var(--danger-bg); color: var(--danger); }
    .hits-tooltip { display: none; position: absolute; left: 100%; top: 50%; transform: translateY(-50%); margin-left: 12px; padding: 10px 14px; background: #1e293b; color: #f1f5f9; border-radius: 8px; font-size: 11px; font-weight: 400; white-space: normal; z-index: 100; box-shadow: 0 4px 12px rgba(0,0,0,0.15); min-width: 200px; max-width: 500px; width: max-content; }
    .hits-tooltip::after { content: ''; position: absolute; right: 100%; top: 50%; transform: translateY(-50%); border: 6px solid transparent; border-right-color: #1e293b; }
    .hits-badge:hover .hits-tooltip { display: block; }
    .hits-tooltip-title { font-weight: 600; margin-bottom: 6px; color: #94a3b8; font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px; }
    .hits-tooltip-list { margin: 0; padding: 0; list-style: none; }
    .hits-tooltip-list li { padding: 3px 0; border-bottom: 1px solid #334155; font-family: 'SF Mono', 'Consolas', 'Liberation Mono', Menlo, monospace; }
    .hits-tooltip-list li:last-child { border-bottom: none; }
    .hits-tooltip-file { color: #60a5fa; }
    .hits-tooltip-fn { color: #a5b4fc; }
    .code { padding: 2px 20px; white-space: pre; vertical-align: top; }
    .covered { background: #d1fae5; }
    .covered .line-num, .covered .hits { background: #a7f3d0; border-color: var(--success-border); }
    .covered:hover { background: #ecfdf5; }
    .covered:hover .line-num, .covered:hover .hits { background: #d1fae5; }
    .uncovered { background: #fee2e2; }
    .uncovered .line-num, .uncovered .hits { background: #fecaca; border-color: var(--danger-border); }
    .uncovered:hover { background: #fef2f2; }
    .uncovered:hover .line-num, .uncovered:hover .hits { background: #fee2e2; }
    .function-summary { max-width: 1600px; margin: 30px auto; padding: 0 30px; }
    .function-table { background: var(--bg-card); border-radius: 16px; overflow: hidden; border: 1px solid var(--border); box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1); width: 100%; border-collapse: collapse; }
    .function-table th { background: #f1f5f9; padding: 14px 20px; text-align: left; font-weight: 600; color: var(--text-secondary); font-size: 0.85rem; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 2px solid var(--border); }
    .function-table th:first-child { width: 40%; }
    .function-table th:nth-child(2), .function-table th:nth-child(3) { text-align: center; }
    .function-table td { padding: 12px 20px; border-bottom: 1px solid var(--border); vertical-align: middle; }
    .function-table tr:last-child td { border-bottom: none; }
    .function-table tbody tr { transition: background 0.15s; }
    .function-table tbody tr:hover { background: var(--bg-hover); }
    .function-table tbody tr.fn-covered { background: #f0fdf4; }
    .function-table tbody tr.fn-covered:hover { background: #dcfce7; }
    .function-table tbody tr.fn-partial { background: #fffbeb; }
    .function-table tbody tr.fn-partial:hover { background: #fef3c7; }
    .function-table tbody tr.fn-uncovered { background: #fef2f2; }
    .function-table tbody tr.fn-uncovered:hover { background: #fee2e2; }
    .fn-name { font-weight: 600; color: var(--primary); cursor: pointer; text-decoration: none; font-family: 'SF Mono', 'Consolas', 'Liberation Mono', Menlo, monospace; font-size: 0.95rem; }
    .fn-name:hover { color: var(--primary-dark); text-decoration: underline; }
    .fn-lines { text-align: center; color: var(--text-secondary); font-size: 0.9rem; }
    .fn-coverage-cell { text-align: center; }
    .fn-coverage-bar { display: flex; align-items: center; gap: 12px; justify-content: center; }
    .fn-progress { width: 100px; height: 8px; background: #e5e7eb; border-radius: 4px; overflow: hidden; }
    .fn-progress-fill { height: 100%; border-radius: 4px; }
    .fn-progress-fill.high { background: var(--success); }
    .fn-progress-fill.medium { background: var(--warning); }
    .fn-progress-fill.low { background: var(--danger); }
    .fn-pct { font-weight: 600; font-size: 0.9rem; min-width: 50px; text-align: right; }
    .fn-pct.high { color: var(--success); }
    .fn-pct.medium { color: var(--warning); }
    .fn-pct.low { color: var(--danger); }
    .line-anchor { scroll-margin-top: 200px; }
    .line-anchor:target { animation: highlightFade 4s ease-out forwards; }
    .line-anchor:target .line-num, .line-anchor:target .hits { animation: highlightFade 4s ease-out forwards; }
    @keyframes highlightFade {
      0% { background: #93c5fd; }
      70% { background: #dbeafe; }
      100% { background: transparent; }
    }
    .footer { max-width: 1600px; margin: 0 auto; padding: 40px 30px; text-align: center; }
    .footer-text { color: var(--text-muted); font-size: 0.9rem; }
    .footer-link { color: var(--primary-light); text-decoration: none; font-weight: 500; }
    .footer-link:hover { color: var(--primary); }
    @media (max-width: 768px) {
      .header { padding: 15px 20px; } .header-content { gap: 15px; }
      .stats-section { gap: 15px; } .summary-bar { padding: 15px 20px; }
      .summary-content { gap: 20px; } .code-container { padding: 0 15px; margin: 20px auto; }
      .code-header { padding: 12px 16px; } .line-num, .hits { padding: 2px 8px; }
      .code { padding: 2px 12px; }
    }
  </style>
</head>
<body>
  <header class="header">
    <div class="header-content">
      <div class="nav-section">
        <a href="../index.html" class="back-btn">← Back to Overview</a>
        <div class="file-title">
EOF
    echo "          <span class=\"file-name\">${display_file##*/}</span>"
    bashunit::coverage::emit_block <<'EOF'
        </div>
      </div>
      <div class="stats-section">
        <div class="stat-item">
EOF
    echo "          <span class=\"stat-badge coverage $class\">${pct}%</span>"
    bashunit::coverage::emit_block <<'EOF'
          <span class="stat-label">Coverage</span>
        </div>
        <div class="stat-item">
EOF
    echo "          <span class=\"stat-badge lines\">${hit}/${executable}</span>"
    bashunit::coverage::emit_block <<'EOF'
          <span class="stat-label">Lines</span>
        </div>
      </div>
    </div>
  </header>
  <div class="summary-bar">
    <div class="summary-content">
      <div class="progress-section">
        <div class="progress-header">
          <span class="progress-label">Line Coverage Progress</span>
EOF
    echo "          <span class=\"progress-percent $class\">${pct}%</span>"
    bashunit::coverage::emit_block <<'EOF'
        </div>
        <div class="progress-bar">
EOF
    echo "          <div class=\"progress-fill $class\" style=\"width: ${pct}%;\"></div>"
    bashunit::coverage::emit_block <<'EOF'
        </div>
      </div>
      <div class="legend">
        <div class="legend-item">
          <span class="legend-color covered"></span>
EOF
    echo "          <span>${hit} lines covered</span>"
    bashunit::coverage::emit_block <<'EOF'
        </div>
        <div class="legend-item">
          <span class="legend-color uncovered"></span>
EOF
    echo "          <span>${uncovered} lines uncovered</span>"
    bashunit::coverage::emit_block <<'EOF'
        </div>
        <div class="legend-item">
          <span class="legend-color neutral"></span>
EOF
    echo "          <span>${non_executable} non-executable</span>"
    bashunit::coverage::emit_block <<'EOF'
        </div>
      </div>
    </div>
  </div>
EOF

    # Extract functions and generate summary table
    local functions_data
    functions_data=$(bashunit::coverage::extract_functions "$file")

    if [ -n "$functions_data" ]; then
      bashunit::coverage::emit_block <<'EOF'
  <div class="function-summary">
    <table class="function-table">
      <thead>
        <tr>
          <th>Function</th>
          <th>Lines</th>
          <th>Coverage</th>
        </tr>
      </thead>
      <tbody>
EOF
      local fn_entry
      while IFS= read -r fn_entry; do
        [ -z "$fn_entry" ] && continue
        local fn_name fn_start fn_end
        fn_name="${fn_entry%%|*}"
        local rest="${fn_entry#*|}"
        fn_start="${rest%%|*}"
        fn_end="${rest#*|}"

        # Calculate function coverage using pre-loaded hits data
        local fn_executable=0
        local fn_hit=0
        local ln
        for ((ln = fn_start; ln <= fn_end; ln++)); do
          local ln_content
          ln_content="${file_lines[$((ln - 1))]:-}"
          if bashunit::coverage::is_executable_line "$ln_content" "$ln"; then
            ((++fn_executable))
            local ln_hits=${_BASHUNIT_COVERAGE_HITS_BY_LINE[$ln]:-0}
            if [ "$ln_hits" -gt 0 ]; then
              ((++fn_hit))
            fi
          fi
        done

        local fn_pct fn_class row_class
        fn_pct=0
        if [ "$fn_executable" -gt 0 ]; then
          fn_pct=$((fn_hit * 100 / fn_executable))
        fi
        bashunit::coverage::class_to_slot "$fn_pct"
        fn_class="$_BASHUNIT_COVERAGE_CLASS_OUT"
        case "$fn_class" in
        high) row_class="fn-covered" ;;
        medium) row_class="fn-partial" ;;
        low) row_class="fn-uncovered" ;;
        esac

        echo "        <tr class=\"$row_class\">"
        echo "          <td><a href=\"#line-${fn_start}\" class=\"fn-name\">${fn_name}</a></td>"
        echo "          <td class=\"fn-lines\">${fn_hit} / ${fn_executable}</td>"
        echo "          <td class=\"fn-coverage-cell\">"
        echo "            <div class=\"fn-coverage-bar\">"
        echo "              <div class=\"fn-progress\"><div class=\"fn-progress-fill ${fn_class}\" style=\"width: ${fn_pct}%;\"></div></div>"
        echo "              <span class=\"fn-pct ${fn_class}\">${fn_pct}%</span>"
        echo "            </div>"
        echo "          </td>"
        echo "        </tr>"
      done <<<"$functions_data"

      bashunit::coverage::emit_block <<'EOF'
      </tbody>
    </table>
  </div>
EOF
    fi

    bashunit::coverage::emit_block <<'EOF'
  <div class="code-container">
    <div class="code-wrapper">
      <div class="code-header">
EOF
    echo "        <span class=\"code-path\">./${display_file}</span>"
    echo "        <div class=\"code-stats\">"
    echo "          <span>${total_lines} total lines</span>"
    echo "        </div>"
    bashunit::coverage::emit_block <<'EOF'
      </div>
      <div class="code-body">
        <table class="code-table">
EOF

    bashunit::coverage::html_code_rows "$file" "$tests_file"

    bashunit::coverage::emit_block <<'EOF'
        </table>
      </div>
    </div>
  </div>
  <footer class="footer">
    <p class="footer-text">
      Generated by <a href="https://bashunit.com" class="footer-link" target="_blank">bashunit</a>
    </p>
  </footer>
</body>
</html>
EOF
  } >"$output_file"
}

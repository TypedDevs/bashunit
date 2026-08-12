#!/usr/bin/env bash

# Verify the built VitePress sitemap still describes the site exactly: one entry
# per published page, nothing extra, every entry dated, no date in the future.
# Google only keeps using <lastmod> for recrawl scheduling while it stays
# verifiably accurate, and a single leaked non-page (public/*.md has slipped in
# before) is enough to poison that.
#
# Usage: check_sitemap.sh [dist-dir]

set -eu

dist="${1:-docs/.vitepress/dist}"
sitemap="$dist/sitemap.xml"
robots="$dist/robots.txt"
site="https://bashunit.com"
errors=0

fail() {
  printf 'sitemap: %s\n' "$1" >&2
  errors=$((errors + 1))
}

if [ ! -s "$sitemap" ]; then
  fail "$sitemap is missing or empty"
  exit 1
fi

# 404 is the only built page that must stay out of the sitemap.
built=$(cd "$dist" && find . -name '*.html' \
  | sed 's|^\./||; s|\.html$||; s|^index$||; s|/index$|/|' \
  | grep -v '^404$' | sort)

locs=$(grep -o '<loc>[^<]*</loc>' "$sitemap" | sed 's|<loc>||; s|</loc>||')
listed=$(printf '%s\n' "$locs" | sed "s|^$site/||" | sort)

missing=$(comm -23 <(printf '%s\n' "$built") <(printf '%s\n' "$listed"))
[ -z "$missing" ] || fail "pages built but not listed: $(echo "$missing" | tr '\n' ' ')"

orphan=$(comm -13 <(printf '%s\n' "$built") <(printf '%s\n' "$listed"))
[ -z "$orphan" ] || fail "listed but not built: $(echo "$orphan" | tr '\n' ' ')"

foreign=$(printf '%s\n' "$locs" | grep -v "^$site/" || true)
[ -z "$foreign" ] || fail "loc outside $site: $(echo "$foreign" | tr '\n' ' ')"

# VitePress emits the whole sitemap on one line, so counting needs -o, not -c.
urls=$(grep -o '<url>' "$sitemap" | wc -l | tr -d ' ')
dated=$(grep -o '<lastmod>' "$sitemap" | wc -l | tr -d ' ')
[ "$urls" = "$dated" ] || fail "$urls urls but $dated lastmod entries"

future=$(grep -o '<lastmod>[^<]*</lastmod>' "$sitemap" \
  | sed 's|<lastmod>||; s|</lastmod>||' | cut -c1-10 | sort -u \
  | awk -v today="$(date -u +%Y-%m-%d)" '$0 > today' || true)
[ -z "$future" ] || fail "lastmod in the future: $(echo "$future" | tr '\n' ' ')"

if [ ! -f "$robots" ]; then
  fail "robots.txt is missing from $dist"
elif ! grep -q "^Sitemap: $site/sitemap.xml\$" "$robots"; then
  fail "robots.txt does not advertise $site/sitemap.xml"
fi

if [ "$errors" -gt 0 ]; then
  exit 1
fi

printf 'sitemap: OK (%s urls, all dated, robots.txt advertises it)\n' "$urls"

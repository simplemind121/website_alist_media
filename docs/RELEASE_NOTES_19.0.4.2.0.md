# Release notes — 19.0.4.2.0

**Date:** 2026-09-23  
**Type:** Stability (compatible upgrade from 19.0.4.1.1)  
**Tag:** [`v19.0.4.2.0`](https://github.com/simplemind121/website_alist_media/releases/tag/v19.0.4.2.0)

## Highlights

- Production-safe link health cron (time budgets, clamped knobs, failure hysteresis)
- Better video thumbnails / posters without extra API calls
- Hardening for late registration of background-video builder plugins

## Changes

### Added / improved

- Link scan & check **time budgets** (default 120s each, configurable with hard caps)
- `fail_count` + threshold before marking links broken (reduces CDN flapping false positives)
- Batch DB writes and shared HTTP `Session` during checks
- Auto `poster` from same-stem image (`demo.mp4` ↔ `demo.jpg` / `demo-poster.png`)
- Grid thumb fallback + play badge when AList/S3 omits video thumbs
- Warnings for extensions unlikely to play in-browser
- Background video dialog patch re-binds if the plugin appears late

### Unchanged (explicitly preserved)

- AList MediaDialog tab, onlyImages coverage, upload, srcset/lazy
- Body `o_alist_cdn_video`, section background video frontend path
- Infinite scroll +「加载更多…」, default `page_size` 60 for **new** sources
- Icon toolbar replace scoping; no product `media_picker` integration

## Upgrade impact

| Item | Impact |
|------|--------|
| Schema | New `fail_count` (and related) — standard module update |
| Config | Optional `ir.config_parameter` tuning; defaults are safe |
| Editors | No training change required; poster appears when naming convention matches |

## Verification

See [DEPLOY.md](./DEPLOY.md) post-deploy checklist.

## Artifacts

- `website_alist_media-19.0.4.2.0.zip`
- `deploy_website_alist_media.sh` (`MIN_VERSION=19.0.4.2.0`)

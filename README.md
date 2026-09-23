# website_alist_media

**Odoo 19 · Website MediaDialog · AList / S3 · CDN URLs (no filestore)**

| Field | Value |
|------|--------|
| **Latest release** | [`v19.0.4.2.0`](https://github.com/simplemind121/website_alist_media/releases/tag/v19.0.4.2.0) |
| **Module name** | `website_alist_media` |
| **Odoo** | 19 Community / Enterprise (website builder) |
| **License (module)** | LGPL-3 (see package `__manifest__.py`) |
| **Repository** | Private deploy artifacts + release notes |

中文详情：[README.zh-CN.md](./README.zh-CN.md) · Pin file: [`VERSION`](./VERSION) · Full history: [`CHANGELOG.md`](./CHANGELOG.md) · Deploy runbook: [`docs/DEPLOY.md`](./docs/DEPLOY.md) · Security: [`SECURITY.md`](./SECURITY.md)

---

## Overview

`website_alist_media` extends Odoo 19’s **native MediaDialog** with an **AList** tab (optional S3-compatible sources). Editors insert **permanent CDN public URLs** into website HTML. Binaries are **not** stored in the Odoo filestore.

**Not** the product-page module `media_picker`. Do not dual-install conflicting forks of the same technical name.

### Goals

- One MediaDialog experience for website content (images + CDN video)
- Server-side secrets; browser never receives AList/S3 credentials
- Predictable upgrades on the `19.0.4.x` line

### Non-goals

- Product form / `product.image` / shop gallery (`media_picker`)
- Social Icons-only dialogs
- Replacing Odoo’s entire asset pipeline

---

## What’s in this repository

| Artifact | Purpose |
|----------|---------|
| `website_alist_media-<version>.zip` | Installable module archive (**prefer versioned name**) |
| `website_alist_media.zip` | Alias of the **current** zip only |
| `deploy_website_alist_media.sh` | Idempotent install/upgrade for Docker VPS layouts |
| `VERSION` | Single-line current recommended version |
| `CHANGELOG.md` | User-facing change history |
| `docs/` | Deploy & ops notes |

Historical zips may remain for rollback. **Canonical current version = `VERSION` + latest GitHub Release.**

---

## Feature matrix (current: 19.0.4.2.0)

| Area | Status |
|------|--------|
| MediaDialog AList tab | Supported |
| onlyImages paths (gallery Add, cover, replace) | Supported |
| Body CDN `<video class="o_alist_cdn_video">` | Supported |
| Section background video (AList + frontend play) | Supported |
| Upload from dialog | Supported |
| srcset / lazy / intrinsic size | Supported |
| Link inventory + daily health cron | Supported (hardened in 4.2.0) |
| Toolbar icon replace (scoped) | Supported |
| Infinite scroll + “加载更多…” | Supported (since 4.1.1) |
| Auto `poster` / grid thumb fallback | Supported (4.2.0) |
| Unplayable format warnings | Supported (4.2.0) |

---

## Quick start

```bash
# 1) Download Release assets (or clone this repo)
#    website_alist_media-19.0.4.2.0.zip
#    deploy_website_alist_media.sh

# 2) Same directory on the VPS
chmod +x deploy_website_alist_media.sh
sudo ./deploy_website_alist_media.sh
# optional: sudo ./deploy_website_alist_media.sh --target staging

# 3) Hard-refresh browser (Ctrl+Shift+R)
# 4) Verify: __websiteAlistMedia.version === "19.0.4.2.0"
```

Full procedure, rollback, and checks: **[docs/DEPLOY.md](./docs/DEPLOY.md)**.

---

## Release 19.0.4.2.0 (summary)

Stability release on top of **19.0.4.1.1**. No intentional feature removal.

1. **Link checker hardening** — time budgets, clamped settings, `fail_count` / jitter suppression, batch writes, HTTP session reuse  
2. **Video UX** — same-name poster matching; grid thumb fallback; unplayable extension hints  
3. **Background video patch** — re-apply if plugin registers late  

Prior: **19.0.4.1.1** = infinite scroll + default `page_size` 60 for new sources.

---

## Versioning policy

Odoo-style five-segment versions: `19.0.<minor>.<patch>.<hotfix>` within series **19.0.4.x**.

| Change type | Example bump | Rule |
|-------------|--------------|------|
| Breaking / parallel product line | `19.0.5.0.0` | Avoid while 4.x is marked stable |
| Compatible feature set | `19.0.4.2.0` | Additive; `-u` upgrade |
| UX / small fix | `19.0.4.1.1` | Patch only |

**Upgrade:** always `-u website_alist_media` via the deploy script. Do not unpack two trees as the same module name.

**Runtime check:** `__websiteAlistMedia.version` must match `__manifest__.py` / Release tag.

---

## Compatibility

| Component | Expectation |
|-----------|-------------|
| Odoo | 19.0 website + html_editor / html_builder |
| Coexistence | Compatible with `media_picker` when that module owns product images only |
| Dual install | **Impossible** — same technical name `website_alist_media` |

---

## Security

- Tokens / secret keys stay server-side; JSON controllers return list/CDN URLs only  
- Trusted domain / SSRF controls apply when resolving remote URLs  
- Report issues privately — see [`SECURITY.md`](./SECURITY.md)

---

## Support & ownership

| Role | Notes |
|------|--------|
| Deploy target | Private VPS (`prod-odoo` / DB layout as in deploy script) |
| Source of truth | This private GitHub repo + GitHub **Releases** |
| Do not mix | Claude-only / Grok-only historical zips without reading CHANGELOG |

---

## License

Module license: **LGPL-3** (declared in the Odoo manifest inside the zip). Repository packaging scripts are provided as-is for private ops use.

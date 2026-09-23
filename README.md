# website_alist_media (Odoo 19)

Private deploy package for native MediaDialog **AList** tab (CDN URLs, no filestore).

**Current:** `19.0.4.1.1` (Claude+Grok merge `19.0.4.1.0` + infinite scroll / default `page_size` 60).

Not the product-page `media_picker` module — keep them separate.

## Deploy files

| File | Purpose |
|------|---------|
| `website_alist_media-19.0.4.1.1.zip` | Module zip (also `website_alist_media.zip`) |
| `deploy_website_alist_media.sh` | One-click install/upgrade (v5.1, `MIN_VERSION=19.0.4.1.1`) |

Older: `website_alist_media-19.0.3.0.1.zip` (pre-merge grok line).

## Deploy (VPS)

Put the zip and script in the same directory (e.g. `$HOME`), then:

```bash
chmod +x deploy_website_alist_media.sh
sudo ./deploy_website_alist_media.sh
# optional: --target staging
```

After deploy: hard-refresh (**Ctrl+Shift+R**). Console: `__websiteAlistMedia.version === "19.0.4.1.1"`.

## Highlights (19.0.4.1.x)

- AList / S3 sources in MediaDialog; CDN rewrite; secrets server-side
- onlyImages paths (gallery Add, cover, replace media)
- Body CDN video (`o_alist_cdn_video`) + section background video AList + frontend play
- Upload, srcset/lazy, link health cron, toolbar icon replace (Claude line)
- AList grid: infinite scroll near bottom +「加载更多…」fallback; new sources default page_size 60

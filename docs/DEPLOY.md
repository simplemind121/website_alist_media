# Deploy runbook — website_alist_media

## Prerequisites

- Docker-based Odoo 19 (`prod-odoo` or staging equivalent)
- Addons directory mounted and writable by the deploy user (script uses `sudo`)
- Package + script in the **same directory**
- Network access from Odoo to AList / S3 endpoints

## Install or upgrade

```bash
chmod +x deploy_website_alist_media.sh
sudo ./deploy_website_alist_media.sh
```

Optional:

```bash
sudo ./deploy_website_alist_media.sh --target staging
sudo ./deploy_website_alist_media.sh --rollback   # if script supports prior backup
```

The script:

1. Locates `website_alist_media*.zip`
2. Verifies package version ≥ `MIN_VERSION`
3. Installs/upgrades the module (`-i` / `-u`)
4. Restarts the container when configured to do so

## Post-deploy checklist

1. Hard refresh website editor assets (**Ctrl+Shift+R**)
2. Apps → `website_alist_media` version = **19.0.4.3.2**
3. Browser console: `__websiteAlistMedia.version === "19.0.4.3.2"`
4. Smoke:
   - MediaDialog → AList tab on image replace
   - Gallery **Add** (onlyImages) still shows AList
   - Body insert CDN mp4 → `<video class="o_alist_cdn_video">`
   - Section background video → AList + frontend play
   - Infinite scroll near bottom of large AList folders
   - Upload a file whose name already exists in the folder → saved as `name-1.ext`, original untouched

## Rollback

1. Keep previous versioned zip (`website_alist_media-19.0.4.3.1.zip`)
2. Replace current zip / re-run deploy against the older archive **or** use script `--rollback` when a backup was taken
3. Re-run smoke checklist on the rolled-back version

## Configuration notes

- **Existing** media sources keep stored `page_size`; **new** sources default to 60 (clamp 1–200)
- Link checker budgets / fail threshold: `ir.config_parameter` keys prefixed `website_alist_media.` (see CHANGELOG 19.0.4.3.1)

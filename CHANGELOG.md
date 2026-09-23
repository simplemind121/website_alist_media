# Changelog — website_alist_media

## 19.0.4.1.1 (2026-09-23) — UX patch / 体验小补丁

### ZH
- **无限滚动**：AList MediaDialog 网格（`.o_alist_media_grid`）滚近底部约 160px 时自动调用现有 `loadMore()`；`loading` 中不重入，`items.length >= total` 时停止。保留「加载更多…」次要按钮作键盘/触控回退。
- **默认 page_size**：新建媒体源 Integer 默认值 30 → **60**（服务端仍钳制 1–200）。**已有源保留库里存的 page_size**，不受影响。

### EN
- **Infinite scroll** on the AList MediaDialog grid: near-bottom (~160px) auto-calls existing `loadMore()`; guarded while `loading` and when all items are loaded. Secondary「加载更多…」button kept as fallback.
- **Default page_size** for new media sources: 30 → **60** (server clamp 1–200). Existing sources keep their stored `page_size`.

## 19.0.4.1.0 (2026-09-23) — 合并版 / merge release

两条 19.0.3.x 开发线合并为一个模块：
- **A 线（19.0.3.0.x）**：正文 AList 视频、区块背景视频、前台直链 `<video>` 播放；有浏览器实测（72 个 snippet 替换矩阵 69 通过、B1/BG1 通过）。
- **B 线（19.0.4.0.0）**：上传、索引搜索、缩略图/srcset、懒加载与尺寸、记住目录、链接健康巡检、env 密钥优先、兼容性守卫、Small/Medium/JS 测试。

### 保留原样（已实测代码，逐字移植）
- `static/src/utils/bg_video_utils.js`
- `static/src/builder/background_video_dialog_patch.js`
- `static/src/interactions/background_video_direct_patch.js`
- `static/src/xml/background_video_direct.xml`
- 视频相关 SCSS（拆到 `scss/alist_video.scss`，前台只加载这几条规则）
- `isAListVideoMedia`、`sanitizeAListVideoElements`、正文 `<video>` 元素构造（`o_alist_cdn_video`，不用 `media_iframe_video`）
- `tests/test_bg_video_utils.py`

### 以 B 线为准的部分
- 「仅图片」入口：采用 B 线补丁（先调用原生 `addTabs()` 再追加 AList；排除二进制图片字段；支持图库多选、图标替换）。A 线 `media_dialog_only_images_patch.js` 的 addTabs 覆盖写法不再使用；其 `renderMedia` 视频清理保留。
- 选择器：B 线为底，并入 A 线的 `videosOnly`（背景视频只列视频）、类型不符提示、Enter 搜索。

### 本版修复 / 加固
- **修 A 线 bug**：AList `/api/fs/list` 的 `type` 是整数，3.0.1 对它调用 `.split()`，文件夹里有 .txt 等非媒体文件时列表会报错。现同时支持整数 type 与 MIME 字符串。
- **修 B 线回归**：B 线正文视频用 `media_iframe_video` 类，会被网站视频组件当成 YT/Vimeo 重建 iframe；改回 A 线已验证的 `o_alist_cdn_video`。B 线没有背景视频与前台播放补丁，已补回（否则已有背景视频的页面会失效）。
- **安全**：`token` / `s3_secret_key` / `secret_ref` 加字段级 `groups`，网站设计者无法再通过 ORM 读取；仅 AList 源管理员与系统管理员可见。
- 默认视频扩展改为浏览器可播格式：`.mp4,.webm,.mov,.m4v,.ogv,.ogg`（去掉 .mkv/.avi；仍可在源里手动加回）。**已存在的源记录保留原值，需要的话手动改。**
- 编辑器 normalize / 保存前再次清理 AList `<video>` 上的图片类（针对「替换」流程把旧 `<img>` 的类带过来的情况；幂等，未知钩子名会被忽略）。
- JS 测试直接测试随包发布的真实 JS（`tests/js/video.test.mjs`）。

## 19.0.4.0.0（B 线）
上传到 AList/S3、AList 索引搜索（失败自动回退当前目录）、缩略图/缩放 URL 模板（可选 srcset）、插入时 lazy + 固有尺寸、记住上次目录、URL 引用索引 + 每日链接巡检 cron、env 密钥优先、兼容性守卫、非阻塞加载与重试、熔断与列表缓存。

---

以下为 A 线（19.0.3.0.x）原始记录，原样保留：

## 19.0.3.0.1 (2026-09-22)

### EN — What changed
- **Body video fix:** `AListSelector.createElements` detects video via `media_type` **or** extension (mp4/webm/ogg/mov/…) so `demo.mp4` always becomes `<video controls playsinline class="o_alist_cdn_video">`, not `<img>`.
- **MediaDialog save path:** `renderMedia` patch strips forced `img` / `o_we_custom_image` / `media_iframe_video` classes from AList CDN videos (stock always merges tab `mediaSpecificClasses`).
- **list/resolve typing:** `.ogg`/`.ogv` in default video extensions; AList `type`/`content_type` MIME used as fallback for `guess_media_type`.
- BG video path unchanged (still PASS).

### 中文 — 改了什么
- **正文视频：** 按 `media_type` 或扩展名识别，插入 `<video controls playsinline class="o_alist_cdn_video">`，不再变成 `<img>`。
- **保存路径：** 去掉 renderMedia 强加在 video 上的图片 class。
- **列表/解析：** 默认视频扩展含 ogg/ogv；可用 AList MIME 回退分类。
- 背景视频路径未改。

## 19.0.3.0.0 (2026-09-22)

### EN — What changed
- **V1 Body/block video:** AList MediaDialog (non-`onlyImages`) can list/select video files and insert `<video controls playsinline src=CDN class="o_alist_cdn_video">`. Avoids `media_iframe_video` so website MediaVideo does not try to rebuild a YT/Vimeo iframe.
- **V2 Section background video (module-only patches, no Odoo core edits):**
  1. Patch `WebsiteBackgroundVideoPlugin.loadReplaceBackgroundVideo` so **AList** appears beside **VIDEO_BACKGROUND** (`extraTabs` + `visibleTabs` merge).
  2. Save path uses `extractBackgroundVideoSrc` — AList CDN mp4/webm URL returned (not only `iframe.src`).
  3. Patch `BackgroundVideo.appendBgVideo` — direct media URLs render `<video autoplay muted loop playsinline>`; YouTube/Vimeo keep iframe.
- Unit tests: `tests/test_bg_video_utils.py` (URL detect, extract, tab merge, videosOnly filter).
- Does **not** edit Odoo core, Social Icons, `product.template.image_1920`, or product CustomMediaDialog (media_picker owns product gallery).

### 中文 — 改了什么
- **正文视频：** 非 onlyImages 的「选择媒体」AList 可选视频，插入 `<video controls playsinline src=CDN>`；不再用 `media_iframe_video` 类，避免被当成嵌入视频重建 iframe。
- **区块背景视频（仅模块补丁，不改 Odoo 核心）：**
  1. 打开背景视频 MediaDialog 时 **AList** 与 Videos 并列。
  2. 保存时从 AList 的 CDN mp4/webm 取 URL（不依赖 iframe.src）。
  3. 前端直链用 `<video autoplay muted loop playsinline>` 播放；YT/Vimeo 仍走 iframe。
- **不改** Odoo 核心、社交 Icons、商品主图、商品 CustomMediaDialog。

### How BG video save / play works
1. Editor: Toggle/Replace BG Video → MediaDialog opens with tabs `VIDEO_BACKGROUND` + `ALIST` (videosOnly).
2. Save: `loadReplaceBackgroundVideo` resolves to a URL string → `applyReplaceBackgroundVideo` sets `o_background_video` + `data-bg-video-src`.
3. Frontend/edit iframe: `BackgroundVideo` interaction reads `data-bg-video-src`; if URL looks like direct media (mp4/webm/…) render `website_alist_media.background.video.direct` (`<video>`); else stock `website.background.video` iframe + autoplay helpers.

### Upgrade
```bash
# After overlaying addons:
odoo -u website_alist_media -d <db> --stop-after-init
# or docker:
docker exec <odoo> odoo -u website_alist_media -d <db> --db_host=... --stop-after-init
docker restart <odoo>
# Hard-refresh browser assets (Ctrl+Shift+R)
```

### Browser QA checklist (known gaps)
- **Body:** Insert media → AList → pick mp4 → `<video controls playsinline src=CDN>` in editable; publish & play.
- **BG1:** Section → Background → Video → MediaDialog shows **Videos** + **AList**.
- **BG2:** AList pick CDN mp4 → section has `o_background_video` + `data-bg-video-src` = CDN URL (no youtube host).
- **BG3:** Frontend shows `<video autoplay muted loop playsinline>` inside `.o_bg_video_container` (not iframe).
- **BG4:** Stock Videos tab / Vimeo sample still sets iframe embed; YT/Vimeo still play.
- **BG5:** Replace BG video AList→Vimeo and Vimeo→AList both work; Remove clears class/dataset.

## 19.0.2.1.0 (2026-09-22)

### EN — What changed
- **Registration hardening (Work package A):** Split backend vs website entry files.
  - Website builder registers only via `website-plugins` (with `contains` guard → no `DuplicatedKeyError` on dual bundle load).
  - Backend HTML fields still get the plugin via guarded `MAIN_PLUGINS.push`.
  - Plugin class (`alist_media_plugin.js`) has **no** top-level side effects.
- **onlyImages / gallery Add (Work package B):** New `media_dialog_only_images_patch.js` patches `MediaDialog.addTabs` so when `onlyImages` is true the dialog still adds the Images tab **and** image-friendly `extraTabs` (at least `ALIST`), then returns (still skips Documents/Icons/Videos). Non-onlyImages keeps stock behavior via `super.addTabs()`.
- **AListSelector:** When the dialog passes `onlyImages`, list UI filters to dirs + images; selecting a non-image shows a warning.
- Does **not** edit Odoo core, social Icons, or `product.template.image_1920`.

### 中文 — 改了什么
- **注册收紧：** 后端 / 网站入口拆分；网站编辑器只走 `website-plugins`（已存在则跳过，避免重复注册报错）；后端 HTML 字段仍走 `MAIN_PLUGINS`。
- **onlyImages 补全：** 图库「添加图片」、cover/背景图等 `onlyImages: true` 弹窗也会出现 **AList**；仍不会塞进文档/图标/视频标签。
- **选择器：** onlyImages 时只显示目录与图片。
- **不改** Odoo 核心、社交 Icons、商品主图 `image_1920`。

### Upgrade
```bash
# 覆盖 addons 后：
odoo -u website_alist_media -d <db> --stop-after-init
# 或 docker：
docker exec <odoo> odoo -u website_alist_media -d <db> --db_host=... --no-http --stop-after-init
docker restart <odoo>
# 浏览器 Ctrl+Shift+R 强刷资产
```

## 19.0.2.0.0
- Scoped to website builder / HTML fields only; product media left to `media_picker`.

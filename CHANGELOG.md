# Changelog — website_alist_media

## 19.0.4.3.2 (2026-10-01) — 上传不再覆盖、使用索引补全、防止 token 填错

### 1. 上传同名文件不再覆盖原文件
**现象**：往已有 `banner.jpg` 的目录再传一张 `banner.jpg`，原文件被替换；所有引用旧地址的
页面悄悄换成新图，CDN 还可能继续显示旧图，前后不一致。
**原因**：AList `PUT /api/fs/put` 与 S3 `put_object` 默认都覆盖同名文件，模块上传前没有检查。
**修复**：上传前先查目标是否存在（AList `/api/fs/get`，S3 `head_object`），存在就依次尝试
`banner-1.jpg`、`banner-2.jpg`……（最多 50 个），并在弹窗里提示「已另存为 xxx」。
查询失败（例如没有权限）时**不上传**，宁可报错也不冒覆盖的风险。AList 上传请求另带
`Overwrite: false` 头，支持该头的版本在并发同名上传时也会拒绝覆盖。
「文件不存在」不计入熔断器（AList v3.58.0 实测返回 `code 500 / object not found`）。

### 2. 使用索引漏掉产品描述和封面图
**现象**：「这个文件还有没有地方在用」对产品页正文、博客封面里的 AList 图片回答「没有」，
照此去 AList 删文件会删掉正在用的图。实测环境中已有多个产品描述受影响。
**原因**：Odoo 19 的产品页正文字段是 `product.template.description_ecommerce`
（`website_description` 是旧名）；封面图存在 `cover_properties`（JSON 里的 `url(...)`），
两者都不在扫描列表里。
**修复**：扫描列表加入 `description_ecommerce`，以及 `blog.post` / `blog.blog` /
`event.event` / `slide.channel` 的 `cover_properties`（字段名均已对照 Odoo 19 源码核实）。
字段不存在时自动跳过。

### 3. 防止把 token 填进 Secret Reference
**现象**：浏览、插图都正常，但上传报 `403 permission denied`，Test Connection 却显示「连接成功」。
**原因**：「Secret Reference」应填环境变量的**名字**。填进 token 本身后，模块找不到这个
「变量」，于是不带 token 访问 AList——游客能读不能写。
**修复**：
- 保存时校验：Secret Reference 必须像环境变量名（字母、数字、下划线，不以数字开头），
  否则拒绝保存并说明该填哪里
- Test Connection：Secret Reference 指向的环境变量没设置时，结果里追加警告
  「请求将不带 token 发出，上传会失败」

### 4. 菜单路径文案
编辑器空状态提示、README、使用说明里的「网站 → 配置 → AList Media」改为实际位置
「网站 → AList 媒体」（Odoo 19 的 `website.menu_website_configuration` 就是网站应用根菜单）。

**测试**：小测试 92 → 110；数据库测试 21 → 30，0 失败（含产品描述、博客封面扫描、
上传改名、token 防呆、环境变量警告）；JS 测试全部通过；三个资源包编译通过；
zh_CN 新增 4 条翻译，Odoo PoFileReader 校验 213 条、占位符一致。

## 19.0.4.3.1 (2026-09-26) — 修复：图片在部分区块里被压扁/拉伸

**现象**：用 AList 图片替换后，在某些区块里图片被莫名压缩或拉伸；原生图片在同样位置正常。

**原因**（19.0.4.0.0 起引入）：插入 AList 图片时写入了原图的 `width` / `height` 属性。
浏览器把 `width` 属性当作 CSS 宽度，于是在**限制图片高度**的区块里，高度被压下去、
宽度却不跟着等比缩小，图片就变形了。原生图片没有这两个属性，会等比缩放。
Odoo 19 中受影响的区块包括：产品列表（最大高度 130px）、图库（三种布局）、团队、轮播。

**实测**（CSS 布局引擎，按浏览器处理 HTML 属性的规则模拟）：

| 区块 | 原生图片 | AList 旧版 | 修复后 |
|---|---|---|---|
| 产品列表 | 比例正确 | 变形 73% | 比例正确，与原生一致 |
| 团队 | 比例正确 | 变形 76% | 比例正确，与原生一致 |
| 图库类 | 比例正确 | 变形 12% | 比例正确，与原生一致 |
| 普通区块 | 比例正确 | 比例正确 | 不受影响 |
| 用户自设宽度 50% | — | — | 仍然生效 |

**修复**
1. 新插入的图片不再写 `width` / `height`，与原生图片完全一致（同时省掉了插入时最多 3 秒的尺寸探测）
2. **已经插入的图片无需重新替换**：新增一条零优先级样式
   `:where(img.o_alist_external, img[data-alist-external]) { width: auto; height: auto; }`。
   `:where()` 的优先级为 0，任何区块、主题或你自己设的样式都比它优先；它只抵消 HTML 属性对尺寸的影响，
   不修改数据库内容。前台与后台资源包均已包含，已在真实 Odoo 中编译验证。
3. 新增回归测试，防止再次写入尺寸属性


## 19.0.4.3.0 (2026-09-25) — 显示区域工具（焦点定位）

**问题**：同一张图放进不同尺寸的区块，显示区域会跑偏。Odoo 原生的裁剪、滤镜、格式工具
对外链图片（跨域）会直接隐藏——裁剪要把图画进 canvas，跨域图画进去就读不出来，这是
浏览器安全限制，绕不过去。

**做法**：不裁图，只控制显示区域（与 Cloudinary、WordPress 焦点插件等同一思路）。
选中 AList 插入的图片后，网站编辑器右侧栏多出「显示区域」选项：

- **画框比例**：Auto / 16:9 / 4:3 / 1:1 / 3:4。选比例会同时设为「铺满」，保证是裁切而不是拉伸
- **填充**：铺满（cover）/ 完整显示（contain）
- **焦点**：九宫格快速定位，再用水平、垂直两个滑块精调
- **还原**：只移除本工具写入的 3 项样式，原生「尺寸」等其他设置不受影响

**稳定性设计**
- 只作用于本模块插入的图片（`data-alist-external` 或新增的 `o_alist_external` 类），
  原生图片、Unsplash 图片完全不受影响
- 纯内联 CSS（`aspect-ratio`、`object-fit`、`object-position`），不改文件、不走服务器、
  不碰 canvas，随时可还原；撤销/重做走编辑器原生历史
- 使用 Odoo 19 **官方**侧栏选项接口（`builder_options` / `builder_actions`），
  不 patch 任何私有方法
- **类标记防清洗**：Odoo 的 HTML 清洗只保留白名单内的 `data-*` 属性，`data-alist-external`
  在清洗型 HTML 字段里保存后可能被剥掉；新增的类标记始终保留
- **不改变原生替换行为**：用原生图片或 Unsplash 替换时，结果与 Odoo 原生完全一致。
  （开发中曾把这三项样式声明为 AList 专属，全 block 测试发现这会让原生替换也剥掉它们——
  `theme_treehouse` 和招聘模块的图片自带内联 `object-fit: cover`，会因此失去填充效果。
  已改为用 `o_alist_framed` 类记录"被本工具调过"，不再剥离任何样式。）
- **不留孤儿样式**：AList 图换 AList 图，画框保留；换成原生图，按 Odoo 原生行为样式随之保留，
  而工具也随 `o_alist_framed` 类一起保留，随时可以继续调整或还原
- 部署脚本新增 5 个兼容性锚点，监控本功能依赖的官方接口，Odoo 升级后若接口变化会提前告警

**界面中文化**
- 新增 `i18n/zh_CN.po`：191 条界面文字全部翻译（字段、菜单、选项、侧栏、媒体弹窗、提示信息），
  由真实 Odoo 导出词条，占位符全部校验一致，已在中文库中验证后台与编辑器均正确显示中文
- 去掉两处写死的中文（「浏览器可能无法播放」「加载更多…」），统一改为可翻译文字，
  不再中英混杂；英文界面也能正常显示
- 画框比例一行 5 个按钮改为紧凑样式，适配侧栏宽度

**真实数据库测试发现并修复的两个问题**（之前所有离线测试都没抓到）
1. **设计师打开媒体源会报错**（4.1.x 合并引入）：「凭据存储方式」字段计算时要读 Token，
   而字段级权限禁止设计师读 Token，于是抛 AccessError。改为以 sudo 计算——设计师能看到
   存储方式（env / database / none），但仍然读不到 Token 本身（已在真实权限系统验证）。
2. **链接巡检的失败抑制过于宽泛**（4.2.0 引入）：原先所有失败都要连续两次才标记，
   连 404（文件确实没了）和域名不在白名单（配置问题）也要等。现在只对**可能自愈**的
   失败做抑制：网络错误/超时、429、5xx；404/410 等 4xx 和白名单拦截**第一次就标记**。
   同时修正了测试里过时的 mock（4.2.0 改用连接复用后，旧测试 mock 的已不是实际调用路径）。

**测试**
- 焦点解析 19 项、动作行为 16 项、替换继承 5 项，均为离线测试
- **真实数据库测试**（PostgreSQL 16 + Odoo 19.0，与生产相同的 42 个模块）：
  - 全新安装 + 模块测试：21 项全部通过
  - 从 19.0.4.1.1 带数据升级：新列正确添加（旧行填 0 而非 NULL）、链接状态/媒体源/
    Token/定时任务全部保留，升级后 21 项测试通过
  - 资源包编译：后台、网站编辑器、前台三个 bundle 编译成功，本模块样式全部进入产物
  - JS 依赖解析：34 个 import 全部指向 Odoo 19 真实存在且确实导出的名称
  - 卸载：无残留数据表、模型、视图、菜单、定时任务；卸载后站点正常启动
- **全 block 替换回归**（`tests/block_harness/`）：对 Odoo 19 官方 190 个含媒体的模板、
  3510 个媒体元素逐一重放替换逻辑，覆盖 website 基础 block、全部官方主题、
  商城/博客/活动等 11 个 website 应用，零问题


## 19.0.4.2.0 (2026-09-23) — 稳定性版本 / stability release

功能已定型，本版只做增稳，不加新功能。

### 1. 链接巡检不再可能拖垮生产（最重要）
- **时间预算**：扫描阶段与检查阶段各有独立的时间预算（默认各 120 秒）。超时即停，
  未检查的链接排在下次优先检查（按 `last_checked` 轮转），不会无限期占用 cron。
- **参数可调且带硬上限**：通过 `ir.config_parameter` 配置，任何值都会被钳制到安全区间，
  配错也不会让 cron 跑飞：

  | 参数（前缀 `website_alist_media.`） | 默认 | 范围 | 作用 |
  |---|---|---|---|
  | `check_batch` | 200 | 1–2000 | 单次检查的链接数 |
  | `check_timeout` | 5 | 1–30 | 单个 HTTP 请求超时（秒） |
  | `check_time_budget` | 120 | 5–1800 | 检查阶段总时长（秒） |
  | `scan_time_budget` | 120 | 5–1800 | 扫描阶段总时长（秒） |
  | `fail_threshold` | 2 | 1–10 | 连续失败多少次才判定为失效 |

- **失败抖动抑制**：CDN 偶发抖动不再把链接直接标成失效。失败次数累计到阈值才标记，
  期间保留原状态并在 `last_message` 显示「failure 1/2」；一次成功立即清零。
  新增只读字段 `fail_count`。
- **批量写入**：原先每个 URL 一次 `create` + 一次 `ref_count` 写入，站点大时是数千次往返；
  现在链接创建、引用创建、计数更新各自合并为批量操作。
- **连接复用**：检查阶段使用单个 `requests.Session`，不再为每条链接新建连接。

### 2. 视频体验
- **自动封面**：插入视频时，自动在同目录寻找同名图片作为 `poster`
  （`demo.mp4` → `demo.jpg`，或 `demo-poster.png`）。找不到就没有封面，绝不猜测无关图片，
  解析失败也不会影响插入。
- （`preload="metadata"` 在 4.1.1 已具备，本版未改。）

### 3. 视频网格缩略图（同名封面图回退）
AList 对 S3/B2 这类驱动不返回视频缩略图（缩略图由各存储驱动自行实现，网盘类驱动才有），
所以视频在网格里只有一个胶片图标。现在：若同目录存在同名图片（`demo.mp4` → `demo.jpg`
或 `demo-poster.png`），网格直接用它作缩略图，并在右下角加一个播放角标以示区分。
不产生任何额外请求（该图片本来就在列表里），AList 自带的 `thumb` 仍然优先。

配套做法：本地用 ffmpeg 生成封面后与视频一起上传即可，例如
`ffmpeg -i demo.mp4 -vf "thumbnail,scale=640:-1" -frames:v 1 demo.jpg`。
同一张图同时作为网格缩略图和插入后的 `<video poster>`。

### 4. 不可播放格式提示
`.mkv/.avi/.wmv/.flv/.rmvb/.rm/.3gp/.mpg/.mpeg/.ts` 这类浏览器无法原生播放的容器，
在列表里显示「浏览器可能无法播放」角标，选中时再提示一次。仍允许插入（源可能已转码），
但不再是插完才发现播不了。

### 5. 背景视频补丁不再依赖资源加载顺序
原先在模块求值时直接从 registry 取官方插件类，取不到就只打一条 console.warn 后静默跳过。
现在：取得到就立即打补丁；取不到则监听 registry 的 `UPDATE` 事件，等官方插件注册后再打。
状态写入 `__websiteAlistMedia.bgVideoPatch`（`true` / `"pending"`），测试时可直接查看。

### 测试
- Python small：46（新增 7 条覆盖钳制、时间预算、失败抑制）
- JS：新增 4 条加载顺序模拟 + 封面匹配与不可播放格式断言
- 全部离线可跑：`bash tests/js/run.sh`、`python3 -m unittest tests.test_small`


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

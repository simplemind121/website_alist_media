# website_alist_media（Odoo 19）

| | |
|---|---|
| **当前版本** | **`19.0.4.2.0`** |
| **Release** | [v19.0.4.2.0](https://github.com/simplemind121/website_alist_media/releases/tag/v19.0.4.2.0) |
| **模块技术名** | `website_alist_media` |
| **定位** | 网站编辑器原生 MediaDialog 增加 **AList** 页；插入 **CDN 直链**，不进 Odoo filestore |

> 与商品页 `media_picker` **不是同一模块**，不要混装、混版本。

根目录 [`VERSION`](./VERSION) = 当前推荐部署版本。完整变更见 [`CHANGELOG.md`](./CHANGELOG.md)。

---

## 这是什么

在 Odoo 19 网站编辑器的「选择媒体」对话框里增加 **AList**（也可配 S3 兼容源）页签：

- 选中的图/视频写入页面的是 **CDN 永久 URL**（例如 `media.xxx`），**不进 filestore**
- 密钥只存在服务端；浏览器只拿列表与改写后的公开地址
- 覆盖：正文插图/换图、图库 Add、封面、正文 CDN 视频、区块背景视频等

---

## 推荐下载（当前）

| 文件 | 用途 |
|------|------|
| [`website_alist_media-19.0.4.2.0.zip`](./website_alist_media-19.0.4.2.0.zip) | **请用带版本号的包** |
| [`deploy_website_alist_media.sh`](./deploy_website_alist_media.sh) | 一键安装/升级（v5.2，`MIN_VERSION=19.0.4.2.0`） |

也可在 **Releases** 页下载同一组附件：  
https://github.com/simplemind121/website_alist_media/releases/tag/v19.0.4.2.0

`website_alist_media.zip` 是当前版本别名（内容与带号 zip 相同）。**看版本请认带号文件名、`VERSION` 或 Release 标签。**

---

## 部署

把 **带版本号的 zip** 与脚本放同一目录（例如家目录）：

```bash
chmod +x deploy_website_alist_media.sh
sudo ./deploy_website_alist_media.sh
# 预发示例：
# sudo ./deploy_website_alist_media.sh --target staging
```

部署后前台 **Ctrl+Shift+R**（或 Ctrl+Shift+R）。

验收：

- 应用版本 / `ir.module.module` ≈ **19.0.4.2.0**
- Console：`__websiteAlistMedia.version === "19.0.4.2.0"`

---

## 19.0.4.2.0 相对上一版（19.0.4.1.1）多了什么

在 **不砍功能** 的前提下做稳定性与视频体验增补：

1. **链接巡检增稳（最重要）**  
   扫描/检查各有时间预算；参数可配且有硬上限；连续失败达阈值才标失效（`fail_count`）；批量写库；HTTP Session 复用。避免大站 cron 拖垮生产。

2. **视频体验**  
   - 插入 mp4 时自动匹配同名图作 `poster`（`demo.mp4` ↔ `demo.jpg` / `demo-poster.png`）  
   - 网格无缩略图时用同名图回退，并加播放角标  
   - 对 mkv/avi 等浏览器难播格式给提示  

3. **背景视频补丁**  
   插件若晚注册，会再补丁一次，降低「AList 背景视频页签静默丢失」风险。

4. **上一版已有、本版保留**  
   无限滚动 +「加载更多…」、新建源默认 `page_size=60`、正文 `o_alist_cdn_video`、背景视频四件套、上传 / srcset / Icon 替换等。

---

## 版本历史（仓库归档）

| 版本 | 包文件 | 说明 |
|------|--------|------|
| **19.0.4.2.0（当前）** | `website_alist_media-19.0.4.2.0.zip` | 巡检增稳 + poster/网格封面 + BG 晚注册 |
| 19.0.4.1.1 | `website_alist_media-19.0.4.1.1.zip` | 无限滚动 + 默认 page_size 60 |
| 19.0.4.1.0 | （见 CHANGELOG / 合并线） | Claude 干 + Grok 视频子系统合并 |
| 19.0.3.0.1 | `website_alist_media-19.0.3.0.1.zip` | 早期 grok 线（归档） |

正式以右侧 **Releases** 带 `v` 的 tag 为准。

---

## 功能清单（当前主线）

- MediaDialog **AList** 页签（AList / S3）；CDN 改写；密钥服务端  
- onlyImages 路径（图库 Add、封面、替换媒体等）  
- 正文 CDN `<video class="o_alist_cdn_video">`（不用易冲突的 iframe 视频类）  
- 区块背景视频：对话框 AList + 前台直链 `<video>` 播放  
- 对话框上传、srcset/lazy、链接用量索引 + 日检 cron  
- 工具栏替换图标（评分/手风琴等入口仍排除）  
- AList 网格近底**无限滚动** +「加载更多…」兜底  

**明确不做 / 另模块：** 商品主图 `media_picker`、社交 Icons 专用对话框。

---

## 发版习惯（给维护者）

1. 升 `__manifest__` / `__websiteAlistMedia.version` / `VERSION` / `CHANGELOG` / README 表格  
2. 更新带号 zip + deploy 脚本 `MIN_VERSION`  
3. `git tag vX.Y.Z.A.B` + `gh release create`，附件放 zip + sh  

Private 仓库，需要已登录的 GitHub 账号才能拉。

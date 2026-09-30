# website_alist_media

**Odoo 19 · 网站 MediaDialog · AList / S3 · CDN 直链（不进 filestore）**

| 字段 | 值 |
|------|--------|
| **当前版本** | [`v19.0.4.3.2`](https://github.com/simplemind121/website_alist_media/releases/tag/v19.0.4.3.2) |
| **模块技术名** | `website_alist_media` |
| **适用** | Odoo 19（网站编辑器） |
| **模块许可** | LGPL-3（见包内 `__manifest__.py`） |

钉选文件：[`VERSION`](./VERSION) · 变更：[`CHANGELOG.md`](./CHANGELOG.md) · 部署：[`docs/DEPLOY.md`](./docs/DEPLOY.md) · 安全：[`SECURITY.md`](./SECURITY.md) · English：[README.md](./README.md)

---

## 概述

在 Odoo 19 **原生「选择媒体」对话框**中增加 **AList** 页（可选 S3 兼容源）。编辑插入的是 **CDN 永久公网 URL**，二进制 **不写入** Odoo 文件库。

密钥只留在服务端。与商品页模块 **`media_picker` 不是同一个东西**，禁止同技术名双装。

### 目标

- 网站内容统一走 MediaDialog + AList
- 浏览器不接触 AList / S3 密钥
- 在 `19.0.4.x` 线上可预期升级

### 非目标

- 商品主图 / `product.image` / 店铺图库（归 `media_picker`）
- 社交 Icons 专用对话框
- 替换整套 Odoo 静态资源体系

---

## 本仓库有什么

| 产物 | 用途 |
|------|------|
| `website_alist_media-<version>.zip` | 安装包（**优先用带版本号文件名**） |
| `website_alist_media.zip` | 仅指向**当前**版本的别名 |
| `deploy_website_alist_media.sh` | Docker VPS 一键安装/升级 |
| `VERSION` | 一行当前推荐版本 |
| `CHANGELOG.md` | 面向使用者的变更史 |
| `docs/` | 部署与发版说明 |

历史 zip 可留作回滚。**权威当前版本 = `VERSION` + 最新 GitHub Release。**

---

## 功能矩阵（当前 19.0.4.3.2）

| 能力 | 状态 |
|------|------|
| MediaDialog AList 页 | 支持 |
| onlyImages（图库 Add、封面、替换） | 支持 |
| 正文 CDN `<video class="o_alist_cdn_video">` | 支持 |
| 区块背景视频（AList + 前台播放） | 支持 |
| 对话框上传 | 支持 |
| srcset / lazy / 固有尺寸 | 支持 |
| 链接索引 + 日检 cron | 支持（4.2.0 加固） |
| 工具栏替换图标（有范围） | 支持 |
| 无限滚动 +「加载更多…」 | 支持（自 4.1.1） |
| 自动 poster / 网格封面回退 | 支持（4.2.0） |
| 难播格式提示 | 支持（4.2.0） |

---

## 快速开始

```bash
chmod +x deploy_website_alist_media.sh
sudo ./deploy_website_alist_media.sh
# sudo ./deploy_website_alist_media.sh --target staging
```

强刷编辑器资源后检查：`__websiteAlistMedia.version === "19.0.4.3.2"`。  
完整步骤与回滚见 **[docs/DEPLOY.md](./docs/DEPLOY.md)**。

---

## 版本 19.0.4.3.2 摘要

在 **19.0.4.3.1** 基础上的安全修复，不砍功能，`-u` 直接升级，无数据迁移：

1. **上传不再覆盖**：目录里已有 `a.jpg` 时自动另存为 `a-1.jpg` 并提示；无法确认是否重名时不上传
2. **使用索引补全**：扫描 Odoo 19 产品页正文（`description_ecommerce`）以及博客、活动、课程的封面图（`cover_properties`）
3. **防止 token 填错**：Secret Reference 填成 token 会拒绝保存；环境变量未设置时 Test Connection 给出警告
4. 菜单路径文案更正为「网站 → AList 媒体」

## 版本 19.0.4.3.1 摘要

修复 AList 图片在限制图片高度的区块（产品列表、图库、团队、轮播）里被压扁或拉伸：新插入的图片
不再带 `width`/`height` 属性；旧版本插入的图片由一条零优先级样式自动纠正，无需修改页面内容。

## 版本 19.0.4.3.0 摘要

网站编辑器侧栏新增 AList 图片的**显示区域**工具（画框比例、填充方式、焦点位置）。纯 CSS 实现，
不修改文件，重置只清除本工具设置的样式。原因是 Odoo 的裁剪工具不支持跨域图片。
同时修复网站设计师打开媒体源时的 AccessError。

## 版本 19.0.4.2.0 摘要

相对 **19.0.4.1.1** 的稳定性版本，**不砍功能**：

1. 链接巡检增稳（时间预算、参数钳制、失败抖动、`fail_count`、批量写、Session）
2. 视频体验（同名 poster、网格封面回退、难播提示）
3. 背景视频插件晚注册再补丁

上一版 **19.0.4.1.1**：无限滚动 + 新建源默认 `page_size` 60。

发版说明（中英结构）：[`docs/RELEASE_NOTES_19.0.4.2.0.md`](./docs/RELEASE_NOTES_19.0.4.2.0.md)

---

## 版本策略

五段式：`19.0.<minor>.<patch>.<hotfix>`，稳定线 **19.0.4.x**。

| 变更类型 | 示例 | 规则 |
|----------|------|------|
| 破坏性 / 新主线 | `19.0.5.0.0` | 4.x 标稳定期间避免 |
| 兼容增强 | `19.0.4.3.1` | 可 `-u` |
| 小修复 / UX | `19.0.4.1.1` | 仅 patch |

运行时 `__websiteAlistMedia.version` 必须与 manifest / Release tag 一致。

---

## 安全

见 [`SECURITY.md`](./SECURITY.md)。勿在 Issue 中粘贴密钥。

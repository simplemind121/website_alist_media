# website_alist_media (Odoo 19)

| | |
|---|---|
| **当前版本** | **`19.0.4.1.1`** |
| **Release** | [v19.0.4.1.1](https://github.com/simplemind121/website_alist_media/releases/tag/v19.0.4.1.1) |
| **模块技术名** | `website_alist_media` |
| **说明** | 网站编辑器原生 MediaDialog 增加 **AList** 页；插入 CDN 直链，不进 filestore |

> 与商品页 `media_picker` **不是同一个模块**，不要混装、混版本。

根目录 `VERSION` 文件内容即当前推荐部署版本。变更说明见 [`CHANGELOG.md`](./CHANGELOG.md)。

## 推荐下载（当前）

| 文件 | 用途 |
|------|------|
| [`website_alist_media-19.0.4.1.1.zip`](./website_alist_media-19.0.4.1.1.zip) | **请用带版本号的包** |
| [`deploy_website_alist_media.sh`](./deploy_website_alist_media.sh) | 一键安装/升级（v5.1，`MIN_VERSION=19.0.4.1.1`） |

`website_alist_media.zip` 是当前版本的别名（与 `…-19.0.4.1.1.zip` 相同），方便脚本；**看版本请认带号文件名或 Release 页**。

## 部署

把 **带版本号的 zip** 和脚本放同一目录后：

```bash
chmod +x deploy_website_alist_media.sh
sudo ./deploy_website_alist_media.sh
# 预发：sudo ./deploy_website_alist_media.sh --target staging
```

部署后前台 **Ctrl+Shift+R**。Console：`__websiteAlistMedia.version === "19.0.4.1.1"`。

## 版本历史（仓库内归档）

| 版本 | 包文件 | 备注 |
|------|--------|------|
| **19.0.4.1.1**（当前） | `website_alist_media-19.0.4.1.1.zip` | 无限滚动 + 新建源默认 page_size 60 |
| 19.0.4.1.0 | （合入合并线，见 Release / CHANGELOG） | Claude 干 + Grok 视频子系统 |
| 19.0.3.0.1 | `website_alist_media-19.0.3.0.1.zip` | 早期 grok 线（归档保留） |

正式发版请打开右侧 **Releases**，以带 `v` 的 tag 为准。

## 功能摘要（19.0.4.1.x）

- AList / S3 源、CDN 改写、密钥仅服务端
- onlyImages 路径（图库 Add、封面、替换媒体）
- 正文 CDN `<video class="o_alist_cdn_video">` + 区块背景视频 AList / 前台播放
- 上传、srcset/lazy、链接巡检 cron、工具栏替换图标
- AList 网格近底无限滚动 +「加载更多…」兜底

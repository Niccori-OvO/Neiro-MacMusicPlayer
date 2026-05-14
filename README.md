# Neiro 

> 一个 Mac 原生的本地音乐播放器。

<!-- 配图建议 ① 主界面整图，能看到 sidebar 分类 + 主内容 + 底部播放栏 -->
<p align="center">
  <img src="docs/screenshots/main.png" width="900" alt="Neiro 主界面"/>
</p>

---

## 这是什么

我是个高中生，平时听很多日系动漫音乐——BanG Dream!、MyGO!!!!!、Project SEKAI、宇多田光、ヨルシカ 这些。

Apple Music 读不了本地 FLAC，Swinsian / VOX 这些虽然功能全但样子太商业，写得像 macOS Tahoe Apple Music v11 风格的本地播放器一直没人做。索性自己写一个。

目标只有三个：**好看 · 好用 · 不烦人**。

---

## 能干什么

### 🎵 播放音乐

用 Apple 自家的 AVAudioEngine 跑，蓝牙耳机 / AirPods / USB DAC 都直接连，不会卡顿不会挑设备。

支持：

- **格式**：FLAC · ALAC · WAV · AIFF · M4A · MP3
- **播放控制**：上一首 / 下一首 / 暂停 / 拖动进度 / 长按快进 / `空格`暂停
- **队列**：双击任意一首歌，整张列表自动入队
- **随机播放**：按权重随机（喜爱的优先），同一首同一次播放只算一次
- **循环模式**：关 / 单曲循环 / 列表循环

### ✨ 自动识别二次元企划

把 47 个常听的乐队 / 艺人内置进去，扫描时按 artist / album / title 关键字自动分类：

| 分类 | 包含 |
|---|---|
| **乐队** | MyGO!!!!! · Ave Mujica · Roselia · Poppin'Party · 放课后茶会 · トゲナシトゲアリ … |
| **偶像企划** | μ's · Aqours · Liella! · 25時、ナイトコードで · Cinderella Girls … |
| **游戏 OST** | 原神 · 崩坏：星穹铁道 · 鸣潮 · 绝区零 · HoYo-MiX … |
| **VTuber** | Hololive · 彩虹社 |
| **VOCALOID** | 初音未来 · 镜音双子 · 巡音流歌 · DECO*27 · wowaka … |
| **歌手** | 宇多田光 · LiSA · Aimer · ヨルシカ · YOASOBI · ZUTOMAYO · Eve · Ado … |

侧边栏自动按分类分组显示，名字中英双语跟着应用语言切换。

<!-- 配图建议 ② Sidebar 分类展开，可见多个分组的列表 -->
<p align="center">
  <img src="docs/screenshots/sidebar.png" width="280" alt="侧边栏分类"/>
</p>

### 📝 歌词同步

把 `.lrc` 文件拖到右侧歌词面板，歌词就跟着播放进度滚动 + 高亮当前句。点任意一行可以跳到那个时间播放。

支持 `.lrc` / `.rtf` / 纯文本，编码自动识别（UTF-8 / GB18030）。第一次拖入会自动绑定到曲目，下次播放这首歌歌词自动出现。

<!-- 配图建议 ③ 右侧歌词面板，能看到当前行高亮 -->
<p align="center">
  <img src="docs/screenshots/lyrics.png" width="900" alt="歌词面板"/>
</p>

### 🎨 视觉

**三栏 Liquid Glass 浮岛布局**（参考 macOS Tahoe 上的 Apple Music v11），整体看起来像漂浮的玻璃。

- 6 套预设强调色（系统蓝 / 樱花粉 / 天空青 / 薄荷绿 / 丁香紫 / 夕橙）+ 自由 ColorPicker
- 跟随系统明暗 / 强制浅色 / 强制深色
- 中文 / English 实时切换
- 圆角强度 · 动画速度 都能微调

最有意思的是：**可以放一张你喜欢的角色立绘 PNG 作为列表背景**。透明度、大小都能调，顶部柔和淡出不刺眼。

<!-- 配图建议 ④ 设置面板「外观」Tab，能看到强调色选择 + 立绘预览 -->
<p align="center">
  <img src="docs/screenshots/appearance.png" width="700" alt="外观设置"/>
</p>

<!-- 配图建议 ⑤ 列表页带立绘背景的效果 -->
<p align="center">
  <img src="docs/screenshots/character.png" width="900" alt="立绘背景"/>
</p>

### 💗 喜爱 + 播放列表

点心形就喜爱：

- 喜爱**歌曲** → 自动进「喜爱歌曲」playlist
- 喜爱**专辑** → 整张专辑的曲目进「喜爱专辑」playlist
- 喜爱**作曲家** → 该作曲家所有曲目进「喜爱作曲家」playlist

也可以自建播放列表，点 sidebar 的 `+` 按钮命名，然后右键任意歌曲「添加到播放列表」。

### 🏠 Home 页

- 按时段问候你（早安 / 中午好 / 下午好 / 晚上好 / 夜深了）
- **每日推荐**：日期作种子的加权抽样，喜爱的曲目优先、很久没听的曲目优先、听爆的曲目降权。每天不一样，同一天打开多次一样
- 媒体库统计卡，点击直达对应页面

### 🔍 还有

- **全库搜索**：曲名 / 作曲家 / 专辑 一框搞定
- **导入时自动复制到 `~/Music/Neiro/`**：删源文件不影响播放
- **同名 `.lrc` 自动关联**：音频和歌词在同目录就自动绑定
- **全屏 Now Playing**：点底部封面进入，模糊封面背景 + 大字 + 大封面
- **右键菜单**：歌曲 / 专辑 / 作曲家 / 立绘 / playlist 全部都有完整右键
- **删除选项**：从媒体库移除时可以选保留源文件或一起删

---

## 开始用

### 系统要求
- macOS 14 (Sonoma) 或更新

### 下载
<!-- 等真发了再填这里 -->
[Releases 页面下载最新版本](#) ← 待填

### 或者自己编译
1. 装 Xcode 16+
2. 克隆这个仓库
3. 打开 `Neiro/Neiro.xcodeproj`，⌘R

### 第一次打开
1. 按 **⌘O** 打开导入窗口
2. 把音乐拖进去（文件或整个文件夹都行）
3. 扫描完成后侧边栏自动出现你的二次元企划分类
4. 双击任意一首歌开始听

### 常用快捷键

| 快捷键 | 干啥 |
|---|---|
| `⌘O` | 导入音乐 |
| `⌘,` | 设置 |
| `空格` | 播放 / 暂停 |
| 双击曲目 | 入队播放 |
| 点底部封面 | 全屏 Now Playing |
| 右键任意行 | 完整菜单 |

---

## 项目结构

```
Neiro/
├── Audio/
│   └── AudioEngine.swift          AVAudioEngine 播放 + 队列 + shuffle / repeat
├── Library/
│   ├── Models.swift               SwiftData 模型（Track / Album / Artist / Playlist）
│   ├── LibraryService.swift       扫描 / 导入 / 元数据 / 复制到 Neiro
│   ├── LibraryActions.swift       喜爱 / 移除 / recordPlay / 孤儿清理
│   ├── AnimeProjects.swift        47 个企划数据库 + 关键字匹配
│   └── PathProvider.swift         ~/Music/Neiro/ 等路径
└── UI/
    ├── RootView.swift             三栏浮岛布局
    ├── Sidebar.swift              分组导航
    ├── PlayerBar.swift            底部胶囊播放栏
    ├── NowPlayingView.swift       全屏播放页
    ├── LyricsPanel.swift          右侧歌词面板（解析 + 同步）
    ├── ImportView.swift           导入窗口
    ├── Theme.swift                配色 / 多语言 / Liquid Glass helper
    └── Pages/                     Home / Songs / Albums / Artists / Playlists / Search / Settings
```

技术栈：Swift 5.9 · SwiftUI · SwiftData · AVAudioEngine · AVFoundation

---

## 后面想做的

- 桌面悬浮迷你歌词（可贴屏幕边）
- 节日皮肤（樱花季 / 圣诞 / 万圣节自动换主题）
- 追番式听歌进度（"MyGO!!!!! 已收听 87%"）
- 角色台词随机播报（开机 / 切歌时一句台词）
- 参数 EQ（自定义频段 + ACG / 流行 / 人声预设）
- USB DAC 用户的 bit-perfect 专业模式

---

## 致谢

- 视觉灵感来自 Apple Music (macOS Tahoe) 和一些开源播放器
- 默默致敬所有让我反复循环的动画 / 游戏音乐人
- 项目仓库不包含任何角色立绘或音乐文件，请用自己的合法资源

---

## License

MIT — 自己拿去玩，记得开心就好。

---

<p align="center">
  <sub>by a high school student who listens to too much MyGO!!!!! 🎸</sub>
</p>

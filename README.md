# Neiro 

> 一个 Mac 原生的本地音乐播放器。

<img width="2714" height="1488" alt="image" src="https://github.com/user-attachments/assets/b8412de7-58b8-41cc-bf5b-95c11302c90b" />


---

## 这是什么

早在一年前吧我那时候懒得续我的Apple Music加上很多歌都没有或者就突然下架了，就比如deco27发了remix的monitoring，结果我听了没两天...啪！没有了下架了！还有25时的DNA也是（）
所以我就开始去很多网站找音源，甚至是买（正版的，比如iTunes上啊什么的），但是自从买了新的MacBook Pro为了上学带着，我听歌的大部分时间也从手机改到了电脑上。但是Mac端Apple Music怎么导入什么的很烦人，加上AM不支持自己放歌词什么的，加上我实在是无聊，所以----
    **我打算自己做一个**

目标嘛...能用就行，但是做着做着发现，似乎可以再好玩一点（？

---

## 能干什么

### 播放音乐

用 Apple 自家的 AVAudioEngine 跑音乐，支持蓝牙耳机 / AirPods / USB DAC 都直接连，不会卡顿不会挑设备。

支持：

- **格式**：FLAC · ALAC · WAV · AIFF · M4A · MP3
- **播放控制**：上一首 / 下一首 / 暂停 / 拖动进度 / 长按快进 / `空格`暂停
- **队列**：双击任意一首歌，整张列表自动入队
- **随机播放**：按权重随机（喜爱的优先），同一首同一次播放只算一次
- **循环模式**：关 / 单曲循环 / 列表循环

这些都是很平常的，直到我想到了一个还算好玩的功能
## **自动识别一些歌手和乐队企划企划**
###其实就是自动分类（

我把 47 个常听的乐队 / 艺人内置进去，扫描时按 artist / album / title 关键字自动分类：

| 包含 |
|---|---|
| **乐队** | MyGO!!!!! · Ave Mujica · Roselia · Poppin'Party · 放课后茶会 · トゲナシトゲアリ … |
| **偶像企划** | μ's · Aqours · Liella! · 25時、ナイトコードで · Cinderella Girls … |
| **游戏 OST** |HoYo-MiX（后续会加上MSR哦） |
| **VTuber** | Hololive · 彩虹社 |
| **VOCALOID** 虚拟歌姬与曲师| 虚拟歌姬们 · DECO*27 · wowaka … |
| **歌手** | 宇多田光 · LiSA · Aimer · ヨルシカ · YOASOBI · ZUTOMAYO · Eve · Ado … |

侧边栏自动按分类分组显示，名字中英双语跟着应用语言切换。

<img width="1357" height="744" alt="Screenshot 2026-05-15 at 15 34 23" src="https://github.com/user-attachments/assets/0d5377ae-0f56-4b45-b96f-f484b10bf8d8" />

##歌词滚动显示

把 `.lrc` 文件拖到右侧歌词面板，歌词就跟着播放进度滚动而且高亮当前句。点任意一行可以跳到那个时间播放。

支持 `.lrc` / `.rtf` / 纯文本，编码自动识别（UTF-8）
第一次拖入会自动绑定到曲目，下次播放这首歌歌词自动出现。

<img width="2714" height="1488" alt="image" src="https://github.com/user-attachments/assets/9f8217f6-86ce-4cb4-b257-f815a3ef84b9" />

##视觉

**三个选项卡布局**
**随意客制化（开发中）**
- 6 套预设强调色（系统蓝 / 樱花粉 / 天空青 / 薄荷绿 / 丁香紫 / 夕橙）+ 自由 ColorPicker
- 跟随系统明暗 / 强制浅色 / 强制深色
- 中文 / English 实时切换
- 圆角强度 / 动画速度 

<img width="672" height="660" alt="Screenshot 2026-05-15 at 15 34 41" src="https://github.com/user-attachments/assets/a44ae3e9-184f-4f61-8f8a-6f8f4cab54d0" />


而且**可以放一张你喜欢的角色立绘放在列表上**
- 透明度、大小都能调，顶部柔和淡出不刺眼。
<img width="2714" height="1488" alt="image" src="https://github.com/user-attachments/assets/100dd521-45d2-4cdd-ac74-a2fc72a43bd4" />

###喜爱与播放列表
- 喜爱**歌曲** → 自动进「喜爱歌曲」playlist
- 喜爱**专辑** → 整张专辑的曲目进「喜爱专辑」playlist
- 喜爱**作曲家** → 该作曲家所有曲目进「喜爱作曲家」playlist

也可以自建播放列表，点 sidebar 的 `+` 按钮命名，然后右键任意歌曲「添加到播放列表」。

##Home 页

- 按时段问候你（早安 / 中午好 / 下午好 / 晚上好 / 夜深了）
- **每日推荐**：日期作种子的加权抽样，喜爱的曲目优先、很久没听的曲目优先、听爆的曲目降权。每天不一样，同一天打开多次一样 （当然你想再来一轮也可以的
- 媒体库统计卡，点击直达对应页面

###当然还有...

- **全库搜索**：曲名 / 作曲家 / 专辑 一框搞定
- **导入时自动复制到 `~/Music/Neiro/`**：删源文件不影响播放
- **同名 `.lrc` 自动关联**：音频和歌词在同目录就自动绑定
- **全屏播放**：沉浸感聆听

---

## Let's Take a Try

### 系统要求
- macOS 14 (Sonoma) +
    - Macbook 产品线 M1 - M5系列+
    - 建议 macOS 26 （Tahoe）+

##**下载**

- 参见Release页面

### 或者自己编译
1. 装 Xcode 
2. 克隆这个仓库
3. 打开 `Neiro/Neiro.xcodeproj`

### 第一次打开
1. 按 **⌘O** 打开导入窗口
2. 把音乐拖进去（文件或整个文件夹都行）
3. 扫描完成后侧边栏自动出现你的二次元企划分类
4. 双击任意一首歌开始听

### 常用快捷键

| 快捷键 |
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
    ├── RootView.swift             视图布局
    ├── Sidebar.swift              侧栏导航
    ├── PlayerBar.swift            底部播放栏
    ├── NowPlayingView.swift       全屏播放页
    ├── LyricsPanel.swift          右侧歌词面板
    ├── ImportView.swift           导入窗口
    ├── Theme.swift                配色 / 多语言
    └── Pages/                     Home / Songs / Albums / Artists / Playlists / Search / Settings          搜索
```

技术栈：Swift 5.9 · SwiftUI · SwiftData · AVAudioEngine · AVFoundation

---

---

## 致谢 

- 谢谢我的好朋友们的支持啦
- 项目仓库不包含任何角色立绘或音乐文件，请用自己的合法资源，支持正版哦
- 感谢在我没有一点灵感的时候Claude帮我想了很多地方该怎么写
- 我平常很不爱写批注注释什么的（这是坏习惯！！！），感谢Codex帮我完成了注释
- 感谢我推凯尔希（不是
- 哦内盖，给个星标吧，如果没有星标的话，瓦塔西！
    
---

## License 

MIT — 自己拿去玩，记得开心就好 OvO
---

<p align="center">
  <sub>by a high school student who loves MyGO ( </sub>
</p>
    

### 对于AI使用 （Artificial Intelligence）###
    - 本项目有在使用AI生成式工具用于编程和项目规划中
    
我使用了确实不少的Claude code帮助我解决bugs与完善项目，但是其余UI设计呀，各种点子都是我想的啦，为什么还有codex的事，那是因为我Claude额度用没了（因为这周复习）所以一些小问题就给到了Codex啦（）

而且，我第一次做这样的项目，没有AI教会我很多知识的话确实做不出来，这真的是一次很好的学习（确信


Copyright (c) 2026 Ethan Shen (Niccori-OvO) All right reservd
如需调用代码等请发Email哦

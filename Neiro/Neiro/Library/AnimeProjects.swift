
import Foundation


public enum AnimeCategory: String, CaseIterable, Identifiable {
    case band       // 乐队企划
    case idol       // 偶像企划
    case game       // 游戏 OST
    case vtuber     // VTuber
    case vocaloid   // VOCALOID
    case artist     // 歌手 / 独立艺人

    public var id: String { rawValue }

    public var sortOrder: Int {
        switch self {
        case .band: 0; case .idol: 1; case .game: 2
        case .vtuber: 3; case .vocaloid: 4; case .artist: 5
        }
    }

    public var sectionTitle: String {
        switch self {
        case .band:     return NeiroText.tr("乐队企划", "Bands")
        case .idol:     return NeiroText.tr("偶像企划", "Idol Projects")
        case .game:     return NeiroText.tr("游戏 OST", "Game OST")
        case .vtuber:   return NeiroText.tr("VTuber", "VTuber")
        case .vocaloid: return NeiroText.tr("VOCALOID", "VOCALOID")
        case .artist:   return NeiroText.tr("歌手", "Artists")
        }
    }

    public var badgeText: String {
        switch self {
        case .band:     return NeiroText.tr("乐队", "Band")
        case .idol:     return NeiroText.tr("偶像", "Idol")
        case .game:     return NeiroText.tr("游戏 OST", "Game OST")
        case .vtuber:   return NeiroText.tr("VTuber", "VTuber")
        case .vocaloid: return NeiroText.tr("VOCALOID", "VOCALOID")
        case .artist:   return NeiroText.tr("歌手", "Artist")
        }
    }

    public var symbolName: String {
        switch self {
        case .band:     "guitars"
        case .idol:     "star.circle"
        case .game:     "gamecontroller"
        case .vtuber:   "person.crop.square.badge.video"
        case .vocaloid: "waveform.path"
        case .artist:   "music.mic"
        }
    }
}


public struct AnimeProject: Identifiable, Hashable {
    public let id: String
    public let nameZH: String
    public let nameEN: String
    public let category: AnimeCategory
    public let keywords: Set<String>

    public var localizedName: String {
        NeiroText.tr(nameZH, nameEN)
    }

    public static func == (lhs: AnimeProject, rhs: AnimeProject) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}


public enum AnimeProjects {

    public static func match(artist: String?, album: String?, title: String?) -> [AnimeProject] {
        let haystack = [artist, album, title]
            .compactMap { $0?.lowercased() }
            .joined(separator: " · ")
        guard !haystack.isEmpty else { return [] }
        return all.filter { project in
            project.keywords.contains { haystack.contains($0) }
        }
    }

    public static func byID(_ id: String) -> AnimeProject? {
        all.first(where: { $0.id == id })
    }

    public static let all: [AnimeProject] = [

        AnimeProject(id: "poppinparty", nameZH: "Poppin'Party", nameEN: "Poppin'Party",
                     category: .band,
                     keywords: ["poppin'party", "poppin party", "poppinparty", "ポピパ"]),
        AnimeProject(id: "roselia", nameZH: "Roselia", nameEN: "Roselia",
                     category: .band,
                     keywords: ["roselia", "ロゼリア"]),
        AnimeProject(id: "afterglow", nameZH: "Afterglow", nameEN: "Afterglow",
                     category: .band,
                     keywords: ["afterglow", "アフターグロウ"]),
        AnimeProject(id: "pastelpalettes", nameZH: "Pastel*Palettes", nameEN: "Pastel*Palettes",
                     category: .band,
                     keywords: ["pastel*palettes", "pastel palettes", "pastelpalettes", "パスパレ"]),
        AnimeProject(id: "hellohappyworld", nameZH: "Hello, Happy World!", nameEN: "Hello, Happy World!",
                     category: .band,
                     keywords: ["hello, happy world", "hello happy world", "hellohappyworld", "ハロハピ"]),
        AnimeProject(id: "ras", nameZH: "RAISE A SUILEN", nameEN: "RAISE A SUILEN",
                     category: .band,
                     keywords: ["raise a suilen", "raiseasuilen"]),
        AnimeProject(id: "morfonica", nameZH: "Morfonica", nameEN: "Morfonica",
                     category: .band,
                     keywords: ["morfonica", "モルフォニカ"]),
        AnimeProject(id: "mygo", nameZH: "MyGO!!!!!", nameEN: "MyGO!!!!!",
                     category: .band,
                     keywords: ["mygo!!!!!", "mygo!!!", "mygo", "迷跡波", "迷子"]),
        AnimeProject(id: "avemujica", nameZH: "Ave Mujica", nameEN: "Ave Mujica",
                     category: .band,
                     keywords: ["ave mujica", "avemujica"]),
        AnimeProject(id: "htt", nameZH: "放课后茶会", nameEN: "Houkago Tea Time",
                     category: .band,
                     keywords: [
                        "放課後ティータイム", "houkago tea time", "hokago tea time",
                        "afterschool tea time", "after school tea time", "桜高軽音部",
                        "k-on", "k-on!", "けいおん", "けいおん!"
                     ]),
        AnimeProject(id: "togearitogenashi", nameZH: "トゲナシトゲアリ", nameEN: "Togenashi Togeari",
                     category: .band,
                     keywords: [
                        "girls band cry", "girlsbandcry", "ガールズバンドクライ",
                        "togenashi togeari", "トゲナシトゲアリ", "togeari", "gbc"
                     ]),

        AnimeProject(id: "muse", nameZH: "μ's", nameEN: "μ's",
                     category: .idol, keywords: ["μ's", "μs", "muse!"]),
        AnimeProject(id: "aqours", nameZH: "Aqours", nameEN: "Aqours",
                     category: .idol, keywords: ["aqours", "アクア"]),
        AnimeProject(id: "nijigasaki", nameZH: "虹咲学园学园偶像同好会", nameEN: "Nijigasaki School Idol Club",
                     category: .idol, keywords: ["nijigasaki", "虹ヶ咲", "虹咲", "ニジガク"]),
        AnimeProject(id: "liella", nameZH: "Liella!", nameEN: "Liella!",
                     category: .idol, keywords: ["liella", "リエラ"]),
        AnimeProject(id: "hasunosora", nameZH: "莲之空女学院", nameEN: "Hasunosora School Idol Club",
                     category: .idol, keywords: ["hasunosora", "蓮ノ空"]),
        AnimeProject(id: "leoneed", nameZH: "Leo/need", nameEN: "Leo/need",
                     category: .idol, keywords: ["leo/need", "レオニ", "leoneed"]),
        AnimeProject(id: "moremorejump", nameZH: "MORE MORE JUMP!", nameEN: "MORE MORE JUMP!",
                     category: .idol, keywords: ["more more jump", "moremorejump", "モモジャン"]),
        AnimeProject(id: "vbs", nameZH: "Vivid BAD SQUAD", nameEN: "Vivid BAD SQUAD",
                     category: .idol, keywords: ["vivid bad squad", "vividbadsquad", "ビビバス"]),
        AnimeProject(id: "wxs", nameZH: "Wonderlands×Showtime", nameEN: "Wonderlands×Showtime",
                     category: .idol, keywords: ["wonderlands x showtime", "wonderlands×showtime", "ワンダショ", "wxs"]),
        AnimeProject(id: "n25", nameZH: "25時、ナイトコードで", nameEN: "Nightcord at 25:00",
                     category: .idol, keywords: ["25-ji, nightcord de", "25時、ナイトコードで", "nightcord", "ニーゴ"]),
        AnimeProject(id: "virtualsinger", nameZH: "Virtual Singer", nameEN: "Virtual Singer",
                     category: .idol, keywords: ["virtual singer", "バーチャル・シンガー"]),
        AnimeProject(id: "765pro", nameZH: "THE iDOLM@STER 765PRO", nameEN: "THE iDOLM@STER 765PRO",
                     category: .idol, keywords: ["765pro", "765 pro", "765production"]),
        AnimeProject(id: "cinderella", nameZH: "灰姑娘女孩", nameEN: "Cinderella Girls",
                     category: .idol, keywords: ["cinderella girls", "シンデレラガールズ", "デレマス"]),
        AnimeProject(id: "millionlive", nameZH: "百万现场", nameEN: "Million Live!",
                     category: .idol, keywords: ["million live", "ミリオンライブ", "ミリマス"]),
        AnimeProject(id: "shinymas", nameZH: "闪耀色彩", nameEN: "Shiny Colors",
                     category: .idol, keywords: ["shiny colors", "シャイニーカラーズ", "シャニマス"]),

        AnimeProject(id: "hoyomix", nameZH: "HoYo-MiX", nameEN: "HoYo-MiX",
                     category: .game, keywords: ["hoyo-mix", "hoyomix", "hoyo mix"]),
        AnimeProject(id: "genshin", nameZH: "原神", nameEN: "Genshin Impact",
                     category: .game, keywords: ["genshin", "原神"]),
        AnimeProject(id: "honkai3rd", nameZH: "崩坏3", nameEN: "Honkai Impact 3rd",
                     category: .game, keywords: ["honkai impact", "崩坏3", "崩壊3"]),
        AnimeProject(id: "starrail", nameZH: "崩坏:星穹铁道", nameEN: "Honkai: Star Rail",
                     category: .game,
                     keywords: ["star rail", "star-rail", "崩坏:星穹铁道", "崩坏星穹铁道",
                                "崩壊:スターレイル", "星穹鉄道"]),
        AnimeProject(id: "zzz", nameZH: "绝区零", nameEN: "Zenless Zone Zero",
                     category: .game, keywords: ["zenless zone zero", "绝区零", "zzz"]),
        AnimeProject(id: "wuwa", nameZH: "鸣潮", nameEN: "Wuthering Waves",
                     category: .game, keywords: ["wuthering waves", "wuwa", "鸣潮", "鳴潮"]),

        AnimeProject(id: "hololive", nameZH: "Hololive", nameEN: "Hololive",
                     category: .vtuber, keywords: ["hololive", "ホロライブ"]),
        AnimeProject(id: "nijisanji", nameZH: "彩虹社", nameEN: "Nijisanji",
                     category: .vtuber, keywords: ["nijisanji", "にじさんじ"]),

        AnimeProject(id: "miku", nameZH: "初音未来", nameEN: "Hatsune Miku",
                     category: .vocaloid, keywords: ["hatsune miku", "初音ミク", "初音未来"]),
        AnimeProject(id: "kagamine", nameZH: "镜音双子", nameEN: "Kagamine Rin & Len",
                     category: .vocaloid, keywords: ["kagamine", "鏡音", "镜音"]),
        AnimeProject(id: "megurine", nameZH: "巡音流歌", nameEN: "Megurine Luka",
                     category: .vocaloid, keywords: ["megurine", "巡音", "luka"]),
        AnimeProject(id: "deco27", nameZH: "DECO*27", nameEN: "DECO*27",
                     category: .vocaloid, keywords: ["deco*27", "deco27"]),
        AnimeProject(id: "wowaka", nameZH: "ヲワカ", nameEN: "wowaka",
                     category: .vocaloid, keywords: ["wowaka", "ヲワカ"]),
        AnimeProject(id: "kikuo", nameZH: "Kikuo", nameEN: "Kikuo",
                     category: .vocaloid, keywords: ["kikuo", "キクオ"]),

        AnimeProject(id: "utadahikaru", nameZH: "宇多田光", nameEN: "Utada Hikaru",
                     category: .artist,
                     keywords: ["utada hikaru", "utadahikaru", "宇多田ヒカル", "宇多田光"]),
        AnimeProject(id: "lisa", nameZH: "LiSA", nameEN: "LiSA",
                     category: .artist, keywords: ["lisa"]),
        AnimeProject(id: "aimer", nameZH: "Aimer", nameEN: "Aimer",
                     category: .artist, keywords: ["aimer", "エメ"]),
        AnimeProject(id: "yorushika", nameZH: "ヨルシカ", nameEN: "Yorushika",
                     category: .artist, keywords: ["ヨルシカ", "yorushika"]),
        AnimeProject(id: "yoasobi", nameZH: "YOASOBI", nameEN: "YOASOBI",
                     category: .artist, keywords: ["yoasobi", "ヨアソビ"]),
        AnimeProject(id: "zutomayo", nameZH: "ZUTOMAYO", nameEN: "ZUTOMAYO",
                     category: .artist,
                     keywords: ["zutomayo", "ずとまよ", "ずっと真夜中", "真夜中でいいのに"]),
        AnimeProject(id: "eve", nameZH: "Eve", nameEN: "Eve",
                     category: .artist, keywords: ["eve", "イヴ"]),
        AnimeProject(id: "ado", nameZH: "Ado", nameEN: "Ado",
                     category: .artist, keywords: ["ado"]),
        AnimeProject(id: "supercell", nameZH: "supercell", nameEN: "supercell",
                     category: .artist, keywords: ["supercell"]),
        AnimeProject(id: "kana_boon", nameZH: "KANA-BOON", nameEN: "KANA-BOON",
                     category: .artist, keywords: ["kana-boon", "kanaboon"]),
    ]
}

//
//  PathProvider.swift
//  Neiro
//
//  集中管理运行时路径。
//
//  关键设计：Neiro **不会** 主动扫描或读取 `~/Music/` 文件夹里既有的内容。
//  库只由用户通过导入窗口拖入的文件 / 文件夹组成，源文件留在原地，
//  SwiftData 只持有路径引用与元数据缓存。
//

import Foundation
import os

public enum NeiroPaths {

    private static let log = Logger(subsystem: "app.neiro", category: "Paths")

    /// App 配置目录：~/Library/Application Support/Neiro/
    /// 永远在沙盒可写范围内，存数据库 / 缓存 / 设置。
    public static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support")
        return base.appending(path: "Neiro")
    }

    /// SwiftData 数据库文件
    public static var databaseURL: URL {
        appSupport.appending(path: "library.store")
    }

    /// 首次启动确保 appSupport 存在即可——不创建任何用户可见的"音乐库"目录。
    public static func bootstrap() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: appSupport.path) {
            do {
                try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
                log.info("created \(appSupport.path, privacy: .public)")
            } catch {
                log.error("create appSupport failed: \(error.localizedDescription)")
            }
        }
    }
}

import Foundation

/// 递归计算 URL 总字节数（目录递归，文件取其 size）
private func totalSize(of url: URL) throws -> UInt64 {
    let fm = FileManager.default
    let res = try fm.attributesOfItem(atPath: url.path)
    let type = res[.type] as? FileAttributeType
    if type == .typeDirectory {
        let kids = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        return try kids.reduce(0) { try $0 + totalSize(of: $1) }
    } else {
        return (res[.size] as? UInt64) ?? 0
    }
}

/// 拷贝进度累加器（仅在后台 Task 内创建与使用）
private final class CopyAccumulator {
    let total: UInt64
    var copied: UInt64 = 0
    var lastReport = Date()
    init(total: UInt64) { self.total = total }
    func add(_ n: UInt64, yield: (Double) -> Void) {
        copied += n
        let now = Date()
        if now.timeIntervalSince(lastReport) >= 0.08 {
            lastReport = now
            yield(total > 0 ? min(1, Double(copied) / Double(total)) : 1)
        }
    }
}

/// 递归拷贝 source -> destination，单文件分块写入以汇报进度；符号链接直接拷贝。
private func copyRecursive(from src: URL, to dst: URL, acc: CopyAccumulator, yield: @escaping (Double) -> Void) throws {
    let fm = FileManager.default
    let res = try fm.attributesOfItem(atPath: src.path)
    let type = res[.type] as? FileAttributeType
    if type == .typeDirectory {
        try fm.createDirectory(at: dst, withIntermediateDirectories: true)
        let kids = try fm.contentsOfDirectory(at: src, includingPropertiesForKeys: nil)
        for k in kids {
            try copyRecursive(from: k, to: dst.appendingPathComponent(k.lastPathComponent), acc: acc, yield: yield)
        }
    } else if type == .typeSymbolicLink {
        try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
        try fm.copyItem(at: src, to: dst)
    } else {
        try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dst.path) { try fm.removeItem(at: dst) }
        guard let ins = InputStream(url: src), let outs = OutputStream(url: dst, append: false) else {
            throw NSError(domain: "FileCopy", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法打开文件：\(src.lastPathComponent)"])
        }
        ins.open(); outs.open()
        let bufSize = 256 * 1024
        var buf = [UInt8](repeating: 0, count: bufSize)
        while true {
            let read = ins.read(&buf, maxLength: bufSize)
            if read <= 0 { break }
            let written = outs.write(buf, maxLength: read)
            if written < 0 {
                ins.close(); outs.close()
                throw outs.streamError ?? NSError(domain: "FileCopy", code: 2, userInfo: [NSLocalizedDescriptionKey: "写入失败：\(dst.lastPathComponent)"])
            }
            acc.add(UInt64(written), yield: yield)
        }
        ins.close(); outs.close()
    }
}

/// 带字节级进度的拷贝，返回 0...1 的 AsyncStream（拷贝在后台线程进行）。
func copyWithProgress(source: URL, destination: URL) -> AsyncStream<Double> {
    AsyncStream { continuation in
        Task.detached(priority: .userInitiated) {
            do {
                let total = try totalSize(of: source)
                let acc = CopyAccumulator(total: total)
                try copyRecursive(from: source, to: destination, acc: acc, yield: { continuation.yield($0) })
                continuation.yield(1)
                continuation.finish()
            } catch {
                continuation.finish()
            }
        }
    }
}

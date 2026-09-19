import Foundation

/// Stores each walk as a metadata file plus an append-only file of points.
///
/// Points are appended and flushed one at a time, so a walk survives the app
/// being killed mid-route: whatever reached the disk is still a valid walk, and
/// a half-written final line is discarded on load.
final class WalkStore {
    enum StoreError: Error, Equatable {
        case walkNotFound(UUID)
    }

    private let root: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Directories are created on the first write, so nothing here can fail at
    /// launch and leave the app without a store.
    init(root: URL, fileManager: FileManager = .default) {
        self.root = root
        self.fileManager = fileManager
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder.dateDecodingStrategy = .secondsSince1970
    }

    static func applicationSupportRoot(fileManager: FileManager = .default) -> URL {
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Caminata/walks", isDirectory: true)
    }

    // MARK: - Writing

    func createWalk(id: UUID = UUID(), startedAt: Date) throws -> WalkMetadata {
        let metadata = WalkMetadata(id: id, startedAt: startedAt, endedAt: nil)
        try fileManager.createDirectory(at: directory(for: id), withIntermediateDirectories: true)
        try write(metadata)
        if !fileManager.fileExists(atPath: pointsURL(for: id).path) {
            fileManager.createFile(atPath: pointsURL(for: id).path, contents: nil)
        }
        return metadata
    }

    func append(_ point: TrackPoint, to walkID: UUID) throws {
        var line = try encoder.encode(point)
        line.append(0x0A)

        let handle = try FileHandle(forWritingTo: pointsURL(for: walkID))
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
        try handle.synchronize()
    }

    @discardableResult
    func finish(walkID: UUID, endedAt: Date, stats: WalkStats? = nil) throws -> WalkMetadata {
        var metadata = try loadMetadata(walkID)
        metadata.endedAt = endedAt
        if let stats {
            metadata.apply(stats)
        }
        try write(metadata)
        return metadata
    }

    func delete(walkID: UUID) throws {
        try fileManager.removeItem(at: directory(for: walkID))
    }

    // MARK: - Reading

    func loadMetadata(_ walkID: UUID) throws -> WalkMetadata {
        guard let data = fileManager.contents(atPath: metadataURL(for: walkID).path) else {
            throw StoreError.walkNotFound(walkID)
        }
        return try decoder.decode(WalkMetadata.self, from: data)
    }

    func loadWalk(_ walkID: UUID) throws -> Walk {
        Walk(metadata: try loadMetadata(walkID), points: try loadPoints(walkID))
    }

    func loadPoints(_ walkID: UUID) throws -> [TrackPoint] {
        guard let data = fileManager.contents(atPath: pointsURL(for: walkID).path) else {
            return []
        }
        // A trailing partial line means the app died mid-append; drop it rather
        // than failing the whole walk.
        return data.split(separator: 0x0A).compactMap { try? decoder.decode(TrackPoint.self, from: Data($0)) }
    }

    /// Newest first.
    func listWalks() throws -> [WalkMetadata] {
        let entries = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []

        return entries
            .compactMap { UUID(uuidString: $0.lastPathComponent) }
            .compactMap { try? loadMetadata($0) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    /// A walk that was never stopped, if the app was killed while recording.
    func activeWalk() throws -> WalkMetadata? {
        try listWalks().first(where: \.isActive)
    }

    // MARK: - Paths

    private func directory(for walkID: UUID) -> URL {
        root.appendingPathComponent(walkID.uuidString, isDirectory: true)
    }

    private func metadataURL(for walkID: UUID) -> URL {
        directory(for: walkID).appendingPathComponent("meta.json")
    }

    private func pointsURL(for walkID: UUID) -> URL {
        directory(for: walkID).appendingPathComponent("points.jsonl")
    }

    private func write(_ metadata: WalkMetadata) throws {
        try encoder.encode(metadata).write(to: metadataURL(for: metadata.id), options: .atomic)
    }
}

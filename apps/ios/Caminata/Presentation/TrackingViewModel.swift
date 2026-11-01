import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class TrackingViewModel {
    private(set) var isRecording = false
    private(set) var isPaused = false
    private(set) var coordinates: [CLLocationCoordinate2D] = []
    /// The route cut at its pauses, so the live map does not draw a line
    /// across wherever the walk was paused.
    private(set) var segments: [[CLLocationCoordinate2D]] = []
    private(set) var stats: WalkStats = .zero
    /// The walk's clock: from Play, minus pauses. This is what the live
    /// screens show; `stats.elapsed` runs from the first fix.
    private(set) var elapsed: TimeInterval = 0
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isExporting = false

    var export: WalkExport?
    var errorMessage: String?

    private(set) var accountName: String?
    private(set) var pendingUploads = 0

    private let store: WalkStore
    private let recorder: WalkRecorder
    private let exporter: WalkExporting
    private let account: CloudAccounting
    private let uploader: WalkUploader
    private let placeNamer: PlaceNaming
    private let broadcaster: WalkBroadcasting
    let settings: AppSettings
    private var ticker: Task<Void, Never>?
    /// The ticker fires once a second whether or not a fix arrived, and the
    /// coordinates only change when one did.
    private var renderedPointCount = 0
    private var renderedPauseCount = 0

    init(
        store: WalkStore = WalkStore(root: WalkStore.applicationSupportRoot()),
        recorder: WalkRecorder? = nil,
        exporter: WalkExporting? = nil,
        account: CloudAccounting? = nil,
        uploader: WalkUploader? = nil,
        settings: AppSettings = AppSettings(),
        placeNamer: PlaceNaming = PlaceNamer(),
        broadcaster: WalkBroadcasting? = nil
    ) {
        self.placeNamer = placeNamer
        self.broadcaster = broadcaster ?? LiveBroadcaster()
        let account = account ?? FirebaseAccount()
        self.store = store
        self.recorder = recorder ?? WalkRecorder(store: store)
        self.settings = settings
        self.exporter = exporter ?? WalkExporter(settings: settings)
        self.account = account
        self.uploader = uploader
            ?? WalkUploader(store: store, sync: FirestoreWalkSync(account: account))

        self.recorder.onChange = { [weak self] in self?.refresh() }
        self.recorder.onError = { [weak self] error in self?.errorMessage = error.localizedDescription }
        self.recorder.onAuthorizationChange = { [weak self] status in
            self?.authorizationStatus = status
        }
        authorizationStatus = self.recorder.authorizationStatus

        self.broadcaster.onCommand = { [weak self] command in
            switch command {
            case .pause: self?.pause()
            case .resume: self?.resume()
            }
        }

        self.account.onChange = { [weak self] in self?.refreshAccount() }
        self.uploader.onChange = { [weak self] in
            self?.pendingUploads = self?.uploader.pendingCount ?? 0
        }
        refreshAccount()
    }

    // MARK: - Account

    /// False in a build with no Firebase configuration, where the whole
    /// account section is hidden rather than offered and then refused.
    var cloudAvailable: Bool { account.isAvailable }
    var isSignedIn: Bool { account.userID != nil }

    func signIn() async {
        do {
            try await account.signIn()
            await uploader.uploadPending()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try account.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshAccount() {
        accountName = account.displayName
        uploader.refreshPendingCount()
    }

    var permissionNeeded: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func onAppear() {
        if authorizationStatus == .notDetermined {
            recorder.requestAuthorization()
        }
        do {
            try recorder.restore()
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
        refreshAccount()
        Task { await uploader.uploadPending() }
    }

    func toggleRecording() {
        isRecording ? stop() : start()
    }

    func start() {
        guard !permissionNeeded else { return }
        do {
            try recorder.start()
            startTicking()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    func pause() {
        do {
            try recorder.pause()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resume() {
        do {
            try recorder.resume()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        stopTicking()
        do {
            guard let walk = try recorder.stop() else { return }
            refresh()
            guard !walk.points.isEmpty else {
                errorMessage = "Esa caminata no registró posiciones utilizables, así que no hay mapa para dibujar."
                return
            }
            Task {
                // Naming first, so the summary and the upload carry it.
                let walk = await describe(walk)
                await exportWalk(walk)
                // A stop happens wherever the walk ended, which is where there
                // is least likely to be signal. A failure here is not worth
                // reporting: the walk stays queued and goes out later -- and
                // the web link only appears once the walk is actually there.
                if await uploader.upload(walk), export?.id == walk.id {
                    export?.webURL = WebHistory.url(for: walk.id)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stamps the colour the walk was drawn in and, when it has no name yet,
    /// asks the geocoder what to call it. Both are best-effort: a walk with
    /// neither still exports and uploads, it just keeps its date as a name.
    private func describe(_ walk: Walk) async -> Walk {
        var walk = walk
        var name: String?

        if walk.metadata.name == nil,
           let first = walk.coordinates.first,
           let last = walk.coordinates.last {
            name = await placeNamer.name(startingAt: first, endingAt: last)
        }

        if let updated = try? store.describe(
            walkID: walk.id,
            name: name,
            routeColor: settings.routeColorHex
        ) {
            walk.metadata = updated
        }
        return walk
    }

    func exportWalk(_ walk: Walk) async {
        isExporting = true
        defer { isExporting = false }
        do {
            export = try await exporter.export(walk)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func emailBody(for export: WalkExport) -> String {
        exporter.emailBody(for: export.walk, webURL: export.webURL)
    }

    func makeHistoryModel() -> HistoryViewModel {
        HistoryViewModel(store: store, exporter: exporter, uploader: uploader)
    }

    // MARK: - Private

    private func refresh() {
        let now = Date()
        isRecording = recorder.isRecording
        isPaused = recorder.isPaused
        let points = recorder.points
        let pauses = recorder.metadata?.pauseList ?? []

        if points.count != renderedPointCount || pauses.count != renderedPauseCount {
            renderedPointCount = points.count
            renderedPauseCount = pauses.count
            let location = { (point: TrackPoint) in
                CLLocationCoordinate2D(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
            }
            coordinates = points.map(location)
            segments = Walk.segments(of: points, pauses: pauses).map { $0.map(location) }
        }

        stats = WalkStats.compute(from: points, endedAt: isRecording ? now : nil, pauses: pauses)
        if let metadata = recorder.metadata, isRecording {
            elapsed = WalkStats.activeDuration(from: metadata.startedAt, to: now, pauses: pauses)
            broadcaster.publish(
                LiveWalkState(
                    elapsed: elapsed,
                    at: now,
                    pausedAt: metadata.isPaused ? pauses.last?.start : nil,
                    distance: stats.distance,
                    pace: stats.averagePace,
                    routeColor: settings.routeColorHex
                ),
                startedAt: metadata.startedAt
            )
        } else {
            elapsed = 0
            broadcaster.publish(nil, startedAt: nil)
        }

        if isRecording, ticker == nil {
            startTicking()
        }
    }

    /// The elapsed time has to keep moving even when no new fix arrives.
    ///
    /// Weakly captured so that a model dropped mid-walk takes its ticker with
    /// it instead of leaving one running against nothing.
    private func startTicking() {
        stopTicking()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.refresh()
            }
        }
    }

    private func stopTicking() {
        ticker?.cancel()
        ticker = nil
    }
}

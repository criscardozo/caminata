import CoreLocation
import Foundation
import Observation

@Observable
final class TrackingViewModel {
    private(set) var isRecording = false
    private(set) var coordinates: [CLLocationCoordinate2D] = []
    private(set) var stats: WalkStats = .zero
    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var isExporting = false

    var export: WalkExport?
    var errorMessage: String?

    private let store: WalkStore
    private let recorder: WalkRecorder
    private let exporter: WalkExporter
    private var ticker: Timer?

    init(
        store: WalkStore = WalkStore(root: WalkStore.applicationSupportRoot()),
        recorder: WalkRecorder? = nil,
        exporter: WalkExporter = WalkExporter()
    ) {
        self.store = store
        self.recorder = recorder ?? WalkRecorder(store: store)
        self.exporter = exporter

        self.recorder.onChange = { [weak self] in self?.refresh() }
        self.recorder.onError = { [weak self] error in self?.errorMessage = error.localizedDescription }
        self.recorder.onAuthorizationChange = { [weak self] status in
            self?.authorizationStatus = status
        }
        authorizationStatus = self.recorder.authorizationStatus
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

    func stop() {
        stopTicking()
        do {
            guard let walk = try recorder.stop() else { return }
            refresh()
            guard !walk.points.isEmpty else {
                errorMessage = "That walk recorded no usable positions, so there is no map to draw."
                return
            }
            Task { await exportWalk(walk) }
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func emailBody(for walk: Walk) -> String {
        exporter.emailBody(for: walk)
    }

    func makeHistoryModel() -> HistoryViewModel {
        HistoryViewModel(store: store, exporter: exporter)
    }

    // MARK: - Private

    private func refresh() {
        isRecording = recorder.isRecording
        let points = recorder.points
        coordinates = points.map {
            CLLocationCoordinate2D(
                latitude: $0.coordinate.latitude,
                longitude: $0.coordinate.longitude
            )
        }
        stats = WalkStats.compute(from: points, endedAt: isRecording ? Date() : nil)
        if isRecording, ticker == nil {
            startTicking()
        }
    }

    /// The elapsed time has to keep moving even when no new fix arrives.
    private func startTicking() {
        stopTicking()
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }
}

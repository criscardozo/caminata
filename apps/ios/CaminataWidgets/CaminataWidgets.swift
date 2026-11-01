import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CaminataWidgets: WidgetBundle {
    var body: some Widget {
        WalkActivityWidget()
    }
}

/// The walk in progress, on the lock screen and in the Dynamic Island.
struct WalkActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            LockScreenWalk(state: context.state)
                .padding(16)
                .activityBackgroundTint(nil)
        } dynamicIsland: { context in
            let state = context.state
            let colour = Color(hex: state.routeColor)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Figure(label: "Distancia", value: LiveFormat.distance(state.distance))
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Figure(label: "Ritmo", value: LiveFormat.pace(state.pace))
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    WalkClock(state: state)
                        .font(.system(.title2, design: .rounded).weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Label(state.isPaused ? "En pausa" : "Caminata en curso", systemImage: state.isPaused ? "pause.fill" : "figure.walk")
                        .font(.caption)
                        .foregroundStyle(state.isPaused ? .orange : colour)
                }
            } compactLeading: {
                Image(systemName: state.isPaused ? "pause.fill" : "figure.walk")
                    .foregroundStyle(state.isPaused ? .orange : colour)
            } compactTrailing: {
                WalkClock(state: state)
                    .frame(maxWidth: 52)
                    .font(.caption.weight(.semibold))
            } minimal: {
                Image(systemName: state.isPaused ? "pause.fill" : "figure.walk")
                    .foregroundStyle(state.isPaused ? .orange : colour)
            }
            .keylineTint(colour)
        }
    }
}

/// The clock runs on its own from `clockStart`, and freezes at `pausedAt`, so
/// the app does not have to send an update every second to keep it moving.
struct WalkClock: View {
    let state: LiveWalkState

    var body: some View {
        Text(
            timerInterval: state.clockStart...Date.distantFuture,
            pauseTime: state.pausedAt,
            countsDown: false,
            showsHours: true
        )
        .monospacedDigit()
        .multilineTextAlignment(.center)
    }
}

private struct Figure: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
    }
}

private struct LockScreenWalk: View {
    let state: LiveWalkState

    var body: some View {
        let colour = Color(hex: state.routeColor)

        HStack(spacing: 14) {
            ZStack {
                Circle().fill(state.isPaused ? Color.orange.opacity(0.22) : colour.opacity(0.22))
                Image(systemName: state.isPaused ? "pause.fill" : "figure.walk")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(state.isPaused ? .orange : colour)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.isPaused ? "Caminata en pausa" : "Caminata en curso")
                    .font(.subheadline.weight(.semibold))
                Text("\(LiveFormat.distance(state.distance))  ·  \(LiveFormat.pace(state.pace))")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            WalkClock(state: state)
                .font(.system(.title, design: .rounded).weight(.semibold))
                .frame(maxWidth: 120, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
    }
}

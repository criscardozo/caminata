import SwiftUI

struct WalkView: View {
    let link: PhoneLink

    var body: some View {
        if let state = link.state {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                walk(state, at: context.date)
            }
        } else {
            idle
        }
    }

    private func walk(_ state: LiveWalkState, at now: Date) -> some View {
        let colour = Color(hex: state.routeColor)

        return VStack(spacing: 6) {
            Label(state.isPaused ? "En pausa" : "Caminando", systemImage: state.isPaused ? "pause.fill" : "figure.walk")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(state.isPaused ? .orange : colour)

            Text(LiveFormat.duration(state.elapsed(at: now)))
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            HStack {
                figure("Distancia", LiveFormat.distance(state.distance))
                Spacer()
                figure("Ritmo", LiveFormat.pace(state.pace))
            }

            Button {
                link.send(state.isPaused ? .resume : .pause)
            } label: {
                if link.pendingCommand != nil {
                    ProgressView()
                } else {
                    Label(state.isPaused ? "Reanudar" : "Pausar", systemImage: state.isPaused ? "play.fill" : "pause.fill")
                }
            }
            .tint(state.isPaused ? .green : .orange)
            .disabled(link.pendingCommand != nil)

            if let error = link.lastError {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 4)
    }

    private func figure(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
    }

    private var idle: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Sin caminata en curso")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Empezala desde el iPhone y la vas a ver acá.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

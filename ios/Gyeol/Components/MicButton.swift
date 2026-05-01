// 결 (Gyeol) — MicButton + RecordingBanner + Waveform
// 03-design-system §8.3, §8.4, §8.5

import SwiftUI

public enum MicState {
    case inactive
    case recording
    case denied
}

public struct MicButton: View {
    public let state: MicState
    public let onTap: () -> Void

    @State private var pulse: Bool = false

    public init(state: MicState, onTap: @escaping () -> Void) {
        self.state = state
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle().fill(background)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
            .frame(width: 40, height: 40)
            .scaleEffect(state == .recording && pulse ? 1.06 : 1.0)
            .animation(state == .recording ? GyMotion.pulse : .default, value: pulse)
            .onAppear {
                if state == .recording { pulse = true }
            }
            .onChange(of: state) { _, newState in
                pulse = newState == .recording
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state == .recording ? "녹음 종료" : "음성 입력 시작")
    }

    private var background: Color {
        switch state {
        case .inactive: return .gyBgSubtle
        case .recording: return .gyAccent
        case .denied: return .gyBgSubtle
        }
    }

    private var iconColor: Color {
        switch state {
        case .inactive: return .gyTextSecondary
        case .recording: return .gyAccentContrast
        case .denied: return .gyTextDisabled
        }
    }

    private var iconName: String {
        switch state {
        case .denied: return "mic.slash"
        default: return "mic"
        }
    }
}

public struct RecordingBanner: View {
    public let elapsedSeconds: Int
    @State private var dotPulse: Bool = false

    public init(elapsedSeconds: Int) {
        self.elapsedSeconds = elapsedSeconds
    }

    public var body: some View {
        HStack(spacing: GySpace.sm) {
            Circle()
                .fill(Color.gyRecording)
                .frame(width: 8, height: 8)
                .opacity(dotPulse ? 1.0 : 0.4)
                .animation(GyMotion.recordingDot, value: dotPulse)
                .onAppear { dotPulse = true }
            Text("듣고 있습니다")
                .font(GyType.bodySM)
                .foregroundColor(.gyTextPrimaryAlias)
            Spacer()
            Text(formatElapsed(elapsedSeconds))
                .font(GyType.mono)
                .foregroundColor(.gyTextSecondary)
        }
        .padding(.horizontal, GySpace.md)
        .padding(.vertical, 10)
        .background(Color.gyBgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: GyRadius.md, style: .continuous))
    }
}

private func formatElapsed(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

extension Color {
    fileprivate static let gyTextPrimaryAlias = Color.gyText
}

public struct WaveformView: View {
    public let amplitude: Float

    public init(amplitude: Float) {
        self.amplitude = amplitude
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<25, id: \.self) { i in
                BarView(index: i, amplitude: amplitude)
            }
        }
        .frame(height: 40)
        .accessibilityHidden(true)
    }
}

private struct BarView: View {
    let index: Int
    let amplitude: Float
    @State private var phase: Double = 0

    var body: some View {
        // 무음 시 1.5pt baseline, 입력 시 amplitude 기반 height
        let base: CGFloat = 1.5
        let dynamicHeight: CGFloat = CGFloat(amplitude) * 32 + base
        let phasedHeight = dynamicHeight * (0.6 + 0.4 * CGFloat(sin(phase + Double(index) * 0.3)))
        return RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.gyAccent.opacity(0.7))
            .frame(width: 2.5, height: max(base, phasedHeight))
            .onAppear {
                withAnimation(GyMotion.waveform) { phase = .pi * 2 }
            }
    }
}

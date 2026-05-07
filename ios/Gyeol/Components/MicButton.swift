// 결 (Gyeol) — MicButton + RecordingBanner + Waveform
// 결_디자인시스템_v1 §2.2.2 (MicButton), §2.4.3 (RecordingBanner), §2.4.4 (Waveform).

import SwiftUI

public enum MicState {
    case inactive
    case recording
    case denied
}

// ─── MicButton ────────────────────────────────────────────
// 비활성: 40×40, bg.subtle + 1pt border, mic.fill text.secondary 16pt.
// 활성: bg accent.primary + 외곽 ring(scale 0.95→1.4 + opacity 0.5→0, 1.6s ease infinite).
// 권한 없음: mic.slash text.disabled-equivalent.

public struct MicButton: View {
    public let state: MicState
    public let onTap: () -> Void

    @State private var pulseScale: CGFloat = 0.95
    @State private var pulseOpacity: Double = 0.5

    public init(state: MicState, onTap: @escaping () -> Void) {
        self.state = state
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack {
                if state == .recording {
                    Circle()
                        .stroke(Color.gyeolAccentPrimary, lineWidth: 2)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                        .frame(width: 46, height: 46)
                }
                Circle()
                    .fill(background)
                    .overlay(
                        Circle()
                            .stroke(state == .recording ? Color.clear : Color.gyeolBorder, lineWidth: 1)
                    )
                    .frame(width: 40, height: 40)
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(iconColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(state == .recording ? "녹음 종료" : "음성 입력 시작")
        .onAppear { startPulseIfNeeded() }
        .onChange(of: state) { _, newState in
            if newState == .recording { startPulse() } else { resetPulse() }
        }
    }

    private var background: Color {
        switch state {
        case .inactive: return .gyeolBgSubtle
        case .recording: return .gyeolAccentPrimary
        case .denied: return .gyeolBgSubtle
        }
    }

    private var iconColor: Color {
        switch state {
        case .inactive: return .gyeolTextSecondary
        case .recording: return .gyeolBgPrimary
        case .denied: return .gyeolTextTertiary
        }
    }

    private var iconName: String {
        switch state {
        case .denied: return "mic.slash"
        default: return "mic.fill"
        }
    }

    private func startPulseIfNeeded() {
        if state == .recording { startPulse() }
    }

    private func startPulse() {
        pulseScale = 0.95
        pulseOpacity = 0.5
        withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
            pulseScale = 1.4
            pulseOpacity = 0
        }
    }

    private func resetPulse() {
        withAnimation(.gyeolFast) {
            pulseScale = 0.95
            pulseOpacity = 0.5
        }
    }
}

// ─── RecordingBanner ──────────────────────────────────────
// 명세 §2.4.3: 8×8 빨간 점 펄스 + "듣고 있습니다" + SF Mono 12.5 timer.

public struct RecordingBanner: View {
    public let elapsedSeconds: Int
    @State private var dotPulse: Bool = false

    public init(elapsedSeconds: Int) {
        self.elapsedSeconds = elapsedSeconds
    }

    public var body: some View {
        HStack(spacing: .gyeolSM) {
            Circle()
                .fill(Color.gyeolStateRecording)
                .frame(width: 8, height: 8)
                .scaleEffect(dotPulse ? 1.0 : 0.85)
                .opacity(dotPulse ? 1.0 : 0.4)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: dotPulse)
                .onAppear { dotPulse = true }
            Text("듣고 있습니다")
                .gyeolStyle(.caption1)
                .foregroundColor(.gyeolTextPrimary)
            Spacer()
            Text(formatElapsed(elapsedSeconds))
                .font(.gyeolMonoSmall)
                .foregroundColor(.gyeolTextTertiary)
        }
        .padding(.horizontal, .gyeolMD)
        .padding(.vertical, 12)
        .background(Color.gyeolBgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: GyeolRadius.md, style: .continuous))
    }
}

private func formatElapsed(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

// ─── Waveform ─────────────────────────────────────────────
// 명세 §2.4.4: 25 bars, width 2.5, gap 3, height 32 area, accent.primary opacity 0.7,
// 막대별 0.0–0.3s delay, height 4↔24px + opacity 0.4↔1.0, 1.2s ease-in-out infinite.

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
        .frame(height: 32)
        .accessibilityHidden(true)
    }
}

private struct BarView: View {
    let index: Int
    let amplitude: Float
    @State private var phase: CGFloat = 0

    var body: some View {
        // 막대별 stagger delay 0.0–0.3s. amplitude 미연동 시 기본 4–24 범위 자체 진동.
        let delay = Double(index) * 0.012  // 25 bars * 0.012 ≈ 0.3s span
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 24
        let amp = max(0.0, min(1.0, CGFloat(amplitude)))
        let dynamicMax = baseHeight + (maxHeight - baseHeight) * (0.4 + 0.6 * amp)
        return RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Color.gyeolAccentPrimary.opacity(0.7))
            .frame(width: 2.5, height: phase * (dynamicMax - baseHeight) + baseHeight)
            .opacity(0.4 + 0.6 * phase)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.2)
                        .repeatForever(autoreverses: true)
                        .delay(delay)
                ) {
                    phase = 1.0
                }
            }
    }
}

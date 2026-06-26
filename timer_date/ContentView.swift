import SwiftUI
import AVFoundation
import AppKit

/// 円形タイマー表示を備えたメインビュー
struct ContentView: View {
    @State private var minutesInput = ""
    @State private var secondsInput = ""
    @State private var remainingSeconds: Int? = nil
    @State private var totalSeconds: Int = 0
    @State private var finished: Bool = false

    // 1 Hz でカウントダウン
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var player: AVAudioPlayer?

    // タイマー文字色（クリックでパレットから変更可能）
    @AppStorage("timerTextColorHex") private var timerTextColorHex: String = "FFFFFF"
    @State private var showColorPalette = false

    var body: some View {
        VStack(spacing: 16) {
            // 時間入力（分：秒）― タイマー実行中は非表示
            if remainingSeconds == nil {
                HStack {
                    TextField("分", text: $minutesInput)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                    Text("：")
                    TextField("秒", text: $secondsInput)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                }
                .font(.title2.monospacedDigit())
            }

            // 円形プログレス
            ZStack {
                // 背景リング
                Circle()  
                    .stroke(Color.gray.opacity(0.3), lineWidth: 12)

                // 残り時間リング（赤）
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.red.opacity(0.8),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90)) // 12 時開始

                // 残り時間のテキスト + ボタン
                VStack(spacing: 8) {
                    Text(remainingSecondsLabel)
                        .font(.title.monospacedDigit())
                        .bold()
                        .foregroundColor(timerTextColor)
                        .contentShape(Rectangle())
                        .onTapGesture { showColorPalette.toggle() }
                        .popover(isPresented: $showColorPalette, arrowEdge: .top) {
                            ColorPaletteView(hex: $timerTextColorHex)
                        }
                    Button(action: startTimer) {
                        Text(remainingSeconds == nil ? "開始" : "リセット")
                            .font(.body).bold()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(width: 160, height: 160)
        }
        .padding(24)
        .onReceive(timer) { _ in tick() }
        .onChange(of: remainingSeconds) { _, newValue in
            setWindowCompact(newValue != nil)
        }
    }

    // MARK: - タイマー制御
    private func startTimer() {
        if remainingSeconds == nil {
            let total = (Int(minutesInput) ?? 0) * 60 + (Int(secondsInput) ?? 0)
            guard total > 0 else { return }
            totalSeconds = total
            remainingSeconds = total
            finished = false
        } else {
            remainingSeconds = nil
            totalSeconds = 0
            finished = false
        }
    }

    private func tick() {
        guard var sec = remainingSeconds else { return }
        sec -= 1
        if sec <= 0 {
            remainingSeconds = nil
            finished = true
            playSound()
        } else {
            remainingSeconds = sec
        }
    }

    // MARK: - サウンド再生
    private func playSound() {
        guard let path = Bundle.main.path(forResource: "beep", ofType: "mp3") else {
            NSSound.beep()
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            if player?.play() == true {
                return
            }
            NSSound.beep()
        } catch {
            NSSound.beep()
        }
    }

    // MARK: - 表示用プロパティ
    private var remainingSecondsLabel: String {
        guard let sec = remainingSeconds else { return finished ? "🚨終了🚨\n⚠️FINISH⚠️" : "--:--" }
        return String(format: "%02d:%02d", sec / 60, sec % 60)
    }

    private var progress: Double {
        guard totalSeconds > 0, let remaining = remainingSeconds else { return 0 }
        return Double(remaining) / Double(totalSeconds)
    }

    private var timerTextColor: Color {
        Color(hex: timerTextColorHex) ?? .white
    }
}

// MARK: - カラーパレット

private struct ColorPaletteView: View {
    @Binding var hex: String
    @Environment(\.dismiss) private var dismiss

    private let presets: [String] = [
        "FFFFFF", "000000", "8E8E93", "FF3B30",
        "FF9500", "FFCC00", "34C759", "00C7BE",
        "30B0C7", "007AFF", "5856D6", "AF52DE",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 8), count: 6),
                      spacing: 8) {
                ForEach(presets, id: \.self) { code in
                    Button {
                        hex = code
                        dismiss()
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(hex: code) ?? .white)
                            .frame(width: 26, height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(hex.caseInsensitiveCompare(code) == .orderedSame
                                            ? Color.accentColor : Color.gray.opacity(0.4),
                                            lineWidth: hex.caseInsensitiveCompare(code) == .orderedSame ? 2.5 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()
            ColorPicker("カスタム", selection: Binding(
                get: { Color(hex: hex) ?? .white },
                set: { newColor in
                    if let h = newColor.hexString { hex = h }
                }
            ))
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 220)
    }
}

// MARK: - Color <-> hex 変換

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255.0,
            green: Double((v >> 8) & 0xFF) / 255.0,
            blue: Double(v & 0xFF) / 255.0
        )
    }

    var hexString: String? {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

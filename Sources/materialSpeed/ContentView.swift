import SwiftUI

private enum M3 {
    static let background = Color(red: 0.078, green: 0.071, blue: 0.094)
    static let surface = Color(red: 0.129, green: 0.118, blue: 0.149)
    static let surfaceHigh = Color(red: 0.173, green: 0.157, blue: 0.196)
    static let primary = Color(red: 0.816, green: 0.741, blue: 1.0)
    static let primaryContainer = Color(red: 0.294, green: 0.208, blue: 0.459)
    static let onPrimary = Color(red: 0.118, green: 0.055, blue: 0.196)
    static let onPrimaryContainer = Color(red: 0.918, green: 0.871, blue: 1.0)
    static let secondary = Color(red: 0.804, green: 0.773, blue: 0.859)
    static let muted = Color(red: 0.706, green: 0.671, blue: 0.733)
    static let error = Color(red: 1.0, green: 0.706, blue: 0.682)
}

private enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case russian = "ru"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .english: return "English"
        case .russian: return "Русский"
        }
    }

    var locale: Locale { Locale(identifier: rawValue) }

    func text(_ english: String, _ russian: String) -> String {
        self == .english ? english : russian
    }
}

struct ContentView: View {
    @StateObject private var model = SpeedTestModel()
    @AppStorage("materialSpeed.language") private var languageRaw = AppLanguage.english.rawValue
    @State private var showsHistory = false
    @State private var showsSettings = false
    @State private var displayedGaugeProgress = 0.0

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .english
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
                .allowsHitTesting(!showsHistory && !showsSettings)

            if showsHistory || showsSettings {
                M3.background.opacity(0.72)
                    .ignoresSafeArea()
                    .onTapGesture { closePanel() }
                    .transition(.opacity)
            }

            if showsHistory {
                HistoryPanel(model: model, language: language, close: closePanel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if showsSettings {
                SettingsPanel(languageRaw: $languageRaw, language: language, close: closePanel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(M3.background)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.58), value: showsHistory)
        .animation(.easeInOut(duration: 0.58), value: showsSettings)
        .onChange(of: gaugeProgress) { newValue in
            withAnimation(.easeInOut(duration: 1.15)) {
                displayedGaugeProgress = newValue
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header

            gauge
                .padding(.top, 34)

            metrics
                .padding(.top, 28)

            Spacer(minLength: 34)

            startButton
            versionLabel
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 24)
    }

    private var header: some View {
        HStack {
            Text("materialSpeed")
                .font(.system(size: 21, weight: .semibold, design: .rounded))

            Spacer()

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.52)) {
                        showsSettings = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(M3.surfaceHigh)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(M3.primary)
                    }
                    .frame(width: 42, height: 42)
                }
                .buttonStyle(M3ButtonStyle())
                .help(language.text("Settings", "Настройки"))

                Button {
                    withAnimation(.easeInOut(duration: 0.52)) {
                        showsHistory = true
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(M3.surfaceHigh)
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(M3.primary)
                    }
                    .frame(width: 42, height: 42)
                }
                .buttonStyle(M3ButtonStyle())
                .help(language.text("History", "История"))
            }
        }
    }

    private var gauge: some View {
        VStack(spacing: 18) {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate * 4.2

                ZStack {
                    WavyGaugeArc(progress: 1, phase: phase, growsFromBottom: false)
                        .stroke(M3.surfaceHigh, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .padding(10)

                    WavyGaugeArc(progress: displayedGaugeProgress, phase: phase, growsFromBottom: true)
                        .stroke(M3.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                        .padding(10)

                    VStack(spacing: 6) {
                        if !phaseLabel.isEmpty {
                            Text(phaseLabel)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .tracking(0.8)
                                .foregroundStyle(M3.muted)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(primaryValue)
                                .font(.system(size: 49, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                            if primaryNumericValue > 0 {
                                Text(primaryUnit)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(M3.muted)
                            }
                        }

                        Text(phaseTitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 28)
                }
                .frame(width: 292, height: 292)
            }

            Text(phaseSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(M3.muted)
                .frame(height: 18)
                .opacity(phaseSubtitle.isEmpty ? 0 : 1)
                .animation(.easeInOut(duration: 0.45), value: phaseSubtitle)
        }
    }

    private var metrics: some View {
        HStack(spacing: 12) {
            MetricCard(label: language.text("Download", "Загрузка"), value: model.download, unit: "Mbps")
            MetricCard(label: language.text("Upload", "Отдача"), value: model.upload, unit: "Mbps")
            MetricCard(label: "Ping", value: model.ping, unit: "ms")
        }
    }

    private var startButton: some View {
        Button(action: model.toggleTest) {
            HStack(spacing: 10) {
                Image(systemName: model.isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(buttonTitle)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .foregroundStyle(M3.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(M3.primary, in: Capsule())
        }
        .buttonStyle(M3ButtonStyle())
    }

    private var versionLabel: some View {
        Text("v1.0.15")
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(M3.muted)
            .padding(.top, 10)
    }

    private var primaryNumericValue: Double {
        switch model.phase {
        case .ping: return model.ping
        case .upload: return model.upload
        case .download, .finished: return model.download
        default: return 0
        }
    }

    private var primaryValue: String {
        guard primaryNumericValue > 0 else { return "—" }
        return formatted(primaryNumericValue, decimals: model.phase == .ping ? 0 : 1)
    }

    private var primaryUnit: String {
        model.phase == .ping ? "ms" : "Mbps"
    }

    private var gaugeProgress: Double {
        switch model.phase {
        case .ping:
            return pingProgress(model.ping)
        case .download:
            return speedProgress(model.download)
        case .upload:
            return speedProgress(model.upload)
        default:
            return 0
        }
    }

    private func speedProgress(_ speed: Double) -> Double {
        guard speed > 0 else { return 0 }
        return min(speed / 1_000, 1)
    }

    private func pingProgress(_ ping: Double) -> Double {
        guard ping > 0 else { return 0 }
        return min(max(log10(ping + 1) / log10(201), 0.04), 1)
    }

    private var phaseLabel: String {
        switch model.phase {
        case .idle: return ""
        case .ping: return language.text("LATENCY", "ЗАДЕРЖКА")
        case .download: return language.text("DOWNLOAD", "ЗАГРУЗКА")
        case .upload: return language.text("UPLOAD", "ОТДАЧА")
        case .finished: return language.text("RESULT", "РЕЗУЛЬТАТ")
        case .failed: return language.text("ERROR", "ОШИБКА")
        }
    }

    private var phaseTitle: String {
        switch model.phase {
        case .idle: return language.text("Speed", "Скорость")
        case .ping: return language.text("Analyzing latency", "Анализируем задержку")
        case .download: return language.text("Measuring download", "Измеряем загрузку")
        case .upload: return language.text("Measuring upload", "Измеряем отдачу")
        case .finished: return language.text("Test complete", "Проверка завершена")
        case .failed: return language.text("Unable to test network", "Не удалось проверить сеть")
        }
    }

    private var phaseSubtitle: String {
        switch model.phase {
        case .idle: return language.text("Press the button to start", "Нажмите кнопку, чтобы начать")
        case .ping: return language.text("16 reference measurements", "16 контрольных измерений")
        case .download: return language.text("Measuring sustained download speed", "Измеряем устойчивую скорость загрузки")
        case .upload: return language.text("Measuring sustained upload speed", "Измеряем устойчивую скорость отдачи")
        case .finished:
            return model.showsSavedConfirmation
                ? language.text("Result saved to history", "Результат сохранён в истории")
                : ""
        case .failed: return language.text("Check your connection and try again", "Проверьте подключение и повторите")
        }
    }

    private var buttonTitle: String {
        if model.isRunning { return language.text("Stop", "Остановить") }
        return model.phase == .finished
            ? language.text("Test again", "Проверить снова")
            : language.text("Start test", "Начать тест")
    }

    private func closePanel() {
        withAnimation(.easeInOut(duration: 0.62)) {
            showsHistory = false
            showsSettings = false
        }
    }

    private func formatted(_ value: Double, decimals: Int) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)))
    }
}

private struct WavyGaugeArc: Shape {
    var progress: Double
    let phase: Double
    let growsFromBottom: Bool

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        var path = Path()

        func point(at degrees: Double, anchorFade: Double = 1) -> CGPoint {
            let radians = degrees * .pi / 180
            let waveAngle = radians - (.pi / 2)
            let primaryWave = sin(waveAngle * 6 + phase) * 7.2
            let secondaryWave = sin(waveAngle * 3 + phase * 0.5) * 1.4
            let radius = baseRadius + (primaryWave + secondaryWave) * anchorFade
            return CGPoint(
                x: center.x + cos(radians) * radius,
                y: center.y + sin(radians) * radius
            )
        }

        func addArc(
            from start: Double,
            through sweep: Double,
            fixedStart: Bool = false,
            fixedSeam: Bool = false
        ) {
            let steps = max(Int(abs(sweep) * 2.4), 24)
            for index in 0...steps {
                let fraction = Double(index) / Double(steps)
                let current = start + sweep * fraction
                let startFade = fixedStart ? min(fraction * 7, 1) : 1
                let seamFade = fixedSeam
                    ? min(min(fraction * 7, (1 - fraction) * 7), 1)
                    : 1
                let fade = min(startFade, seamFade)
                let currentPoint = point(at: current, anchorFade: fade)
                if index == 0 {
                    path.move(to: currentPoint)
                } else {
                    path.addLine(to: currentPoint)
                }
            }
        }

        if growsFromBottom {
            addArc(from: 90, through: 360 * min(progress, 1), fixedStart: true)
        } else {
            addArc(from: 90, through: 360, fixedSeam: true)
            path.closeSubpath()
        }
        return path
    }
}

private struct MetricCard: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(M3.muted)
            Text(value > 0
                 ? value.formatted(.number.precision(.fractionLength(unit == "ms" ? 0 : 1)))
                 : "—")
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(unit)
                .font(.system(size: 10))
                .foregroundStyle(M3.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(M3.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .animation(.easeInOut(duration: 0.25), value: value)
    }
}

private struct M3ButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SettingsPanel: View {
    @Binding var languageRaw: String
    let language: AppLanguage
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(M3.muted.opacity(0.45))
                .frame(width: 32, height: 4)
                .padding(.top, 8)

            ZStack {
                Text(language.text("Settings", "Настройки"))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))

                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(M3.secondary)
                            .frame(width: 40, height: 40)
                            .background(M3.surfaceHigh, in: Circle())
                    }
                    .buttonStyle(M3ButtonStyle())
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 12) {
                Text(language.text("Language", "Язык"))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Picker("", selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(option.name).tag(option.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                Text(language.text(
                    "The interface language changes immediately and is saved for the next launch.",
                    "Язык интерфейса меняется сразу и сохраняется для следующего запуска."
                ))
                .font(.system(size: 11))
                .foregroundStyle(M3.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(M3.surfaceHigh.opacity(0.7), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.top, 24)

            Spacer()
        }
        .frame(height: 280)
        .background(M3.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
    }
}

private struct HistoryPanel: View {
    @ObservedObject var model: SpeedTestModel
    let language: AppLanguage
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(M3.muted.opacity(0.45))
                .frame(width: 32, height: 4)
                .padding(.top, 8)

            ZStack {
                VStack(spacing: 8) {
                    Text(language.text("History", "История"))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Text(language.text("Last 30 tests", "Последние 30 проверок"))
                        .font(.system(size: 11))
                        .foregroundStyle(M3.muted)
                }

                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(M3.secondary)
                            .frame(width: 40, height: 40)
                            .background(M3.surfaceHigh, in: Circle())
                    }
                    .buttonStyle(M3ButtonStyle())
                }
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)

            if model.history.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 28))
                        .foregroundStyle(M3.primary)
                    Text(language.text("No results yet", "Пока нет результатов"))
                        .font(.system(size: 15, weight: .semibold))
                    Text(language.text("Completed tests will appear here", "Завершённые тесты появятся здесь"))
                        .font(.system(size: 12))
                        .foregroundStyle(M3.muted)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.history) { result in
                            HistoryRow(result: result, language: language)
                        }
                    }
                    .padding(.top, 14)
                }
                .scrollIndicators(.hidden)

                Button(language.text("Clear history", "Очистить историю"), role: .destructive) {
                    model.clearHistory()
                }
                .buttonStyle(M3ButtonStyle())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(M3.error)
                .padding(.vertical, 12)
            }
        }
        .frame(height: 480)
        .background(M3.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
    }
}

private struct HistoryRow: View {
    let result: SpeedResult
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(result.date.formatted(
                    .dateTime
                        .locale(language.locale)
                        .year()
                        .month(.abbreviated)
                        .day()
                        .hour()
                        .minute()
                ))
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }

            HStack(spacing: 22) {
                HistoryMetric(label: language.text("Download", "Загрузка"), value: result.download, unit: "Mbps")
                HistoryMetric(label: language.text("Upload", "Отдача"), value: result.upload, unit: "Mbps")
                HistoryMetric(label: "Ping", value: result.ping, unit: "ms")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            M3.surfaceHigh.opacity(0.7),
            in: RoundedRectangle(cornerRadius: 50, style: .continuous)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

private struct HistoryMetric: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(M3.muted)
            Text(value.formatted(.number.precision(.fractionLength(unit == "ms" ? 0 : 1))))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(M3.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

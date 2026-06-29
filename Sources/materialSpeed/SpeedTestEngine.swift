import Foundation
import SwiftUI

struct SpeedResult: Codable, Identifiable {
    let id: UUID
    let date: Date
    let ping: Double
    let jitter: Double
    let download: Double
    let upload: Double

    init(ping: Double, jitter: Double, download: Double, upload: Double) {
        id = UUID()
        date = Date()
        self.ping = ping
        self.jitter = jitter
        self.download = download
        self.upload = upload
    }
}

enum TestPhase: Equatable {
    case idle
    case ping
    case download
    case upload
    case finished
    case failed(String)

    var title: String {
        switch self {
        case .idle: return "Скорость"
        case .ping: return "Анализируем задержку"
        case .download: return "Измеряем загрузку"
        case .upload: return "Измеряем отдачу"
        case .finished: return "Проверка завершена"
        case .failed(let message): return message
        }
    }
}

@MainActor
final class SpeedTestModel: ObservableObject {
    @Published var phase: TestPhase = .idle
    @Published var ping = 0.0
    @Published var jitter = 0.0
    @Published var download = 0.0
    @Published var upload = 0.0
    @Published var progress = 0.0
    @Published var history: [SpeedResult] = []
    @Published var showsSavedConfirmation = false

    private let historyKey = "pulse.speed.history.v1"
    private var activeTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([SpeedResult].self, from: data) {
            history = saved
        }
    }

    var isRunning: Bool {
        switch phase {
        case .ping, .download, .upload: return true
        default: return false
        }
    }

    func toggleTest() {
        if isRunning {
            activeTask?.cancel()
            reset()
            return
        }

        ping = 0
        jitter = 0
        download = 0
        upload = 0
        progress = 0
        showsSavedConfirmation = false

        activeTask = Task {
            do {
                phase = .ping
                let latency = try await SpeedTestEngine.measureLatency { [weak self] value, partialProgress in
                    Task { @MainActor in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self?.ping = value
                            self?.progress = partialProgress * 0.18
                        }
                    }
                }
                try Task.checkCancellation()
                ping = latency.ping
                jitter = latency.jitter

                phase = .download
                let down = try await SpeedTestEngine.measureDownload { [weak self] value, partialProgress in
                    Task { @MainActor in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self?.download = value
                            self?.progress = 0.18 + partialProgress * 0.45
                        }
                    }
                }
                try Task.checkCancellation()
                download = down

                phase = .upload
                let up = try await SpeedTestEngine.measureUpload { [weak self] value, partialProgress in
                    Task { @MainActor in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self?.upload = value
                            self?.progress = 0.63 + partialProgress * 0.37
                        }
                    }
                }
                try Task.checkCancellation()
                upload = up
                progress = 1
                phase = .finished
                saveResult()
                showsSavedConfirmation = true
                try await Task.sleep(for: .seconds(5))
                try Task.checkCancellation()
                withAnimation(.easeInOut(duration: 0.45)) {
                    showsSavedConfirmation = false
                }
            } catch is CancellationError {
                reset()
            } catch {
                phase = .failed("Не удалось проверить сеть")
                progress = 0
            }
        }
    }

    func clearHistory() {
        history = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    private func saveResult() {
        history.insert(
            SpeedResult(ping: ping, jitter: jitter, download: download, upload: upload),
            at: 0
        )
        history = Array(history.prefix(30))
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func reset() {
        activeTask?.cancel()
        activeTask = nil
        phase = .idle
        progress = 0
        ping = 0
        jitter = 0
        download = 0
        upload = 0
        showsSavedConfirmation = false
    }
}

private actor TransferMeter {
    let started = ContinuousClock.now
    let warmup: Double
    let duration: Double
    private var measuredBytes = 0

    init(warmup: Double, duration: Double) {
        self.warmup = warmup
        self.duration = duration
    }

    func record(_ bytes: Int) -> (speed: Double, progress: Double, done: Bool) {
        let elapsed = Self.seconds(started.duration(to: .now))
        if elapsed >= warmup {
            measuredBytes += bytes
        }
        let measuredTime = max(elapsed - warmup, 0.001)
        let speed = Double(measuredBytes) * 8 / measuredTime / 1_000_000
        let progress = min(elapsed / duration, 1)
        return (speed, progress, elapsed >= duration)
    }

    func current() -> (speed: Double, progress: Double, done: Bool) {
        record(0)
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}

enum SpeedTestEngine {
    private static let host = "https:" + "/speed.cloudflare.com"

    static func measureLatency(
        update: @escaping @Sendable (Double, Double) -> Void
    ) async throws -> (ping: Double, jitter: Double) {
        let session = makeSession(timeout: 5)
        var samples: [Double] = []

        for index in 0..<16 {
            try Task.checkCancellation()
            let url = URL(string: "\(host)/__down?bytes=0&t=\(UUID().uuidString)")!
            let start = ContinuousClock.now
            let (_, response) = try await session.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let milliseconds = seconds(start.duration(to: .now)) * 1000
            if index > 1 { samples.append(milliseconds) }
            if !samples.isEmpty {
                update(median(samples), Double(index + 1) / 16)
            }
            try await Task.sleep(for: .milliseconds(110))
        }

        let sorted = samples.sorted()
        let trimmed = Array(sorted.dropFirst(2).dropLast(2))
        let ping = median(trimmed)
        let differences = zip(trimmed.dropFirst(), trimmed).map { abs($0 - $1) }
        let jitter = differences.reduce(0, +) / Double(max(differences.count, 1))
        return (ping, jitter)
    }

    static func measureDownload(
        update: @escaping @Sendable (Double, Double) -> Void
    ) async throws -> Double {
        let session = makeSession(timeout: 12)
        let meter = TransferMeter(warmup: 2.0, duration: 14.0)
        let chunkSize = 2_000_000

        return try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<6 {
                group.addTask {
                    while true {
                        try Task.checkCancellation()
                        let state = await meter.current()
                        if state.done { break }

                        let url = URL(string: "\(host)/__down?bytes=\(chunkSize)&t=\(UUID().uuidString)")!
                        let (data, response) = try await session.data(from: url)
                        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                            throw URLError(.badServerResponse)
                        }
                        let reading = await meter.record(data.count)
                        if reading.progress > 0.14 {
                            update(reading.speed, reading.progress)
                        }
                    }
                }
            }
            try await group.waitForAll()
            let final = await meter.current()
            return final.speed
        }
    }

    static func measureUpload(
        update: @escaping @Sendable (Double, Double) -> Void
    ) async throws -> Double {
        let session = makeSession(timeout: 20)
        let meter = TransferMeter(warmup: 1.5, duration: 14.0)
        let chunkSize = 512_000
        let payload = Data(repeating: 0xA5, count: chunkSize)

        return try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    while true {
                        try Task.checkCancellation()
                        let state = await meter.current()
                        if state.done { break }

                        do {
                            var request = URLRequest(url: URL(string: "\(host)/__up?t=\(UUID().uuidString)")!)
                            request.httpMethod = "POST"
                            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                            request.setValue(String(chunkSize), forHTTPHeaderField: "Content-Length")
                            let (_, response) = try await session.upload(for: request, from: payload)
                            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                                continue
                            }
                            let reading = await meter.record(chunkSize)
                            update(reading.speed, reading.progress)
                        } catch is CancellationError {
                            throw CancellationError()
                        } catch {
                            let reading = await meter.current()
                            update(reading.speed, reading.progress)
                        }
                    }
                }
            }
            try await group.waitForAll()
            let final = await meter.current()
            guard final.speed > 0 else {
                throw URLError(.cannotConnectToHost)
            }
            return final.speed
        }
    }

    private static func makeSession(timeout: TimeInterval) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpMaximumConnectionsPerHost = 8
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }

    private static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}

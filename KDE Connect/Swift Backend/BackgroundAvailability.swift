/*
 * SPDX-FileCopyrightText: 2026 LaskyWolf
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

#if !os(macOS)

import AppIntents
import BackgroundTasks
import OSLog
import SwiftUI

extension Notification.Name {
    static let backgroundAvailabilityFailedToStart = Notification.Name("backgroundAvailabilityFailedToStart")
}

/// How far the file transfers of one or more devices have come.
struct TransferProgress: Equatable {
    static let unitsPerFile: Int64 = 1000

    var totalFiles = 0
    var finishedFiles = 0
    /// Sum of the fractions (0...1) completed of the files being transferred now.
    var inFlightFraction = 0.0

    var isActive: Bool { totalFiles > 0 }
    var totalUnits: Int64 { Int64(totalFiles) * Self.unitsPerFile }
    /// Grows from file to file, so finishing a file never moves the progress backwards.
    var completedUnits: Int64 {
        min(Int64(finishedFiles) * Self.unitsPerFile
            + Int64(inFlightFraction * Double(Self.unitsPerFile)),
            totalUnits)
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(totalFiles: lhs.totalFiles + rhs.totalFiles,
             finishedFiles: lhs.finishedFiles + rhs.finishedFiles,
             inFlightFraction: lhs.inFlightFraction + rhs.inFlightFraction)
    }

    static func fraction(of file: FileTransferItemInfo) -> Double {
        let completed = Double(file.totalBytesCompleted)
        if let total = file.totalBytes {
            return completed / Double(max(total, 1))
        }
        // Unknown size: keeps growing with the data received, without ever reaching 1.
        return completed / (completed + 1_048_576)
    }
}

extension Share {
    var transferProgress: TransferProgress {
        let inFlight = currentFilesSending.values.map(TransferProgress.fraction(of:))
        + currentFilesReceiving.values.map(TransferProgress.fraction(of:))
        return TransferProgress(
            totalFiles: totalNumOfFilesToSend + totalNumOfFilesToReceive,
            finishedFiles: numFilesSuccessfullySent + numFilesReceived,
            inFlightFraction: inFlight.reduce(0, +)
        )
    }
}

/// What a running session does at each tick. A transfer outlasts the countdown.
enum BackgroundAvailabilityStep: Equatable {
    case transferring(TransferProgress)
    case waiting(remaining: TimeInterval)
    case finished

    init(transfer: TransferProgress, elapsed: TimeInterval, duration: TimeInterval) {
        if transfer.isActive {
            self = .transferring(transfer)
        } else if elapsed < duration {
            self = .waiting(remaining: duration - elapsed)
        } else {
            self = .finished
        }
    }
}

/// The text of the Live Activity.
struct BackgroundAvailabilityStatus: Equatable {
    let title: String
    let subtitle: String

    init(connectedDevices: [String], step: BackgroundAvailabilityStep, latestFile: String?) {
        switch connectedDevices.count {
        case 0:
            title = NSLocalizedString("Waiting for a device", comment: "Live Activity title when no device is connected")
        case 1:
            title = String(format: NSLocalizedString("Connected to %@", comment: "Live Activity title with the connected device"),
                           connectedDevices[0])
        default:
            title = String(format: NSLocalizedString("Connected to %d devices", comment: "Live Activity title"),
                           connectedDevices.count)
        }

        var parts = [String]()
        switch step {
        case .transferring(let progress):
            parts.append(String(format: NSLocalizedString("File %1$d of %2$d", comment: "Live Activity subtitle during a file transfer"),
                                min(progress.finishedFiles + 1, progress.totalFiles),
                                progress.totalFiles))
        case .waiting(let remaining):
            parts.append(String(format: NSLocalizedString("%d min left", comment: "Live Activity subtitle while waiting for files"),
                                Int((remaining / 60).rounded(.up))))
        case .finished:
            break
        }
        if let latestFile {
            parts.append(String(format: NSLocalizedString("Latest: %@", comment: "Live Activity subtitle with the last received file"),
                                latestFile))
        }
        subtitle = parts.joined(separator: " · ")
    }
}

/// Keeps the app's connections open in the background for a limited time, shown in a Live Activity.
///
/// iOS only runs this for work that a person starts from the foreground and that reports progress:
/// sending files, or the countdown of "Stay Available", which can turn into a transfer from the
/// remote device. iOS may still stop it at any time, and closing the app in the app switcher ends it.
@available(iOS 26.0, *)
final class BackgroundAvailability: ObservableObject {
    static let shared = BackgroundAvailability()
    static let stayAvailableDuration: TimeInterval = 15 * 60
    private static let startTimeout: TimeInterval = 5

    @Published private(set) var isStayingAvailable = false
    /// Whether connections should stay open when the app moves to the background.
    var isRunning: Bool { isStarting || task != nil }

    private var isStarting = false
    private var task: BGContinuedProcessingTask?
    private var timer: Timer?
    private var startDate = Date()
    private var duration: TimeInterval = 0
    private var status: BackgroundAvailabilityStatus?
    private var latestFile: String?
    private var isToggleWaitingForForeground = false
    private let logger = Logger()

    private init() {}

    /// Starts staying available, and tells the person if iOS refuses to.
    func stayAvailable() {
        startDate = Date()
        duration = Self.stayAvailableDuration
        isStayingAvailable = isRunning || submit()
        if !isStayingAvailable {
            NotificationCenter.default.post(name: .backgroundAvailabilityFailedToStart, object: nil)
        }
    }

    /// iOS only starts the session from the foreground, which the app may not have reached yet.
    func toggleFromIntent() {
        if isStayingAvailable {
            stopStayingAvailable()
        } else {
            isToggleWaitingForForeground = true
            startToggleIfActive()
        }
    }

    func startToggleIfActive() {
        guard isToggleWaitingForForeground, UIApplication.shared.applicationState == .active else { return }
        isToggleWaitingForForeground = false
        stayAvailable()
    }

    func noteFileReceived(_ filename: String) {
        latestFile = filename
        tick()
    }

    /// Stops the countdown. Transfers in progress can still finish.
    func stopStayingAvailable() {
        duration = 0
        isStayingAvailable = false
        tick()
    }

    /// Lets the files that the person is about to send finish in the background.
    func coverFileTransfer() {
        if !isRunning {
            _ = submit()
        }
    }

    private func submit() -> Bool {
        // Registering an identifier missing from Info.plist would crash the app.
        let permitted = Bundle.main.object(forInfoDictionaryKey: "BGTaskSchedulerPermittedIdentifiers") as? [String]
        guard let wildcard = permitted?.first(where: { $0.hasSuffix(".*") }) else {
            logger.fault("Info.plist doesn't permit a wildcard background task identifier")
            return false
        }
        let identifier = String(wildcard.dropLast()) + UUID().uuidString

        guard BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main, launchHandler: { [weak self] task in
            guard let self, let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.run(task)
        }) else {
            logger.fault("Failed to register background task \(identifier, privacy: .public)")
            return false
        }

        let request = BGContinuedProcessingTaskRequest(
            identifier: identifier,
            title: "KDE Connect",
            subtitle: NSLocalizedString("Starting…", comment: "Live Activity subtitle while the background session starts")
        )
        // Waiting in a queue is useless: the person is about to leave the app.
        request.strategy = .fail
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            logger.fault("Failed to submit background task: \(error.localizedDescription, privacy: .public)")
            return false
        }

        isStarting = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.startTimeout) { [weak self] in
            guard let self, self.isStarting else { return }
            self.logger.error("Background task did not start in time")
            self.finish(success: false)
        }
        return true
    }

    private func run(_ task: BGContinuedProcessingTask) {
        isStarting = false
        self.task = task
        task.expirationHandler = { [weak self] in
            DispatchQueue.main.async { self?.finish(success: false) }
        }
        tick()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        guard let task else { return }
        let transfer = backgroundService._devices.values
            .compactMap { ($0._plugins[.share] as? Share)?.transferProgress }
            .reduce(TransferProgress(), +)
        let elapsed = Date().timeIntervalSince(startDate)
        let step = BackgroundAvailabilityStep(transfer: transfer, elapsed: elapsed, duration: duration)

        switch step {
        case .transferring(let progress):
            task.progress.totalUnitCount = progress.totalUnits
            task.progress.completedUnitCount = progress.completedUnits
        case .waiting:
            task.progress.totalUnitCount = Int64(duration)
            task.progress.completedUnitCount = Int64(elapsed)
        case .finished:
            finish(success: true)
            return
        }

        let connectedDevices = backgroundService._devices.values
            .filter { $0.isReachable() && $0.isPaired() }
            .map { $0._deviceInfo.name }
            .sorted()
        let newStatus = BackgroundAvailabilityStatus(connectedDevices: connectedDevices, step: step, latestFile: latestFile)
        if newStatus != status {
            status = newStatus
            task.updateTitle(newStatus.title, subtitle: newStatus.subtitle)
        }
    }

    private func finish(success: Bool) {
        timer?.invalidate()
        timer = nil
        task?.setTaskCompleted(success: success)
        task = nil
        isStarting = false
        duration = 0
        status = nil
        isStayingAvailable = false
        if UIApplication.shared.applicationState == .background {
            // The app is about to be suspended, same as when it enters the background normally.
            backgroundService.stopDiscovery()
        }
    }
}

/// A menu item that starts or stops staying available.
@available(iOS 26.0, *)
struct StayAvailableMenuItem: View {
    @ObservedObject private var availability = BackgroundAvailability.shared

    var body: some View {
        if availability.isStayingAvailable {
            Button {
                availability.stopStayingAvailable()
            } label: {
                Label("Stop Staying Available", systemImage: "antenna.radiowaves.left.and.right.slash")
            }
        } else {
            Button {
                availability.stayAvailable()
            } label: {
                Label("Stay Available for 15 Minutes", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
    }
}

/// Lets the Shortcuts app, Control Center and the Action Button start or stop staying available.
@available(iOS 26.0, *)
struct ToggleStayAvailableIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Stay Available"
    static let description = IntentDescription("Keeps KDE Connect reachable for 15 minutes after you leave the app, or stops doing so.")
    /// iOS only starts the background session while the app is in the foreground.
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        BackgroundAvailability.shared.toggleFromIntent()
        return .result()
    }
}

@available(iOS 26.0, *)
struct KDEConnectShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleStayAvailableIntent(),
            phrases: ["Toggle Stay Available in \(.applicationName)"],
            shortTitle: "Stay Available",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
    }
}

#endif

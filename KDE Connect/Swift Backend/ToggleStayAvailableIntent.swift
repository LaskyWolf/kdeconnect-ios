/*
 * SPDX-FileCopyrightText: 2026 LaskyWolf
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

#if !os(macOS)

import AppIntents
import Foundation

/// Lets the Shortcuts app, Control Center and the Action Button start or stop staying available.
///
/// This file belongs to both the app and the control extension, because iOS only opens the app
/// from a control when both contain the intent.
@available(iOS 26.0, *)
struct ToggleStayAvailableIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Stay Available"
    static let description = IntentDescription("Keeps KDE Connect reachable for 15 minutes after you leave the app, or stops doing so.")
    /// iOS only starts the background session while the app is in the foreground.
    static let openAppWhenRun = true
    static let url = URL(string: "kdeconnect-ios://toggle-stay-available")!

#if STAY_AVAILABLE_CONTROL
    /// Runs if iOS keeps the intent in the extension, which can't reach the app's state.
    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(Self.url))
    }
#else
    @MainActor
    func perform() async throws -> some IntentResult {
        BackgroundAvailability.shared.toggleFromIntent()
        return .result()
    }
#endif
}

#endif

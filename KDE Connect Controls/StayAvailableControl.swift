/*
 * SPDX-FileCopyrightText: 2026 LaskyWolf
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

import AppIntents
import SwiftUI
import WidgetKit

@main
struct KDEConnectControls: WidgetBundle {
    var body: some Widget {
        StayAvailableControl()
    }
}

/// A button, not a toggle: the extension can't read whether the app is staying available.
struct StayAvailableControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "org.kde.kdeconnect.controls.stay-available") {
            ControlWidgetButton(action: ToggleStayAvailableIntent()) {
                Label("Stay Available", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
        .displayName("Stay Available")
        .description("Opens KDE Connect and keeps it reachable for 15 minutes, or stops doing so.")
    }
}

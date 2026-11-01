/*
 * SPDX-FileCopyrightText: 2021 Lucas Wang <lucas.wang@tuta.io>
 *
 * SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
 */

// Original header below:
//
//  AppIconPicker.swift
//  KDE Connect
//
//  Created by Apollo Zhu on 2/24/22.
//

#if !os(macOS)

import SwiftUI

enum AppIcon: RawRepresentable, CaseIterable {
    case `default`
    case classic
    case roundedRectangle
    
    init?(rawValue: String?) {
        switch rawValue {
        case nil:
            self = .default
        case "AppIcon-Classic":
            self = .classic
        case "AppIcon-RoundedRectangle":
            self = .roundedRectangle
        default:
            return nil
        }
    }
    
    var rawValue: String? {
        switch self {
        case .default:
            return nil
        case .classic:
            return "AppIcon-Classic"
        case .roundedRectangle:
            return "AppIcon-RoundedRectangle"
        }
    }
    
    var name: Text {
        switch self {
        case .default:
            return Text("Default")
        case .classic:
            return Text("Classic")
        case .roundedRectangle:
            return Text("Rounded Rectangle")
        }
    }
    
    /// Separate image sets, because alternate app icons can't be loaded by name from the asset catalog.
    var previewImageName: String {
        "\(rawValue ?? "AppIcon")Preview"
    }

    var image60x60: some View {
        Image(previewImageName)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AppIconPicker: View {
    @EnvironmentObject var settings: KdeConnectSettings
    @EnvironmentObject var alertManager: AlertManager
    
    var body: some View {
        List {
            ForEach(AppIcon.allCases, id: \.self) { icon in
                Button {
                    settings.appIcon = icon
                    UIApplication.shared.setAlternateIconName(icon.rawValue) { error in
                        guard let error = error else { return }
                        alertManager.queueAlert(prioritize: true,
                                                title: "Failed to Change Icon") {
                            Text(error.localizedDescription)
                        }
                    }
                } label: {
                    AccessibleHStack(spacing: 16) {
                        icon.image60x60
                        icon.name
                            .foregroundColor(.primary)
                        Spacer()
                        if icon == settings.appIcon {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .accessibilityLabel("App Icon")
                .accessibilityValue(icon.name)
                .accessibilityAddTraits(icon == settings.appIcon ? .isSelected : [])
            }
        }
        .navigationTitle("Choose App Icon")
    }
}

struct AppIconPicker_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AppIconPicker()
                .environmentObject(KdeConnectSettings.shared)
        }
    }
}

#endif

//
//  AppMetadata.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import Foundation

struct AppMetadata {
    let bundleIdentifier: String?
    let bundleVersion: String?           // CFBundleShortVersionString
    let buildNumber: String?             // CFBundleVersion
    let minimumSystemVersion: String?    // LSMinimumSystemVersion
    let architectures: [String]          // arm64, x86_64, etc.
    let appName: String

    var architectureDescription: String {
        if architectures.isEmpty {
            return "Unknown"
        }
        if architectures.contains("arm64") && architectures.contains("x86_64") {
            return "Universal (Apple Silicon & Intel)"
        }
        if architectures.contains("arm64") {
            return "Apple Silicon"
        }
        if architectures.contains("x86_64") {
            return "Intel"
        }
        return architectures.joined(separator: ", ")
    }

    func generateSystemRequirementsText() -> String {
        var lines: [String] = []

        lines.append("System Requirements")
        lines.append("==================")
        lines.append("")

        if let minOS = minimumSystemVersion {
            lines.append("Minimum macOS Version: \(minOS)")
        }

        lines.append("Architecture: \(architectureDescription)")

        if let version = bundleVersion {
            lines.append("")
            lines.append("App Version: \(version)")
        }

        if let build = buildNumber, build != bundleVersion {
            lines.append("Build: \(build)")
        }

        return lines.joined(separator: "\n")
    }
}

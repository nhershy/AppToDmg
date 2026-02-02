//
//  MetadataExtractor.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import Foundation

struct MetadataExtractor {

    static func extractMetadata(from appURL: URL) async -> AppMetadata? {
        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")

        guard let plistData = try? Data(contentsOf: infoPlistURL),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }

        let bundleIdentifier = plist["CFBundleIdentifier"] as? String
        let bundleVersion = plist["CFBundleShortVersionString"] as? String
        let buildNumber = plist["CFBundleVersion"] as? String
        let minimumSystemVersion = plist["LSMinimumSystemVersion"] as? String
        let executableName = plist["CFBundleExecutable"] as? String
        let appName = appURL.deletingPathExtension().lastPathComponent

        // Detect architectures using lipo
        var architectures: [String] = []
        if let execName = executableName {
            let executableURL = appURL.appendingPathComponent("Contents/MacOS/\(execName)")
            architectures = await detectArchitectures(executableURL: executableURL)
        }

        return AppMetadata(
            bundleIdentifier: bundleIdentifier,
            bundleVersion: bundleVersion,
            buildNumber: buildNumber,
            minimumSystemVersion: minimumSystemVersion,
            architectures: architectures,
            appName: appName
        )
    }

    private static func detectArchitectures(executableURL: URL) async -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-info", executableURL.path]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            return []
        }

        // Parse lipo output: "Architectures in the fat file: /path are: x86_64 arm64"
        // or "Non-fat file: /path is architecture: arm64"
        var architectures: [String] = []

        if output.contains("are:") {
            if let archPart = output.components(separatedBy: "are:").last {
                architectures = archPart
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
            }
        } else if output.contains("is architecture:") {
            if let archPart = output.components(separatedBy: "is architecture:").last {
                let arch = archPart.trimmingCharacters(in: .whitespacesAndNewlines)
                if !arch.isEmpty {
                    architectures = [arch]
                }
            }
        }

        return architectures
    }
}

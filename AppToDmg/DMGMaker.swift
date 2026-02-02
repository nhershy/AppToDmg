//
//  DMGMaker.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import Foundation

enum DMGError: LocalizedError {
    case invalidAppBundle
    case copyFailed(String)
    case symlinkFailed(String)
    case hdiutilFailed(exitCode: Int32, output: String)

    var errorDescription: String? {
        switch self {
        case .invalidAppBundle:
            return "The selected item is not a valid application bundle."
        case .copyFailed(let reason):
            return "Could not copy the application. \(reason)"
        case .symlinkFailed(let reason):
            return "Could not create the Applications shortcut. \(reason)"
        case .hdiutilFailed(let exitCode, let output):
            return "DMG creation failed (exit code \(exitCode)): \(output)"
        }
    }
}

actor DMGMaker {

    func createDMG(
        appURL: URL,
        outputURL: URL,
        volumeName: String,
        includeApplicationsLink: Bool,
        outputHandler: @escaping @MainActor (String) -> Void
    ) async throws {
        // Validate input is an app bundle
        guard appURL.pathExtension == "app" else {
            throw DMGError.invalidAppBundle
        }

        let fileManager = FileManager.default

        // Verify app bundle exists
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: appURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw DMGError.invalidAppBundle
        }

        // Create staging directory
        let stagingDir = fileManager.temporaryDirectory
            .appendingPathComponent("AppToDmg-\(UUID().uuidString)")

        await outputHandler("Creating staging directory...")

        do {
            try fileManager.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        } catch {
            throw DMGError.copyFailed("Could not create staging directory: \(error.localizedDescription)")
        }

        defer {
            // Cleanup staging directory
            try? fileManager.removeItem(at: stagingDir)
        }

        // Copy app bundle to staging
        let appName = appURL.lastPathComponent
        let stagedAppURL = stagingDir.appendingPathComponent(appName)

        await outputHandler("Copying \(appName) to staging area...")

        do {
            try fileManager.copyItem(at: appURL, to: stagedAppURL)
        } catch {
            throw DMGError.copyFailed(error.localizedDescription)
        }

        // Create Applications symlink if requested
        if includeApplicationsLink {
            let applicationsLink = stagingDir.appendingPathComponent("Applications")

            await outputHandler("Creating Applications shortcut...")

            do {
                try fileManager.createSymbolicLink(
                    at: applicationsLink,
                    withDestinationURL: URL(fileURLWithPath: "/Applications")
                )
            } catch {
                throw DMGError.symlinkFailed(error.localizedDescription)
            }
        }

        // Remove existing output file if present
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        // Create DMG using hdiutil
        await outputHandler("Creating DMG image...")

        let result = await runHdiutil(
            stagingDir: stagingDir,
            outputURL: outputURL,
            volumeName: volumeName,
            outputHandler: outputHandler
        )

        if result.exitCode != 0 {
            throw DMGError.hdiutilFailed(exitCode: result.exitCode, output: result.output)
        }

        await outputHandler("DMG created successfully!")
    }

    private func runHdiutil(
        stagingDir: URL,
        outputURL: URL,
        volumeName: String,
        outputHandler: @escaping @MainActor (String) -> Void
    ) async -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "create",
            "-volname", volumeName,
            "-srcfolder", stagingDir.path,
            "-ov",
            "-format", "UDZO",
            outputURL.path
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return (-1, "Failed to launch hdiutil: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if let outputStr = String(data: outputData, encoding: .utf8), !outputStr.isEmpty {
            await outputHandler(outputStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let errorStr = String(data: errorData, encoding: .utf8), !errorStr.isEmpty {
            await outputHandler(errorStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let combinedOutput = String(data: outputData + errorData, encoding: .utf8) ?? ""
        return (process.terminationStatus, combinedOutput)
    }
}

//
//  DMGMaker.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import Foundation
import AppKit

enum DMGError: LocalizedError {
    case invalidAppBundle
    case copyFailed(String)
    case symlinkFailed(String)
    case hdiutilFailed(exitCode: Int32, output: String)
    case stylingFailed(String)
    case backgroundGenerationFailed
    case fileWriteFailed(String)

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
        case .stylingFailed(let reason):
            return "DMG styling failed: \(reason)"
        case .backgroundGenerationFailed:
            return "Failed to generate background image."
        case .fileWriteFailed(let reason):
            return "Could not write file: \(reason)"
        }
    }
}

enum ReadmeContent {
    case file(URL)
    case text(String)
}

actor DMGMaker {

    // DMG window and icon layout constants
    private let windowWidth: CGFloat = 540
    private let windowHeight: CGFloat = 380
    private let iconSize: Int = 128
    private let appIconX: Int = 130
    private let appIconY: Int = 190
    private let applicationsIconX: Int = 410
    private let applicationsIconY: Int = 190

    func createDMG(
        appURL: URL,
        outputURL: URL,
        volumeName: String,
        includeApplicationsLink: Bool,
        systemRequirementsText: String? = nil,
        readmeContent: ReadmeContent? = nil,
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

        // Write System Requirements.txt if provided
        if let sysReqText = systemRequirementsText {
            let sysReqURL = stagingDir.appendingPathComponent("System Requirements.txt")
            await outputHandler("Adding System Requirements.txt...")

            do {
                try sysReqText.write(to: sysReqURL, atomically: true, encoding: .utf8)
            } catch {
                throw DMGError.fileWriteFailed("System Requirements.txt: \(error.localizedDescription)")
            }
        }

        // Write README.txt if provided
        if let readme = readmeContent {
            let readmeURL = stagingDir.appendingPathComponent("README.txt")
            await outputHandler("Adding README.txt...")

            do {
                switch readme {
                case .file(let sourceURL):
                    let content = try String(contentsOf: sourceURL, encoding: .utf8)
                    try content.write(to: readmeURL, atomically: true, encoding: .utf8)
                case .text(let text):
                    try text.write(to: readmeURL, atomically: true, encoding: .utf8)
                }
            } catch {
                throw DMGError.fileWriteFailed("README.txt: \(error.localizedDescription)")
            }
        }

        // Remove existing output file if present
        if fileManager.fileExists(atPath: outputURL.path) {
            try? fileManager.removeItem(at: outputURL)
        }

        // Create DMG - use styled approach if Applications link is included
        if includeApplicationsLink {
            try await createStyledDMG(
                stagingDir: stagingDir,
                outputURL: outputURL,
                volumeName: volumeName,
                appName: appName,
                outputHandler: outputHandler
            )
        } else {
            // Simple DMG without styling
            await outputHandler("Creating DMG image...")

            let result = await runHdiutil(arguments: [
                "create",
                "-volname", volumeName,
                "-srcfolder", stagingDir.path,
                "-ov",
                "-format", "UDZO",
                outputURL.path
            ], outputHandler: outputHandler)

            if result.exitCode != 0 {
                throw DMGError.hdiutilFailed(exitCode: result.exitCode, output: result.output)
            }
        }

        await outputHandler("DMG created successfully!")
    }

    // MARK: - Styled DMG Creation

    private func createStyledDMG(
        stagingDir: URL,
        outputURL: URL,
        volumeName: String,
        appName: String,
        outputHandler: @escaping @MainActor (String) -> Void
    ) async throws {
        let fileManager = FileManager.default
        let tempDMGURL = fileManager.temporaryDirectory
            .appendingPathComponent("AppToDmg-temp-\(UUID().uuidString).dmg")

        defer {
            try? fileManager.removeItem(at: tempDMGURL)
        }

        // Step 1: Create read-write DMG
        await outputHandler("Creating read-write DMG...")

        var result = await runHdiutil(arguments: [
            "create",
            "-volname", volumeName,
            "-srcfolder", stagingDir.path,
            "-ov",
            "-format", "UDRW",
            tempDMGURL.path
        ], outputHandler: outputHandler)

        if result.exitCode != 0 {
            throw DMGError.hdiutilFailed(exitCode: result.exitCode, output: result.output)
        }

        // Step 2: Mount the DMG
        await outputHandler("Mounting DMG for styling...")

        let mountPoint = "/Volumes/\(volumeName)"

        result = await runHdiutil(arguments: [
            "attach",
            tempDMGURL.path,
            "-mountpoint", mountPoint,
            "-nobrowse"
        ], outputHandler: outputHandler)

        if result.exitCode != 0 {
            throw DMGError.hdiutilFailed(exitCode: result.exitCode, output: result.output)
        }

        // Ensure we detach on exit
        defer {
            Task {
                _ = await runHdiutil(arguments: ["detach", mountPoint, "-force"], outputHandler: { _ in })
            }
        }

        // Step 3: Generate and copy background image
        await outputHandler("Generating background image...")

        guard let backgroundURL = generateBackgroundImage() else {
            throw DMGError.backgroundGenerationFailed
        }

        defer {
            try? fileManager.removeItem(at: backgroundURL)
        }

        // Create .background directory and copy image
        let backgroundDir = URL(fileURLWithPath: mountPoint).appendingPathComponent(".background")
        do {
            try fileManager.createDirectory(at: backgroundDir, withIntermediateDirectories: true)
            try fileManager.copyItem(at: backgroundURL, to: backgroundDir.appendingPathComponent("background.png"))
        } catch {
            throw DMGError.stylingFailed("Could not copy background: \(error.localizedDescription)")
        }

        // Step 4: Run AppleScript to configure Finder view
        await outputHandler("Configuring DMG appearance...")

        try await configureFinderView(volumeName: volumeName, appName: appName)

        // Small delay to let Finder write .DS_Store
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Step 5: Detach the DMG
        await outputHandler("Finalizing DMG...")

        result = await runHdiutil(arguments: [
            "detach", mountPoint
        ], outputHandler: outputHandler)

        if result.exitCode != 0 {
            // Try force detach
            _ = await runHdiutil(arguments: ["detach", mountPoint, "-force"], outputHandler: { _ in })
        }

        // Step 6: Convert to compressed read-only DMG
        await outputHandler("Compressing DMG...")

        result = await runHdiutil(arguments: [
            "convert",
            tempDMGURL.path,
            "-format", "UDZO",
            "-o", outputURL.path
        ], outputHandler: outputHandler)

        if result.exitCode != 0 {
            throw DMGError.hdiutilFailed(exitCode: result.exitCode, output: result.output)
        }
    }

    // MARK: - Background Image Generation

    private func generateBackgroundImage() -> URL? {
        let width = Int(windowWidth)
        let height = Int(windowHeight)

        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return nil
        }

        // Fill with light gray background
        context.setFillColor(NSColor(white: 0.95, alpha: 1.0).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw arrow from app icon to Applications folder
        // Icons are positioned at their center points
        let arrowStartX = CGFloat(appIconX + iconSize / 2 + 20)  // Start after app icon
        let arrowEndX = CGFloat(applicationsIconX - iconSize / 2 - 20)  // End before Applications
        let arrowY = CGFloat(height - appIconY)  // Flip Y coordinate for Core Graphics

        // Arrow settings
        let arrowColor = NSColor(white: 0.4, alpha: 0.7)
        context.setStrokeColor(arrowColor.cgColor)
        context.setFillColor(arrowColor.cgColor)
        context.setLineWidth(3.0)
        context.setLineCap(.round)

        // Draw arrow line
        context.move(to: CGPoint(x: arrowStartX, y: arrowY))
        context.addLine(to: CGPoint(x: arrowEndX - 15, y: arrowY))
        context.strokePath()

        // Draw arrow head
        let arrowHeadSize: CGFloat = 15
        context.move(to: CGPoint(x: arrowEndX, y: arrowY))
        context.addLine(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY + arrowHeadSize * 0.6))
        context.addLine(to: CGPoint(x: arrowEndX - arrowHeadSize, y: arrowY - arrowHeadSize * 0.6))
        context.closePath()
        context.fillPath()

        image.unlockFocus()

        // Save to temp file
        guard let tiffData = image.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dmg-background-\(UUID().uuidString).png")

        do {
            try pngData.write(to: tempURL)
            return tempURL
        } catch {
            return nil
        }
    }

    // MARK: - Finder Configuration via AppleScript

    private func configureFinderView(volumeName: String, appName: String) async throws {
        let script = """
        tell application "Finder"
            tell disk "\(volumeName)"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set bounds of container window to {100, 100, \(100 + Int(windowWidth)), \(100 + Int(windowHeight))}
                set theViewOptions to icon view options of container window
                set arrangement of theViewOptions to not arranged
                set icon size of theViewOptions to \(iconSize)
                set background picture of theViewOptions to file ".background:background.png"
                set position of item "\(appName)" of container window to {\(appIconX), \(appIconY)}
                set position of item "Applications" of container window to {\(applicationsIconX), \(applicationsIconY)}
                close
                open
                close
            end tell
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
        } catch {
            throw DMGError.stylingFailed("Failed to run AppleScript: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorStr = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw DMGError.stylingFailed("AppleScript failed: \(errorStr)")
        }
    }

    // MARK: - hdiutil Helper

    private func runHdiutil(
        arguments: [String],
        outputHandler: @escaping @MainActor (String) -> Void
    ) async -> (exitCode: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments

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

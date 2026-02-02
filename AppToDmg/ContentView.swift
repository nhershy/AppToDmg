//
//  ContentView.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var selectedAppURL: URL?
    @State private var includeApplicationsLink = true
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var isComplete = false
    @State private var isTargeted = false

    // Progress tracking
    @State private var progress: Double = 0.0
    @State private var progressMessage: String = ""

    // Metadata & README options
    @State private var appMetadata: AppMetadata?
    @State private var includeSystemRequirements = false
    @State private var includeReadme = false
    @State private var readmeOption: ReadmeOption = .none

    private let dmgMaker = DMGMaker()

    var body: some View {
        VStack(spacing: 20) {
            // Drop zone or selected app
            dropZone
                .animation(.easeInOut(duration: 0.2), value: selectedAppURL != nil)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)

            // Metadata display (when app is selected)
            if let metadata = appMetadata, !isComplete {
                MetadataDisplayView(metadata: metadata)
                    .padding(.horizontal, 8)
            }

            // Options section
            if !isComplete {
                VStack(spacing: 12) {
                    Toggle("Include Applications folder shortcut", isOn: $includeApplicationsLink)
                        .toggleStyle(.switch)
                        .disabled(isRunning)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if appMetadata != nil {
                        Toggle("Include System Requirements.txt", isOn: $includeSystemRequirements)
                            .toggleStyle(.switch)
                            .disabled(isRunning)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ReadmeOptionsView(
                        includeReadme: $includeReadme,
                        readmeOption: $readmeOption,
                        disabled: isRunning
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 8)
            }

            // Create DMG button or success state
            if isComplete {
                successView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Button(action: createDMG) {
                    HStack(spacing: 8) {
                        if isRunning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isRunning ? "Creating DMG..." : "Create DMG")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(selectedAppURL == nil || isRunning ? Color.accentColor.opacity(0.5) : Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(selectedAppURL == nil || isRunning)
                .padding(.horizontal, 8)

                // Progress bar (visible when running)
                if isRunning {
                    VStack(spacing: 4) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                        Text(progressMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .transition(.opacity)
                }
            }

            // Error message
            if let error = errorMessage {
                Label(error, systemImage: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.25), value: isComplete)
        .animation(.easeInOut(duration: 0.2), value: errorMessage != nil)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Spacer()

            if let appURL = selectedAppURL {
                // Selected app display
                AppIconView(appURL: appURL)
                    .frame(width: 80, height: 80)

                Text(appURL.deletingPathExtension().lastPathComponent)
                    .font(.title2)
                    .fontWeight(.medium)

                Button("Change App") {
                    chooseApp()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .font(.subheadline)
            } else {
                // Empty drop zone
                Image(systemName: "arrow.down.app")
                    .font(.system(size: 56))
                    .foregroundStyle(.blue.opacity(0.6))

                Text("Drop .app here")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Button(action: chooseApp) {
                    Text("Choose App...")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    Color.blue.opacity(isTargeted ? 0.8 : 0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(isTargeted ? 0.08 : 0.04))
        )
    }

    private var successView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("DMG Created!")
                .font(.title2)
                .fontWeight(.medium)

            Button("Create Another") {
                resetForNewDMG()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(.vertical, 8)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle]
        panel.message = "Select an application to convert to DMG"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            selectedAppURL = panel.url
            clearStatus()
            loadMetadata(for: panel.url)
        }
    }

    private func loadMetadata(for url: URL?) {
        guard let url = url else {
            appMetadata = nil
            return
        }

        Task {
            appMetadata = await MetadataExtractor.extractMetadata(from: url)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }

            Task { @MainActor in
                if url.pathExtension.lowercased() == "app" {
                    selectedAppURL = url
                    clearStatus()
                    loadMetadata(for: url)
                }
            }
        }

        return true
    }

    private func clearStatus() {
        errorMessage = nil
        isComplete = false
    }

    private func resetForNewDMG() {
        selectedAppURL = nil
        appMetadata = nil
        errorMessage = nil
        isComplete = false
        includeSystemRequirements = false
        includeReadme = false
        readmeOption = .none
    }

    private func createDMG() {
        guard let appURL = selectedAppURL else { return }

        // Show save panel
        let savePanel = NSSavePanel()
        let appName = appURL.deletingPathExtension().lastPathComponent
        savePanel.nameFieldStringValue = "\(appName).dmg"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "dmg") ?? .data]
        savePanel.message = "Choose where to save the DMG file"
        savePanel.prompt = "Create DMG"

        guard savePanel.runModal() == .OK, let outputURL = savePanel.url else {
            return
        }

        // Start creation
        isRunning = true
        errorMessage = nil
        progress = 0.0
        progressMessage = ""

        Task {
            do {
                // Prepare system requirements text if enabled
                let sysReqText: String? = if includeSystemRequirements, let metadata = appMetadata {
                    metadata.generateSystemRequirementsText()
                } else {
                    nil
                }

                // Prepare readme content
                let readmeContent: ReadmeContent? = switch readmeOption {
                case .none:
                    nil
                case .file(let url):
                    .file(url)
                case .text(let text):
                    text.isEmpty ? nil : .text(text)
                }

                try await dmgMaker.createDMG(
                    appURL: appURL,
                    outputURL: outputURL,
                    volumeName: appName,
                    includeApplicationsLink: includeApplicationsLink,
                    systemRequirementsText: sysReqText,
                    readmeContent: readmeContent
                ) { message in
                    progressMessage = message
                    progress = mapMessageToProgress(message)
                }

                isComplete = true
                SoundPlayer.playSuccessJingle()
            } catch {
                errorMessage = error.localizedDescription
            }

            isRunning = false
            progress = 0.0
            progressMessage = ""
        }
    }

    private func mapMessageToProgress(_ message: String) -> Double {
        let lowercased = message.lowercased()
        if lowercased.contains("staging directory") {
            return 0.05
        } else if lowercased.contains("copying") {
            return 0.15
        } else if lowercased.contains("applications shortcut") {
            return 0.25
        } else if lowercased.contains("system requirements") {
            return 0.30
        } else if lowercased.contains("readme") {
            return 0.35
        } else if lowercased.contains("read-write dmg") {
            return 0.45
        } else if lowercased.contains("mounting") {
            return 0.55
        } else if lowercased.contains("background image") {
            return 0.65
        } else if lowercased.contains("configuring") {
            return 0.75
        } else if lowercased.contains("finalizing") {
            return 0.85
        } else if lowercased.contains("compressing") {
            return 0.90
        } else if lowercased.contains("successfully") {
            return 1.0
        }
        return progress // Keep current progress for unknown messages
    }
}

struct AppIconView: View {
    let appURL: URL

    var body: some View {
        if let icon = NSWorkspace.shared.icon(forFile: appURL.path) as NSImage? {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}

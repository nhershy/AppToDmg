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

    private let dmgMaker = DMGMaker()

    var body: some View {
        VStack(spacing: 20) {
            // Drop zone or selected app
            dropZone
                .animation(.easeInOut(duration: 0.2), value: selectedAppURL != nil)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)

            // Options toggle (subtle styling)
            if !isComplete {
                Toggle("Include Applications folder shortcut", isOn: $includeApplicationsLink)
                    .toggleStyle(.switch)
                    .disabled(isRunning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedAppURL == nil || isRunning)
                .padding(.horizontal, 8)
            }

            // Error message
            if let error = errorMessage {
                Label(error, systemImage: "xmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding(24)
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
        errorMessage = nil
        isComplete = false
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

        Task {
            do {
                try await dmgMaker.createDMG(
                    appURL: appURL,
                    outputURL: outputURL,
                    volumeName: appName,
                    includeApplicationsLink: includeApplicationsLink
                ) { _ in
                    // Silently ignore log messages for cleaner UI
                }

                isComplete = true
                SoundPlayer.playSuccessJingle()
            } catch {
                errorMessage = error.localizedDescription
            }

            isRunning = false
        }
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

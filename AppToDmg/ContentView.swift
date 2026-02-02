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
    @State private var logOutput: [String] = []
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var isTargeted = false

    private let dmgMaker = DMGMaker()

    var body: some View {
        VStack(spacing: 16) {
            // Input App Section
            GroupBox("Input App") {
                VStack(spacing: 12) {
                    if let appURL = selectedAppURL {
                        HStack(spacing: 12) {
                            AppIconView(appURL: appURL)
                                .frame(width: 48, height: 48)

                            VStack(alignment: .leading) {
                                Text(appURL.deletingPathExtension().lastPathComponent)
                                    .font(.headline)
                                Text(appURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button("Clear") {
                                selectedAppURL = nil
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(8)
                    } else {
                        dropZone
                    }
                }
            }

            // Output Section
            GroupBox("Options") {
                Toggle("Include Applications folder shortcut", isOn: $includeApplicationsLink)
                    .padding(.vertical, 4)
            }

            // Action Button
            Button(action: createDMG) {
                HStack {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.trailing, 4)
                    }
                    Text(isRunning ? "Creating DMG..." : "Create DMG")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(selectedAppURL == nil || isRunning)

            // Status Section
            if !logOutput.isEmpty || errorMessage != nil || successMessage != nil {
                GroupBox("Status") {
                    VStack(alignment: .leading, spacing: 8) {
                        if let error = errorMessage {
                            Label(error, systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }

                        if let success = successMessage {
                            Label(success, systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }

                        if !logOutput.isEmpty {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    LazyVStack(alignment: .leading, spacing: 2) {
                                        ForEach(Array(logOutput.enumerated()), id: \.offset) { index, line in
                                            Text(line)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .id(index)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .frame(maxHeight: 120)
                                .onChange(of: logOutput.count) { _, newCount in
                                    if newCount > 0 {
                                        proxy.scrollTo(newCount - 1, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("App to DMG")
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.down.app")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("Drop .app here or click to browse")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Choose App...") {
                chooseApp()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
        )
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
        successMessage = nil
        logOutput.removeAll()
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
        clearStatus()

        Task {
            do {
                try await dmgMaker.createDMG(
                    appURL: appURL,
                    outputURL: outputURL,
                    volumeName: appName,
                    includeApplicationsLink: includeApplicationsLink
                ) { message in
                    logOutput.append(message)
                }

                successMessage = "DMG created at \(outputURL.lastPathComponent)"
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
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
}

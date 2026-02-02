//
//  ReadmeOptionsView.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import SwiftUI
import UniformTypeIdentifiers

enum ReadmeOption: Equatable {
    case none
    case file(URL)
    case text(String)
}

enum ReadmeMode: String, CaseIterable {
    case selectFile = "Select file"
    case typeContent = "Type content"
}

struct ReadmeOptionsView: View {
    @Binding var includeReadme: Bool
    @Binding var readmeOption: ReadmeOption
    @State private var readmeMode: ReadmeMode = .selectFile
    @State private var readmeText: String = ""
    @State private var selectedFileURL: URL?
    @State private var isDropTargeted = false
    @State private var showingTextEditor = false
    let disabled: Bool

    var body: some View {
        VStack(spacing: 8) {
            Toggle("Include README file", isOn: $includeReadme)
                .toggleStyle(.switch)
                .disabled(disabled)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if includeReadme {
                Picker("", selection: $readmeMode) {
                    ForEach(ReadmeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(disabled)

                if readmeMode == .selectFile {
                    // Mini drop zone for README file
                    readmeDropZone
                } else {
                    // Button to open text editor window
                    HStack {
                        if readmeText.isEmpty {
                            Text("No content")
                                .foregroundStyle(.tertiary)
                        } else {
                            Text("\(readmeText.count) characters")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Edit...") {
                            showingTextEditor = true
                        }
                        .disabled(disabled)
                    }
                    .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: readmeMode) { _, _ in
            updateReadmeOption()
        }
        .onChange(of: readmeText) { _, _ in
            updateReadmeOption()
        }
        .onChange(of: selectedFileURL) { _, _ in
            updateReadmeOption()
        }
        .onChange(of: includeReadme) { _, newValue in
            if !newValue {
                readmeOption = .none
            } else {
                updateReadmeOption()
            }
        }
        .sheet(isPresented: $showingTextEditor) {
            ReadmeTextEditorView(text: $readmeText)
        }
    }

    private var readmeDropZone: some View {
        VStack(spacing: 4) {
            if let url = selectedFileURL {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.blue)
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Change") {
                        chooseReadmeFile()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .font(.caption)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc")
                        .foregroundStyle(.blue.opacity(0.6))
                    Text("Drop README or")
                        .foregroundStyle(.secondary)
                    Button("choose file...") {
                        chooseReadmeFile()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    Color.blue.opacity(isDropTargeted ? 0.8 : 0.3),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.blue.opacity(isDropTargeted ? 0.08 : 0.04))
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            guard let url = url, error == nil else { return }

            Task { @MainActor in
                // Accept text files
                let ext = url.pathExtension.lowercased()
                if ["txt", "md", "rtf", "text", "readme"].contains(ext) || ext.isEmpty {
                    selectedFileURL = url
                }
            }
        }

        return true
    }

    private func updateReadmeOption() {
        guard includeReadme else {
            readmeOption = .none
            return
        }

        switch readmeMode {
        case .selectFile:
            if let url = selectedFileURL {
                readmeOption = .file(url)
            } else {
                readmeOption = .none
            }
        case .typeContent:
            if !readmeText.isEmpty {
                readmeOption = .text(readmeText)
            } else {
                readmeOption = .none
            }
        }
    }

    private func chooseReadmeFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.plainText, .text]
        panel.message = "Select a README file to include"
        panel.prompt = "Select"

        if panel.runModal() == .OK {
            selectedFileURL = panel.url
        }
    }
}

// MARK: - README Text Editor Window

struct ReadmeTextEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @State private var editingText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("README Content")
                    .font(.headline)
                Spacer()
                Text("\(editingText.count) characters")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // Text editor
            TextEditor(text: $editingText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // Footer with buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    text = editingText
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            editingText = text
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var includeReadme = true
        @State private var readmeOption: ReadmeOption = .none

        var body: some View {
            ReadmeOptionsView(
                includeReadme: $includeReadme,
                readmeOption: $readmeOption,
                disabled: false
            )
            .padding()
            .frame(width: 350)
        }
    }

    return PreviewWrapper()
}

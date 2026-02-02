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
    let disabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Include README file", isOn: $includeReadme)
                .toggleStyle(.switch)
                .disabled(disabled)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if includeReadme {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $readmeMode) {
                        ForEach(ReadmeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(disabled)

                    if readmeMode == .selectFile {
                        HStack {
                            if let url = selectedFileURL {
                                Text(url.lastPathComponent)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundStyle(.primary)
                            } else {
                                Text("No file selected")
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            Button("Choose...") {
                                chooseReadmeFile()
                            }
                            .disabled(disabled)
                        }
                        .font(.caption)
                    } else {
                        TextEditor(text: $readmeText)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 80)
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                            .disabled(disabled)
                    }
                }
                .padding(.leading, 4)
            }
        }
        .onChange(of: readmeMode) { _, newMode in
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

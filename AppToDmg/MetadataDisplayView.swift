//
//  MetadataDisplayView.swift
//  AppToDmg
//
//  Created by Nicholas Hershy on 2/2/26.
//

import SwiftUI

struct MetadataDisplayView: View {
    let metadata: AppMetadata

    var body: some View {
        HStack(spacing: 16) {
            if let version = metadata.bundleVersion {
                metadataItem(label: "Version", value: version)
            }

            if let minOS = metadata.minimumSystemVersion {
                metadataItem(label: "Min macOS", value: minOS)
            }

            metadataItem(label: "Arch", value: shortArchDescription)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var shortArchDescription: String {
        if metadata.architectures.contains("arm64") && metadata.architectures.contains("x86_64") {
            return "Universal"
        }
        if metadata.architectures.contains("arm64") {
            return "Apple Silicon"
        }
        if metadata.architectures.contains("x86_64") {
            return "Intel"
        }
        return metadata.architectures.first ?? "Unknown"
    }

    private func metadataItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
            Text(value)
        }
    }
}

#Preview {
    MetadataDisplayView(metadata: AppMetadata(
        bundleIdentifier: "com.example.app",
        bundleVersion: "1.2.3",
        buildNumber: "45",
        minimumSystemVersion: "13.0",
        architectures: ["arm64", "x86_64"],
        appName: "Example App"
    ))
    .padding()
}

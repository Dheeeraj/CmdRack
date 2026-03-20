//
//  ImportConfirmationSheet.swift
//  CmdRack
//

import SwiftUI

struct ImportConfirmationSheet: View {
    let metadata: BackupMetadata
    let onImport: (BackupImportMode) -> Void
    let onCancel: () -> Void

    @State private var selectedMode: BackupImportMode = .merge

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .short
        return fmt.string(from: metadata.exportedAt)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)

                Text("Restore from Snapshot")
                    .font(.headline)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Backup info card
            VStack(alignment: .leading, spacing: 8) {
                metadataRow(icon: "desktopcomputer", label: "Source", value: metadata.deviceName)
                metadataRow(icon: "calendar", label: "Created", value: formattedDate)
                metadataRow(icon: "terminal", label: "Commands", value: "\(metadata.commandCount)")
                metadataRow(icon: "chart.bar", label: "Analytics events", value: "\(metadata.analyticsCount)")
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)

            // Import mode picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Import mode")
                    .font(.subheadline.weight(.medium))
                    .padding(.top, 16)

                ForEach(BackupImportMode.allCases, id: \.self) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedMode == mode ? .blue : .secondary)
                                .font(.body)
                            Image(systemName: mode.icon)
                                .foregroundStyle(mode == .replace ? .orange : .blue)
                                .frame(width: 20, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(mode.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(selectedMode == mode ? Color.accentColor.opacity(0.08) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            if selectedMode == .replace {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                    Text("Replace will permanently delete all existing data before restoring.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            Spacer()

            // Action buttons
            Divider()
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(selectedMode == .replace ? "Replace & Restore" : "Merge & Restore") {
                    onImport(selectedMode)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(selectedMode == .replace ? .orange : .blue)
            }
            .padding(16)
        }
        .frame(width: 420, height: 480)
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .center)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
            Spacer()
        }
    }
}

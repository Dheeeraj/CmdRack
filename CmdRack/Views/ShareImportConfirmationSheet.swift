//
//  ShareImportConfirmationSheet.swift
//  CmdRack
//

import SwiftUI

struct ShareImportConfirmationSheet: View {
    let metadata: BackupService.SharePackMetadata
    let onImport: () -> Void
    let onCancel: () -> Void

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.timeStyle = .short
        return fmt.string(from: metadata.exportedAt)
    }

    var body: some View {
        VStack(spacing: 0) {

            // Header — matches AddCommandView / ShareExportSheet
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Shared Commands")
                        .font(.title3.weight(.semibold))
                    Text("Review the command pack before importing")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Info card
            VStack(alignment: .leading, spacing: 6) {
                metaRow("From", metadata.deviceName)
                metaRow("Created", formattedDate)
                metaRow("Filter", metadata.filterDescription)
                metaRow("Commands", "\(metadata.commandCount)")
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Notes
            VStack(alignment: .leading, spacing: 6) {
                noteRow("No analytics or settings included")
                noteRow("Duplicate commands will be skipped")
                noteRow("Imported commands will not be pinned")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 14)

            Spacer()

            // Footer — matches AddCommandView / ShareExportSheet
            Divider()
            HStack(spacing: 10) {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Import") { onImport() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 420, height: 340)
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 0) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
            Spacer()
        }
    }

    private func noteRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text("·")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

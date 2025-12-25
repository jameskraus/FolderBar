import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FolderSelectionViewModel
    @ObservedObject var updater: FolderBarUpdater
    let appVersion: String
    let appSigningSummary: String?
    let onChooseFolder: () -> Void
    let onResetAll: () -> Void

    @State private var showingResetAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Download Location")
                    .font(.system(size: 13, weight: .semibold))
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folderDisplayName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(folderPathText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Change…", action: onChooseFolder)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("App Icon")
                    .font(.system(size: 13, weight: .semibold))
                HStack(alignment: .center, spacing: 12) {
                    Text("Default icon")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Change Icon…") {}
                        .disabled(true)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Updates")
                    .font(.system(size: 13, weight: .semibold))

                VStack(alignment: .leading, spacing: 2) {
                    Text(updateStatusText)
                        .font(.system(size: 12, weight: .semibold))
                    if updater.needsAppManagementPermission {
                        Text("macOS blocked FolderBar from updating itself. Enable FolderBar in System Settings → Privacy & Security → App Management, then try again.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            Button("Open Privacy & Security…") {
                                updater.openPrivacyAndSecuritySettings()
                            }
                            .buttonStyle(.plain)

                            Spacer()
                        }
                    }
                    if let lastCheckedText {
                        Text(lastCheckedText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                HStack {
                    Spacer()
                    Button("Update…") {
                        updater.userInitiatedUpdate()
                    }
                    .disabled(!updater.isEnabled)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("About")
                    .font(.system(size: 13, weight: .semibold))
                Text("FolderBar Version \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if let appSigningSummary {
                    Text(appSigningSummary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button(
                action: { showingResetAlert = true },
                label: {
                    Text("Reset All Settings")
                        .foregroundColor(.red)
                }
            )
            .buttonStyle(DefaultButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 28)
        .frame(minWidth: 360, minHeight: 300)
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("Reset All Settings?"),
                message: Text("This clears the selected folder and all saved preferences."),
                primaryButton: .destructive(Text("Reset"), action: onResetAll),
                secondaryButton: .cancel()
            )
        }
    }

    private var folderDisplayName: String {
        viewModel.selectedFolderURL?.lastPathComponent ?? "Not set"
    }

    private var folderPathText: String {
        viewModel.selectedFolderURL?.path ?? "Choose a folder to show in the menu bar."
    }

    private var updateStatusText: String {
        guard updater.isEnabled else { return "Updates unavailable" }
        if updater.isUpdateAvailable, let availableVersionString = updater.availableVersionString {
            return "Update available: \(availableVersionString)"
        }
        if updater.isUpdateAvailable {
            return "Update available"
        }
        return "Up to date"
    }

    private var lastCheckedText: String? {
        guard updater.isEnabled, let lastCheckedAt = updater.lastCheckedAt else { return nil }
        return "Last checked: \(Self.lastCheckedFormatter.string(from: lastCheckedAt))"
    }

    private var errorText: String? {
        guard updater.isEnabled, let lastError = updater.lastError, !lastError.isEmpty else { return nil }
        return "Last error: \(lastError)"
    }

    private static let lastCheckedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

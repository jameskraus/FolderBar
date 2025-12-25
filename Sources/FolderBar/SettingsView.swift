import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FolderSelectionViewModel
    @ObservedObject var updater: FolderBarUpdater
    @ObservedObject var iconSettings: StatusItemIconSettings
    let appVersion: String
    let appSigningSummary: String?
    let onChooseFolder: () -> Void
    let onResetAll: () -> Void

    @State private var showingResetAlert = false
    @State private var showingIconPicker = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsSection(title: "Selected Folder") {
                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(folderDisplayName)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(folderPathText)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 12)
                            Button("Change…", action: onChooseFolder)
                        }
                    }

                    Divider()
                        .padding(.vertical, 16)

                    SettingsSection(title: "Menu Bar Icon") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Image(systemName: iconSettings.resolvedSymbolName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 22, alignment: .center)
                                    .foregroundColor(.secondary)

                                Text(iconSettings.resolvedSymbolName)
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)

                                Spacer(minLength: 12)

                                Button("Choose…") {
                                    showingIconPicker = true
                                }

                                Button("Reset") {
                                    iconSettings.resetToDefault()
                                }
                                .controlSize(.small)
                            }

                            if !iconSettings.isValidSymbol {
                                Text("Unknown icon was previously selected. Using the default icon.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Divider()
                        .padding(.vertical, 16)

                    SettingsSection(title: "Updates") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(updateStatusText)
                                        .font(.system(size: 12, weight: .semibold))
                                    if let lastCheckedText {
                                        Text(lastCheckedText)
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer(minLength: 12)

                                Button("Update…") {
                                    updater.userInitiatedUpdate()
                                }
                                .disabled(!updater.isEnabled)
                            }

                            if updater.needsAppManagementPermission {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("macOS blocked FolderBar from updating itself. Enable FolderBar in System Settings → Privacy & Security → App Management, then try again.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Button("Open Privacy & Security…") {
                                        updater.openPrivacyAndSecuritySettings()
                                    }
                                    .controlSize(.small)
                                }
                            }

                            if let errorText {
                                Text(errorText)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }

                    Divider()
                        .padding(.vertical, 16)

                    SettingsSection(title: "About") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("FolderBar Version \(appVersion)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            if let appSigningSummary {
                                Text(appSigningSummary)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 24)
            }

            Divider()

            HStack {
                Button(
                    action: { showingResetAlert = true },
                    label: {
                        Text("Reset All Settings")
                            .foregroundColor(.red)
                    }
                )
                .buttonStyle(DefaultButtonStyle())

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .frame(minWidth: 500, minHeight: 480)
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("Reset All Settings?"),
                message: Text("This clears the selected folder and all saved preferences."),
                primaryButton: .destructive(Text("Reset"), action: onResetAll),
                secondaryButton: .cancel()
            )
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(iconSettings: iconSettings)
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

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

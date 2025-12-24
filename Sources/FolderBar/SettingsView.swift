import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: FolderSelectionViewModel
    let appVersion: String
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
                    Button(viewModel.isFolderPickerPresented ? "Show…" : "Change…", action: onChooseFolder)
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

            VStack(alignment: .leading, spacing: 6) {
                Text("About")
                    .font(.system(size: 13, weight: .semibold))
                Text("FolderBar Version \(appVersion)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
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
}

import SwiftUI

struct FolderPanelView: View {
    @ObservedObject var viewModel: FolderSelectionViewModel

    var body: some View {
        Group {
            if let folderURL = viewModel.selectedFolderURL {
                SelectedFolderView(folderURL: folderURL)
            } else {
                EmptyStateView(onChooseFolder: viewModel.chooseFolder)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
    }
}

private struct EmptyStateView: View {
    let onChooseFolder: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 28, weight: .semibold))
            Text("No folder selected")
                .font(.system(size: 13, weight: .semibold))
            Text("Choose a folder to show its files here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Choose Folder", action: onChooseFolder)
                .buttonStyle(DefaultButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SelectedFolderView: View {
    let folderURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(folderURL.lastPathComponent)
                .font(.system(size: 13, weight: .semibold))
            Text(folderURL.path)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

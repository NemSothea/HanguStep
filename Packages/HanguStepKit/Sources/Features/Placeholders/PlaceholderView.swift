import SwiftUI

struct PlaceholderView: View {
    let section: AppSection

    var body: some View {
        ContentUnavailableView(
            section.title,
            systemImage: section.systemImage,
            description: Text("Coming in a later phase.")
        )
        .navigationTitle(section.title)
    }
}

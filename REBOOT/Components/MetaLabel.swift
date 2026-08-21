import SwiftUI

/// 11px / 600 / +3.08px uppercase eyebrow label.
struct MetaLabel: View {
    let text: String
    var color: Color = AppColors.inkFaint

    var body: some View {
        Text(text.uppercased())
            .type(.metaLabel)
            .foregroundStyle(color)
            .accessibilityLabel(text)
    }
}

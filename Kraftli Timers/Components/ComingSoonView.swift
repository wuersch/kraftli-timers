//
//  ComingSoonView.swift
//  Kraftli Timers
//
//  Created by Michael Würsch on 17.12.2025.
//

import SwiftUI

struct ComingSoonView: View {
    let title: String
    let description: String
    let image: String

    init(title: String, description: String, image: String) {
        self.title = title
        self.description = "Coming soon\(UISeparator.dot)\(description)"
        self.image = image
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // App-Icon-Style
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .frame(width: 80, height: 80)

                Image(systemName: image)
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
            }
            .padding(.top, 30)

            Text(title)
                .font(.largeTitle.weight(.bold))
                .padding(.top, 4)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineSpacing(2)
                .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color(uiColor: .systemFill).opacity(0.3), radius: 4, y: 2)
        )
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding()

        Spacer()
    }
}

#Preview {
    ComingSoonView(title: "Settings", description: "Adjust settings and more", image: "gearshape")
}

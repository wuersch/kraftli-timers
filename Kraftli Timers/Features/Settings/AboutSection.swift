//
//  AboutSection.swift
//  Kraftli Timers
//
//  Settings section displaying app info, GitHub link, and acknowledgments.
//

import SwiftUI

struct AboutSection: View {
    @State private var showingAcknowledgments = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)

            VStack(spacing: 0) {
                // Version
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundStyle(.secondary)
                }
                .padding()

                Divider().padding(.leading, 16)

                // GitHub
                Button {
                    openGitHub()
                } label: {
                    HStack {
                        Label("GitHub", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }

                Divider().padding(.leading, 16)

                // Acknowledgments
                Button {
                    showingAcknowledgments = true
                } label: {
                    HStack {
                        Label("Acknowledgments", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .contentShape(Rectangle())
                }
            }
            .cardStyle()
        }
        .sheet(isPresented: $showingAcknowledgments) {
            AcknowledgmentsView()
        }
    }

    private func openGitHub() {
        if let url = URL(string: "https://github.com/wuersch/kraftli-timers") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Acknowledgments View

struct AcknowledgmentsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Icons Section
                Section("Icons") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Icon based on Wide Push Up by Guilherme Silva Soares")
                            .font(.body)
                        Link("The Noun Project", destination: URL(string: "https://thenounproject.com/icon/wide-push-up-1970890/")!)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }

                // Sounds Section
                Section("Sounds") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timer Completion Sound based on CRWDCheer by ShangusBurger")
                            .font(.body)
                        Text("License: Creative Commons 0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link("Freesound", destination: URL(string: "https://freesound.org/s/764274/")!)
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Acknowledgments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("About Section") {
    ScrollView {
        AboutSection()
            .padding()
    }
}

#Preview("Acknowledgments") {
    AcknowledgmentsView()
}

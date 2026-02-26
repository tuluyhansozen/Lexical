import SwiftUI
import SwiftData
import LexicalCore

struct ManageInterestsView: View {
    var profile: InterestProfile
    @State private var newTag: String = ""

    var body: some View {
        Form {
            Section("Current Interests") {
                if profile.selectedTags.isEmpty {
                    Text("No interests selected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profile.selectedTags, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete { indexSet in
                        profile.selectedTags = profile.selectedTags.enumerated().compactMap { pair in
                            indexSet.contains(pair.offset) ? nil : pair.element
                        }
                        profile.lastUpdated = Date()
                    }
                }
            }
            
            Section("Add Interest") {
                HStack {
                    TextField("New Interest", text: $newTag)
                    Button("Add") {
                        appendTag(newTag)
                        newTag = ""
                    }
                    .disabled(newTag.isEmpty)
                }
            }

            Section("Browse By Group") {
                ForEach(InterestCatalog.groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal) {
                            HStack {
                                ForEach(group.options) { option in
                                    if !profile.selectedTags.contains(option.title) {
                                        Button {
                                            appendTag(option.title)
                                        } label: {
                                            Text(option.chipLabel)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .scrollIndicators(.hidden)
                    }
                }
            }
        }
        .navigationTitle("Manage Interests")
    }

    private func appendTag(_ rawTag: String) {
        let normalized = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard !profile.selectedTags.contains(normalized) else { return }
        profile.selectedTags.append(normalized)
        profile.selectedTags.sort()
        profile.lastUpdated = Date()
    }
}

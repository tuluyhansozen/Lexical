import SwiftUI
import SwiftData
import LexicalCore

struct ManageInterestsView: View {
    @Bindable var profile: InterestProfile
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
                        profile.removeTags(at: indexSet)
                    }
                }
            }
            
            Section("Add Interest") {
                HStack {
                    TextField("New Interest", text: $newTag)
                    Button("Add") {
                        profile.addTag(newTag)
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
                                            profile.addTag(option.title)
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
}

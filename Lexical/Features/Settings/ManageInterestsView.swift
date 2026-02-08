import SwiftUI
import SwiftData
import LexicalCore

struct ManageInterestsView: View {
    @Bindable var profile: InterestProfile
    @State private var newTag: String = ""
    
    let suggestedTags = ["Science", "Technology", "Business", "Health", "Politics", "Arts", "Sports", "Nature"]
    
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
                        profile.selectedTags.remove(atOffsets: indexSet)
                    }
                }
            }
            
            Section("Add Interest") {
                HStack {
                    TextField("New Interest", text: $newTag)
                    Button("Add") {
                        if !newTag.isEmpty && !profile.selectedTags.contains(newTag) {
                            profile.selectedTags.append(newTag)
                            newTag = ""
                        }
                    }
                    .disabled(newTag.isEmpty)
                }
            }
            
            Section("Suggestions") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestedTags, id: \.self) { tag in
                            if !profile.selectedTags.contains(tag) {
                                Button {
                                    profile.selectedTags.append(tag)
                                } label: {
                                    Text(tag)
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
            }
        }
        .navigationTitle("Manage Interests")
    }
}

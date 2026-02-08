import Foundation
import SwiftData

@Model
public final class MorphologicalRoot {
    @Attribute(.unique) public var rootId: Int
    public var root: String
    public var basicMeaning: String
    public var wordIdsData: Data

    public var wordIds: [Int] {
        get {
            (try? JSONDecoder().decode([Int].self, from: wordIdsData)) ?? []
        }
        set {
            wordIdsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public init(rootId: Int, root: String, basicMeaning: String, wordIds: [Int] = []) {
        self.rootId = rootId
        self.root = root
        self.basicMeaning = basicMeaning
        self.wordIdsData = (try? JSONEncoder().encode(wordIds)) ?? Data()
    }
}

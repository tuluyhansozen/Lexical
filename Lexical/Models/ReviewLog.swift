import Foundation
import SwiftData
import UIKit

/// Immutable review event log for CRDT-based sync
@Model
final class ReviewLog {
    /// Unique identifier for this review event
    var id: UUID
    
    /// The vocabulary item that was reviewed
    var vocabularyItem: VocabularyItem?
    
    /// FSRS grade (1=Again, 2=Hard, 3=Good, 4=Easy)
    var grade: Int
    
    /// When the review occurred
    var reviewDate: Date
    
    /// Time spent on this review (in seconds)
    var duration: TimeInterval
    
    /// Device that recorded this review (for CRDT merging)
    var deviceId: String
    
    /// Stability value after this review
    var stabilityAfter: Double
    
    /// Difficulty value after this review
    var difficultyAfter: Double
    
    init(
        vocabularyItem: VocabularyItem,
        grade: Int,
        duration: TimeInterval,
        stabilityAfter: Double,
        difficultyAfter: Double
    ) {
        self.id = UUID()
        self.vocabularyItem = vocabularyItem
        self.grade = grade
        self.reviewDate = Date()
        self.duration = duration
        self.deviceId = Self.currentDeviceId
        self.stabilityAfter = stabilityAfter
        self.difficultyAfter = difficultyAfter
    }
    
    /// Get current device identifier
    private static var currentDeviceId: String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return UUID().uuidString
        #endif
    }
}

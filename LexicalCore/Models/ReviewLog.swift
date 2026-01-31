import Foundation
import SwiftData
import UIKit

/// Immutable review event log for CRDT-based sync
@Model
public final class ReviewLog {
    /// Unique identifier for this review event
    public var id: UUID
    
    /// The vocabulary item that was reviewed
    public var vocabularyItem: VocabularyItem?
    
    /// FSRS grade (1=Again, 2=Hard, 3=Good, 4=Easy)
    public var grade: Int
    
    /// When the review occurred
    public var reviewDate: Date
    
    /// Time spent on this review (in seconds)
    public var duration: TimeInterval
    
    /// Device that recorded this review (for CRDT merging)
    public var deviceId: String
    
    /// Stability value after this review
    public var stabilityAfter: Double
    
    /// Difficulty value after this review
    public var difficultyAfter: Double
    
    public init(
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

import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@Model
public final class ReviewEvent {
    @Attribute(.unique) public var eventId: String

    public var userId: String
    public var lemma: String
    public var grade: Int
    public var reviewDate: Date
    public var durationMs: Int
    public var scheduledDays: Double
    public var reviewState: String
    public var deviceId: String
    public var sourceReviewLogId: UUID?

    public init(
        eventId: String = UUID().uuidString,
        userId: String,
        lemma: String,
        grade: Int,
        reviewDate: Date = Date(),
        durationMs: Int,
        scheduledDays: Double,
        reviewState: String,
        deviceId: String? = nil,
        sourceReviewLogId: UUID? = nil
    ) {
        self.eventId = eventId
        self.userId = userId
        self.lemma = lemma.lowercased()
        self.grade = grade
        self.reviewDate = reviewDate
        self.durationMs = durationMs
        self.scheduledDays = scheduledDays
        self.reviewState = reviewState
        self.deviceId = deviceId ?? Self.currentDeviceId
        self.sourceReviewLogId = sourceReviewLogId
    }

    public static func reviewState(for grade: Int) -> String {
        switch grade {
        case 1: return "again"
        case 2: return "hard"
        case 3: return "good"
        case 4: return "easy"
        default: return "unknown"
        }
    }

    private static var currentDeviceId: String {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return UUID().uuidString
        #endif
    }
}

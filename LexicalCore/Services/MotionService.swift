import SwiftUI
import CoreMotion
import Combine

/// A service that provides real-time device motion data for parallax effects.
/// Falls back to a simulated "breathing" motion on Simulator or when motion is unavailable.
@MainActor
public class MotionService: ObservableObject {
    @Published public var tilt: CGPoint = .zero
    @Published public var pitch: Double = 0.0
    @Published public var roll: Double = 0.0

    private let motionManager = CMMotionManager()
    private var timer: Timer?
    private var startTime: Date?

    public init() {
        startUpdates()
    }

    private func startUpdates() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self = self, let motion = motion else { return }
                self.processMotion(motion)
            }
        } else {
            // Simulator / Fallback: Gentle breathing sine wave
            startTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                guard let self = self, let start = self.startTime else { return }
                let time = Date().timeIntervalSince(start)
                
                // Simulate a gentle figure-8 motion
                let x = sin(time * 0.5) * 0.3
                let y = cos(time * 0.3) * 0.3
                
                self.tilt = CGPoint(x: x, y: y)
                self.pitch = y
                self.roll = x
            }
        }
    }

    private func processMotion(_ motion: CMDeviceMotion) {
        // Map gravity to tilt (-1...1)
        // Adjust sensitivity as needed
        let roll = motion.attitude.roll
        let pitch = motion.attitude.pitch
        
        // Clamp to avoid extreme angles
        self.roll = (roll * 0.5).clamped(to: -1...1)
        self.pitch = (pitch * 0.5).clamped(to: -1...1)
        
        self.tilt = CGPoint(x: self.roll, y: self.pitch)
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
        timer?.invalidate()
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

import SwiftUI
import CoreMotion
import Combine

/// A service that provides real-time device motion data for parallax effects.
/// Falls back to a simulated "breathing" motion on Simulator or when motion is unavailable.
@MainActor
public final class MotionService: NSObject, ObservableObject {
    @Published public var tilt: CGPoint = .zero
    @Published public var pitch: Double = 0.0
    @Published public var roll: Double = 0.0

    #if os(iOS)
    private let motionManager = CMMotionManager()
    #endif
    private var timer: Timer?
    private var startTime: Date?

    public override init() {
        super.init()
        startUpdates()
    }

    private func startUpdates() {
        #if os(iOS)
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self = self, let motion = motion else { return }
                self.processMotion(motion)
            }
            return
        }
        #endif

        // Simulator / unsupported-platform fallback: gentle breathing sine wave.
        startTime = Date()
        timer = Timer.scheduledTimer(
            timeInterval: 1.0 / 60.0,
            target: self,
            selector: #selector(handleFallbackTick),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func handleFallbackTick() {
        guard let start = startTime else { return }
        let time = Date().timeIntervalSince(start)

        let x = sin(time * 0.5) * 0.3
        let y = cos(time * 0.3) * 0.3

        tilt = CGPoint(x: x, y: y)
        pitch = y
        roll = x
    }

    #if os(iOS)
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
    #endif
    
    deinit {
        #if os(iOS)
        motionManager.stopDeviceMotionUpdates()
        #endif
        timer?.invalidate()
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

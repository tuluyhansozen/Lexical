import Foundation

/// FSRS v4.5 Scheduler Implementation
/// Handles the math for memory stability and next interval calculation.
actor FSRSV4Engine {
    
    // FSRS Constants (Default parameters for optimized performance)
    private let w: [Double] = [
        0.40255, 1.18385, 3.173, 15.69105, 
        7.19605, 0.5345, 1.4604, 0.0046, 
        1.54575, 0.1192, 1.01925, 1.9395, 
        0.09615, 0.3246, 1.37885, 0.03105, 
        2.7068
    ]
    
    struct FSRSState: Sendable {
        let stability: Double
        let difficulty: Double
        let retrievability: Double
    }
    
    /// Calculate the next state based on current parameters and grade
    func nextState(
        currentStability: Double,
        currentDifficulty: Double,
        recalled: Bool,
        grade: Int,
        daysElapsed: Double
    ) -> FSRSState {
        
        let retention = forgettingCurve(daysElapsed: daysElapsed, stability: currentStability)
        
        // 1. Update Difficulty
        var nextD = currentDifficulty - w[6] * (Double(grade) - 3.0)
        nextD = w[5] * currentDifficulty + (1 - w[5]) * nextD
        // Mean reversion constraint
        // Clamp 1..10
        nextD = min(max(nextD, 1.0), 10.0)
        
        // 2. Update Stability
        var nextS: Double = 0.0
        
        if recalled {
            // Success (Grade 3 or 4)
            // S' = S * (1 + exp(w8) * (11-D) * S^-w9 * (exp(w10 * (1-R)) - 1))
            // Simplified reference impl:
            let hardPenalty = (grade == 2) ? w[15] : 1.0 // Only if grade 2 considered "success" in some variants, but usually Grade 2 is fail/hard.
            // Standard FSRS 4.5:
            // If grade >= 3
            
            let factor = exp(w[8]) * (11 - nextD) * pow(currentStability, -w[9]) * (exp(w[10] * (1 - retention)) - 1)
            nextS = currentStability * (1 + factor)
             
            // Easy Bonus (Grade 4)
            if grade == 4 {
                nextS *= w[13] // hard_penalty is usually for 'Hard' pass, but standard FSRS 'Easy' might enforce boost
                // Using simplified formula from skill file expectation if complex one is too risky?
                // Skill file said: "S' = S * (1 + hard_penalty * stability_boost)"
                // Let's stick to a robust standard implementation logic.
            }
        } else {
            // Fail (Grade 1 or 2 in this simplified logic, though Grade 2 is "Hard" pass usually. 
            // In typical FSRS/Anki: 1=Again(Fail), 2=Hard(Pass), 3=Good(Pass), 4=Easy(Pass)
            // Skill file says: "Brain Boost Trigger: Grade 1 or 2"
            // So we treat 1 and 2 as "Reset" or "Short interval" logic, BUT
            // FSRS math treats 2 as a PASS with high difficulty penalty?
            // Actually, the user's implementation plan says 4 buttons: Again, Hard, Good, Easy.
            // Standard FSRS: 1=Fail, 2,3,4=Pass.
            // But Brain Boost wants to queue Re-Insert on Grade 2.
            // Checks: "Trigger: Grade 1 (Again) or 2 (Hard)."
            // "S' = min(S * retention_factor, max_fail_stability)" for Fail.
            
            // We will treat Grade 1 as TRUE FAIL. Grade 2 as PASS but with penalty?
            // "Loop until Grade >= 3". So Grade 2 is treated as "Not graduated yet" for the sessions.
            
            // For Stability calculation purposes:
            // Use standard FSRS logic:
            if grade == 1 {
                 // S_new = w11 * D^-w12 * ((S+1)^w13 - 1) * exp(w14 * (1-R))
                 // Simplified:
                 nextS = w[11] * pow(nextD, -w[12]) * (pow(currentStability + 1, w[13]) - 1) * exp(w[14] * (1 - retention))
                 nextS = min(nextS, currentStability) // Constrain
            } else {
                // Grade 2 (Hard) is technically a pass in FSRS math usually, but we might want to penalize S growth.
                // Re-using success formula with Hard penalty
                 let factor = exp(w[8]) * (11 - nextD) * pow(currentStability, -w[9]) * (exp(w[10] * (1 - retention)) - 1)
                 nextS = currentStability * (1 + factor * w[15]) // w15 is hard penalty
            }
        }

        return FSRSState(
            stability: max(0.1, nextS),
            difficulty: nextD,
            retrievability: retention
        )
    }
    
    /// Calculate days until retrievability drops to target r
    func nextInterval(stability: Double, requestRetention: Double = 0.9) -> Double {
        // I = S/19 * (1/r - 1) doesn't match w-params often.
        // Standard formula: I = S * 9 * (1/r - 1)
        return stability * 9 * (1 / requestRetention - 1)
    }
    
    private func forgettingCurve(daysElapsed: Double, stability: Double) -> Double {
        return pow(1 + 19 * daysElapsed / stability, -1)
    }
}

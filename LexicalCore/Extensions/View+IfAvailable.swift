import SwiftUI

public extension View {
    @ViewBuilder
    func ifAvailable<T: View, F: View>(
        iOS expectedVersion: Int,
        @ViewBuilder _ transform: (Self) -> T,
        @ViewBuilder fallback: (Self) -> F
    ) -> some View {
        if #available(iOS 26, *) {
            transform(self)
        } else {
            fallback(self)
        }
    }
}

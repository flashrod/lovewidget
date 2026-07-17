import SwiftUI

extension Color {
    public init(_ strokeColor: StrokeColor) {
        self.init(
            red: strokeColor.red,
            green: strokeColor.green,
            blue: strokeColor.blue,
            opacity: strokeColor.alpha
        )
    }
}

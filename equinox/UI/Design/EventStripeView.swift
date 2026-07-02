import SwiftUI

struct EventStripeView: View {
    let color: Color
    var width: CGFloat = EquinoxDesign.EventStripe.width
    var cornerRadius: CGFloat = EquinoxDesign.EventStripe.cornerRadius
    var verticalPadding: CGFloat = EquinoxDesign.spacingXS

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(color)
            .frame(width: width)
            .padding(.vertical, verticalPadding)
    }
}

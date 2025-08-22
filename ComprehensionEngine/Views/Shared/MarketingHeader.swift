import SwiftUI
import UIKit

struct MarketingHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            brandImage
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: AppColors.shadowDark, radius: 12, x: 0, y: 6)
                .accessibilityHidden(true)

            Text("Graspy")
                .heading2(color: .white)
                .font(.system(size: 96, weight: .bold))
                .accessibilityLabel("Graspy, home header")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    private var brandImage: Image {
        if let ui = UIImage(named: "brand-icon") {
            return Image(uiImage: ui)
        }
        if let ui = UIApplication.shared.alternateAppIconImage() {
            return Image(uiImage: ui)
        }
        return Image(systemName: "square.grid.2x2.fill")
    }
}

private extension UIApplication {
    func alternateAppIconImage() -> UIImage? {
        // Attempt to load app icon from bundle as a fallback for brand mark
        guard
            let iconsDict = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
            let primaryIcon = iconsDict["CFBundlePrimaryIcon"] as? [String: Any],
            let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
            let lastIcon = iconFiles.last
        else { return nil }
        return UIImage(named: lastIcon)
    }
}

#Preview {
    ZStack {
        AppColors.brandLinearGradient()
        MarketingHeader()
            .padding(.top, 44)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .ignoresSafeArea()
}



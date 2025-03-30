import SwiftUI

struct SkeletonCertificateCardView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Имитация изображения сертификата
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(colorScheme == .dark ? Color(UIColor.systemGray3) : Color.gray.opacity(0.4), lineWidth: 2)
                    )
                
                // Имитация номера сертификата
                Rectangle()
                    .fill(colorScheme == .dark ? Color(UIColor.systemGray3) : Color.gray.opacity(0.4))
                    .frame(width: 60, height: 20)
                    .cornerRadius(8)
                    .padding(6)
            }
            
            // Имитация баланса
            Rectangle()
                .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                .frame(height: 20)
                .cornerRadius(4)
                .padding(.top, 8)
            
            // Имитация даты покупки
            Rectangle()
                .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                .frame(height: 14)
                .cornerRadius(4)
            
            // Имитация срока действия
            Rectangle()
                .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                .frame(height: 14)
                .cornerRadius(4)
        }
        .padding()
        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
        .cornerRadius(15)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1), radius: 5)
    }
}

struct SkeletonCertificateCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SkeletonCertificateCardView()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.light)
            SkeletonCertificateCardView()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
        }
    }
}

import SwiftUI

struct SkeletonAbonementCardView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Имитация изображения
            ZStack(alignment: .topTrailing) {
                Rectangle()
                    .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.3))
                    .frame(height: 180)
                    .cornerRadius(15)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(colorScheme == .dark ? Color(UIColor.systemGray2) : Color.gray.opacity(0.4), lineWidth: 2)
                    )
                
                // Имитация небольшого блока с номером абонемента
                Rectangle()
                    .fill(colorScheme == .dark ? Color(UIColor.systemGray2) : Color.gray.opacity(0.4))
                    .frame(width: 60, height: 20)
                    .cornerRadius(6)
                    .padding(8)
            }
            
            // Имитация баланса
            Rectangle()
                .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.3))
                .frame(height: 16)
                .cornerRadius(4)
                .padding(.top, 8)
            
            // Имитация даты покупки
            Rectangle()
                .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.3))
                .frame(height: 12)
                .cornerRadius(4)
            
            // Имитация срока окончания
            Rectangle()
                .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.3))
                .frame(height: 12)
                .cornerRadius(4)
        }
        .padding()
        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
        .cornerRadius(20)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

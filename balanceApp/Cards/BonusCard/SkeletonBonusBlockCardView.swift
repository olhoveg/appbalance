//
//  SkeletonBonusBlockCardView.swift.swift
//  balanceApp
//
//  Created by Olkhov on 30.03.2025.
//

import SwiftUI

struct SkeletonBonusBlockCardView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            // Верхняя часть: имитация изображения бонусной карты
            ZStack(alignment: .topTrailing) {
                // Placeholder для изображения
                Rectangle()
                    .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(colorScheme == .dark ? Color(UIColor.systemGray3) : Color.gray.opacity(0.4), lineWidth: 2)
                    )
                
                // Placeholder для номера карты (имитирует текст "№ ...")
                Rectangle()
                    .fill(colorScheme == .dark ? Color(UIColor.systemGray3) : Color.gray.opacity(0.4))
                    .frame(width: 60, height: 20)
                    .cornerRadius(10)
                    .padding([.top, .trailing], 12)
            }
            
            // Небольшой отступ
            Spacer().frame(height: 8)
            
            // Баланс – placeholder (центрально выровнено)
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                        .frame(width: 50, height: 12)
                        .cornerRadius(4)
                    Rectangle()
                        .fill(colorScheme == .dark ? Color(UIColor.systemGray4) : Color.gray.opacity(0.2))
                        .frame(width: 80, height: 20)
                        .cornerRadius(6)
                }
                Spacer()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(colorScheme == .dark ? Color(UIColor.systemGray6) : Color.white)
        .cornerRadius(20)
        .shadow(color: colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
    }
}

struct SkeletonBonusBlockCardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SkeletonBonusBlockCardView()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.light)
            SkeletonBonusBlockCardView()
                .previewLayout(.sizeThatFits)
                .preferredColorScheme(.dark)
        }
    }
}

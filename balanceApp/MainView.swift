//
//  MainView.swift
//  balanceApp
//
//  Created by Evgeniy Olkhov on 20.02.2025.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Наш кастомный NavigationBar наверху
                CustomNavigationBar()
                
                // Основной контент ниже
                ScrollView {
                    VStack(spacing: 20) {
                        StoriesView() // Вставляем готовый блок сторис
                        
                        Divider()
                        
                        RecommendationsView() // Блок с рекомендациями
                        
                        Divider()
                        
                        ArticlesView() // Блок со статьями
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true) // Скрываем стандартный navigation bar
        }
    }
}

// MARK: - Остальные вьюшки (примерные реализации)

// Кастомный NavigationBar (с увеличенной областью касания для кнопки профиля)
struct CustomNavigationBar: View {
    var body: some View {
        HStack {
            NavigationLink(destination: ProfileView()) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(.black)
                    .padding(10)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(1)
            
            Spacer()
            
            Text("Главная")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
            
            HStack(spacing: 15) {
                Button(action: openWhatsApp) {
                    Image(systemName: "message.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: makeCall) {
                    Image(systemName: "phone.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    func openWhatsApp() {
        if let url = URL(string: "https://wa.me/79615805108") {
            UIApplication.shared.open(url)
        }
    }
    
    func makeCall() {
        if let url = URL(string: "tel://+79615805108") {
            UIApplication.shared.open(url)
        }
    }
}


// Блок рекомендаций
struct RecommendationsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Рекомендации")
                .font(.headline)
                .padding(.leading)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(0..<5, id: \.self) { index in
                        NavigationLink(destination: RecommendationDetailView(id: index)) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green)
                                .frame(width: 150, height: 100)
                                .overlay(
                                    Text("Рекомендация \(index + 1)")
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// Блок статей
struct ArticlesView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Статьи")
                .font(.headline)
                .padding(.leading)
            
            List(0..<5, id: \.self) { index in
                NavigationLink(destination: ArticleDetailView(id: index)) {
                    Text("Статья \(index + 1)")
                }
            }
            .frame(height: 250)
        }
    }
}

// Детальные страницы
struct FullStoriesView: View {
    var body: some View {
        Text("Полный экран сторис")
            .font(.largeTitle)
    }
}

struct RecommendationDetailView: View {
    var id: Int
    
    var body: some View {
        Text("Детальная страница рекомендации \(id + 1)")
            .font(.largeTitle)
    }
}

struct ArticleDetailView: View {
    var id: Int
    
    var body: some View {
        Text("Детальная страница статьи \(id + 1)")
            .font(.largeTitle)
    }
}

// Превью для MainView
struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MainView()
        }
    }
}

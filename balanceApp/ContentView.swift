//ContentView.swift


import SwiftUI


// MARK: - Enum вкладок
enum Tab: Hashable {
    case main, cards, feed, chat, solarium
}


// MARK: - Root ContentView с TabView
struct ContentView: View {
    @State private var selectedTab: Tab = .main

    var body: some View {
        TabView(selection: $selectedTab) {
            MainView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Главная")
                }
                .tag(Tab.main)
            
            CardsTabView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("Карты")
                }
                .tag(Tab.cards)
            
            FeedView()
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("Лента")
                }
                .tag(Tab.feed)
            
            SpecialistsView()
                .tabItem {
                    Image(systemName: "person.3.fill") // Используем иконку команды
                    Text("Команда")
                }
                .tag(Tab.chat)
            
            SolariumView()
                .tabItem {
                    Image(systemName: "calendar.badge.plus")
                    Text("Записаться")
                }
                .tag(Tab.solarium)
        }
    }
}









// Лента
struct FeedView: View {
    var body: some View {
        Text("Лента")
            .font(.title)
            .padding()
    }
}

// Чат
struct ChatView: View {
    var body: some View {
        Text("Чат")
            .font(.title)
            .padding()
    }
}



struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

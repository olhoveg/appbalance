import SwiftUI

// MARK: - Enum вкладок
enum Tab: Hashable {
    case main, cards, service, chat, solarium
}

// MARK: - Root ContentView с TabView
struct ContentView: View {
    @State private var selectedTab: Tab = .main

    var body: some View {
        NavigationView {
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
                
                // Используем новую иконку для услуг (массаж)
                VerticalServicesView()
                    .tabItem {
                        Image(systemName: "figure.mind.and.body")
                        Text("Услуги")
                    }
                    .tag(Tab.service)
                
                SpecialistsView()
                    .tabItem {
                        Image(systemName: "person.3.fill")
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
            .navigationBarHidden(true)
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

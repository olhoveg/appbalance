import AppMetricaCore
import SwiftUI
import AVKit

// MARK: - Enum вкладок
enum Tab: Hashable {
    case main, cards, service, chat, solarium, videoLessons
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
                
                VideoLessonsView()
                    .tabItem {
                        Image(systemName: "play.rectangle.fill")
                        Text("Видео уроки")
                    }
                    .tag(Tab.videoLessons)
            }
            .navigationBarHidden(true)
            .onChange(of: selectedTab) { oldValue, tab in
                switch tab {
                case .main:
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку 'Главная'")
                case .cards:
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку 'Карты'")
                case .service:
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку 'Услуги'")
                case .chat:
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку 'Команда'")
                case .solarium:
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку 'Записаться'")
                case .videoLessons:
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку 'Видео уроки'")
                }
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

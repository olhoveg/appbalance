import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()  // Теперь тут загрузка из Firestore
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Главная")
                }
            
            CardsTabView()
                .tabItem {
                    Image(systemName: "creditcard.fill")
                    Text("Карты")
                }
            
            FeedView()
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("Лента")
                }
            
            ChatView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Чат")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Профиль")
                }
        }
    }
}



// Карты (внутри переключение между сертификатами и абонементами)
struct CardsTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker(selection: $selectedTab, label: Text("Выбор")) {
                Text("Сертификаты").tag(0)
                Text("Абонементы").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if selectedTab == 0 {
                CertificatesView()
            } else {
                SubscriptionsView()
            }
        }
    }
}

// Сертификаты
struct CertificatesView: View {
    var body: some View {
        Text("Сертификаты")
            .font(.title)
            .padding()
    }
}

// Абонементы
struct SubscriptionsView: View {
    var body: some View {
        Text("Абонементы")
            .font(.title)
            .padding()
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

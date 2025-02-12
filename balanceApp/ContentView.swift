import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Главная")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Профиль")
                }
            
            MapView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Карта")
                }
            
            ChatView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Чат")
                }
        }
    }
}

// Главная
struct HomeView: View {
    var body: some View {
        Text("Главная страница")
            .font(.title)
            .padding()
    }
}

// Профиль
struct ProfileView: View {
    var body: some View {
        Text("Профиль")
            .font(.title)
            .padding()
    }
}

// Карта
struct MapView: View {
    var body: some View {
        Text("Карта")
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

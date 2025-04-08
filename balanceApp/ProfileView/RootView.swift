import SwiftUI

struct RootView: View {
    @StateObject var authVM = AuthViewModel()
    
    var body: some View {
        Group {
            if authVM.isLoggedIn {
                ContentView()
            } else {
                MainView(selectedTab: .constant(.main)) // ✅ всегда на главную
            }
            
        }
        .environmentObject(authVM) // Передаем authVM в окружение
    }
}

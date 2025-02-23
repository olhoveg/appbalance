import SwiftUI

struct SplashScreen: View {
    @State private var isActive = false
    @State private var scaleEffect: CGFloat = 0.8
    @Environment(\.colorScheme) var colorScheme // Получаем текущую тему

    var body: some View {
        ZStack {
            // Фон экрана: белый в светлой теме, черный в тёмной
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()

            VStack {
                Image("logo") // Имя логотипа в Assets.xcassets
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .scaleEffect(scaleEffect)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5)) {
                            scaleEffect = 1.2
                        }
                    }

                Text("Добро пожаловать в Баланс!")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? .white : .black) // Меняем цвет текста
                    .padding(.top, 20)
                    .opacity(scaleEffect == 1.2 ? 1 : 0)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isActive = true
                }
            }
        }
        .fullScreenCover(isPresented: $isActive) {
            ContentView() // Основной экран приложения
        }
    }
}

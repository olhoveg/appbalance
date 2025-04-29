import SwiftUI

struct AbonementBlockView: View {
    @StateObject private var viewModel = AbonementViewModel()
    @State private var activeIndex: Int = 0      // для пагинатора
    @State private var hasLoaded: Bool = false   // флаг: загрузка завершена

    private func getUserPhoneNumber() -> String? {
        UserDefaults.standard.string(forKey: "userPhone")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Проверяем авторизацию
                    if let phone = getUserPhoneNumber(), !phone.isEmpty {
                        // 1) Пока не загружено или есть уже карточки — показываем ZStack
                        if !hasLoaded || viewModel.isLoading || !viewModel.abonements.isEmpty {
                            ZStack {
                                Color.clear.frame(height: 380)

                                // 2) Если ещё идёт загрузка — skeleton-карточки
                                if !hasLoaded || viewModel.isLoading {
                                    TabView {
                                        ForEach(0..<3, id: \.self) { _ in
                                            SkeletonAbonementCardView()
                                                .padding(.horizontal)
                                        }
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 380)
                                }
                                // 3) Иначе — реальные карточки
                                else {
                                    TabView(selection: $activeIndex) {
                                        ForEach(viewModel.abonements.indices, id: \.self) { index in
                                            AbonementCardContainerView(
                                                abonement: viewModel.abonements[index],
                                                phoneNumber: phone,
                                                isLoading: false
                                            )
                                            .padding(.horizontal)
                                            .tag(index)
                                        }
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 380)
                                }
                            }
                        }

                        // Пагинатор
                        if !hasLoaded {
                            PaginationView(dots: 3, activeIndex: activeIndex)
                        } else if !viewModel.abonements.isEmpty {
                            PaginationView(dots: viewModel.abonements.count, activeIndex: activeIndex)
                        }

                        // Сообщение, если нет абонементов (показываем только после загрузки)
                        if hasLoaded && viewModel.abonements.isEmpty {
                            Text("У вас нет активных абонементов")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .padding(.top, 0)
                                .padding(.bottom, 16)
                                .multilineTextAlignment(.center)
                        }

                    } else {
                        // Неавторизован
                        Text("Абонементы недоступны. Пожалуйста, авторизуйтесь.")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    // Всегда показываем блок покупки
                    AbonementPurchaseListView()
                }
                .padding()
            }
            .onAppear {
                viewModel.fetchAbonements {
                    hasLoaded = true
                }
            }
            .refreshable {
                viewModel.fetchAbonements {
                    hasLoaded = true
                }
            }
        }
    }
}

// Контейнер для перехода skeleton ↔ real
struct AbonementCardContainerView: View {
    let abonement: Abonement
    let phoneNumber: String
    let isLoading: Bool

    var body: some View {
        ZStack {
            SkeletonAbonementCardView()
                .opacity(isLoading ? 1 : 0)
            AbonementCardView(abonement: abonement, phoneNumber: phoneNumber)
                .opacity(isLoading ? 0 : 1)
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

struct AbonementBlockView_Previews: PreviewProvider {
    static var previews: some View {
        AbonementBlockView()
            .environmentObject(ImageCache.shared)
    }
}

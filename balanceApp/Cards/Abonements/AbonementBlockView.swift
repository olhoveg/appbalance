import SwiftUI

struct AbonementBlockView: View {
    @StateObject private var viewModel = AbonementViewModel()
    @State private var activeIndex: Int = 0      // для пагинатора
    @State private var isInitialLoadCompleted = false

    private func getUserPhoneNumber() -> String? {
        UserDefaults.standard.string(forKey: "userPhone")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack(alignment: .top) {
                        Group {
                            if let phone = getUserPhoneNumber(), !phone.isEmpty {
                                if viewModel.isLoading && isInitialLoadCompleted {
                                    TabView {
                                        ForEach(0..<3, id: \.self) { _ in
                                            SkeletonAbonementCardView()
                                                .padding(.horizontal)
                                        }
                                    }
                                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                                    .frame(height: 380)

                                } else if !viewModel.abonements.isEmpty {
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

                                } else if !viewModel.isLoading && isInitialLoadCompleted && viewModel.abonements.isEmpty {
                                    Text("У вас нет активных абонементов")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 0)
                                        .padding(.bottom, 16)
                                        .multilineTextAlignment(.center)
                                }
                            } else {
                                Text("Абонементы недоступны. Пожалуйста, авторизуйтесь.")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                        }
                    }
                    if viewModel.isLoading && isInitialLoadCompleted {
                        PaginationView(dots: 3, activeIndex: activeIndex)
                    } else if !viewModel.abonements.isEmpty {
                        PaginationView(dots: viewModel.abonements.count, activeIndex: activeIndex)
                    }

                    if isInitialLoadCompleted {
                        AbonementPurchaseListView()
                    }
                }
                .padding()
            }
            .onAppear {
                viewModel.fetchAbonements {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        isInitialLoadCompleted = true
                    }
                }
            }
            .refreshable {
                viewModel.fetchAbonements {
                    isInitialLoadCompleted = true
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

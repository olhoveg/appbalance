import SwiftUI

struct AbonementBlockView: View {
    @State private var abonements: [Abonement] = []
    @State private var activeIndex: Int = 0 // Отслеживает текущую страницу
    @State private var isLoading: Bool = false
    @State private var hasLoaded: Bool = false  // Флаг: загрузка завершена (успешно или с ошибкой)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Фиксированная область для отображения карточек (высота = 400)
                    ZStack {
                        Color.clear.frame(height: 400)
                        
                        if !hasLoaded || isLoading {
                            // Пока данные ещё не получены – показываем TabView с skeleton‑версиями
                            TabView {
                                ForEach(0..<3, id: \.self) { _ in
                                    SkeletonAbonementCardView()
                                        .padding(.horizontal)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: 400)
                        } else if !abonements.isEmpty {
                            // Если данные загружены и массив не пуст – показываем реальные карточки
                            TabView(selection: $activeIndex) {
                                ForEach(abonements.indices, id: \.self) { index in
                                    AbonementCardContainerView(
                                        abonement: abonements[index],
                                        phoneNumber: getUserPhoneNumber() ?? "",
                                        isLoading: false
                                    )
                                    .padding(.horizontal)
                                    .tag(index)
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                            .frame(height: 400)
                        } else {
                            // Если загрузка завершена и массив пуст – показываем пустой контейнер (без надписи)
                            // Чтобы избежать мерцания, оставляем область пустой (цвет фона наследуется)
                            Color.clear.frame(height: 400)
                        }
                    }
                    
                    // Пагинатор – отображается всегда, если область абонементов отрисована
                    if !hasLoaded {
                        // Пока данные ещё не загружены – показываем пагинатор с 3 точками
                        PaginationView(dots: 3, activeIndex: activeIndex)
                    } else if !abonements.isEmpty {
                        PaginationView(dots: abonements.count, activeIndex: activeIndex)
                    }
                    // Если данные загружены, но массив пуст, выводим сообщение вне области карточек
                    if hasLoaded && abonements.isEmpty {
                        Text("Нет абонементов")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                    }
                    
                    // Блок покупки абонементов – всегда отрисовывается ниже
                    AbonementPurchaseListView()
                }
                .padding()
            }
            .onAppear {
                fetchAbonements()
            }
            .refreshable {
                fetchAbonements()
            }
        }
    }
    
    private func getUserPhoneNumber() -> String? {
        UserDefaults.standard.string(forKey: "userPhone")
    }
    
    private func fetchAbonements() {
        guard let phone = getUserPhoneNumber() else { return }
        isLoading = true
        let urlString = "https://api.yclients.com/api/v1/loyalty/abonements/?company_id=433675&phone=\(phone)"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/vnd.api.v2+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer 88fnh8jbmt44er5y28nj, User 9d241fb00061c17a5e2e76a23b214b20", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                self.hasLoaded = true
            }
            if let error = error {
                print("Ошибка: \(error.localizedDescription)")
                return
            }
            guard let data = data else { return }
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let response = try decoder.decode(AbonementAPIResponse.self, from: data)
                DispatchQueue.main.async {
                    self.abonements = response.data
                    // Предзагрузка изображений для всех абонементов
                    prefetchAbonementImages()
                }
            } catch {
                print("Ошибка декодирования: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func prefetchAbonementImages() {
        guard let imageCache = ImageCache.shared.cachedImages as? [String: UIImage] else { return }
        for abonement in abonements {
            let key = abonement.type.title
            // Если для ключа еще не загружено изображение, инициируем загрузку
            if imageCache[key] == nil {
                AbonementImageLoader(key: key).loadImage()
            }
        }
    }
    
    // Контейнер для плавного перехода между skeleton‑версией и реальной карточкой
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
        }
    }
}

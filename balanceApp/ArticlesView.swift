import SwiftUI
import FeedKit

// MARK: - Модель статьи
struct Article: Identifiable {
    let id = UUID()
    let title: String
    let imageUrl: String
    let content: String
    let plainContent: String  // вычисленный один раз результат удаления HTML-тегов
}

// MARK: - ViewModel для загрузки статей
class ArticlesViewModel: ObservableObject {
    @Published var articles: [Article] = []
    
    func fetchArticles() async {
        guard let feedURL = URL(string: "https://www.24balance.ru/post/rss/latest-posts") else {
            print("Invalid feed URL")
            return
        }
        
        let parser = FeedParser(URL: feedURL)
        let result = await withCheckedContinuation { continuation in
            parser.parseAsync { result in
                continuation.resume(returning: result)
            }
        }
        
        DispatchQueue.main.async {
            switch result {
            case .success(let feed):
                if let rssFeed = feed.rssFeed, let items = rssFeed.items {
                    self.articles = items.compactMap { item in
                        let title = item.title ?? "Без заголовка"
                        // Если enclosure не указан – используем placeholder
                        let imageUrl = item.enclosure?.attributes?.url ?? "https://via.placeholder.com/150"
                        let rawContent = item.description ?? ""
                        let plain = removeHTMLTags(rawContent)
                        return Article(title: title, imageUrl: imageUrl, content: rawContent, plainContent: plain)
                    }
                }
            case .failure(let error):
                print("Failed to parse feed: \(error)")
            }
        }
    }
}

// MARK: - Функция для удаления HTML-тегов
func removeHTMLTags(_ text: String) -> String {
    let wrappedText = "<html><body>" + text + "</body></html>"
    guard let data = wrappedText.data(using: .utf8) else { return text }
    do {
        let attributedString = try NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: NSNumber(value: String.Encoding.utf8.rawValue)
            ],
            documentAttributes: nil
        )
        return attributedString.string
    } catch {
        print("removeHTMLTags - Error converting HTML: \(error)")
        return text
    }
}

// MARK: - Карточка статьи (для горизонтального отображения)
struct ArticleCardView: View {
    let article: Article
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: article.imageUrl)) { phase in
                if let image = phase.image {
                    image.resizable()
                        .scaledToFill()
                        .frame(width: 200, height: 120)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Color.gray
                        .frame(width: 200, height: 120)
                        .cornerRadius(8)
                }
            }
            Text(article.title)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(article.plainContent)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
        }
        .frame(width: 200)
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Основной экран статей (горизонтальное пролистывание)
struct ArticlesView: View {
    @StateObject private var viewModel = ArticlesViewModel()
    @State private var selectedArticle: Article? = nil  // Для хранения выбранной статьи
    
    var body: some View {
        NavigationView {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.articles) { article in
                        Button(action: {
                            selectedArticle = article
                        }) {
                            ArticleCardView(article: article)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Статьи")
            .task {
                await viewModel.fetchArticles()
            }
            .refreshable {
                await viewModel.fetchArticles()
            }
            .fullScreenCover(item: $selectedArticle) { article in
                ArticleDetailsView(article: article)
            }
        }
    }
}

// MARK: - Детальный экран статьи
struct ArticleDetailsView: View {
    let article: Article
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncImage(url: URL(string: article.imageUrl)) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .scaledToFill()
                                .frame(height: 250)
                                .clipped()
                        } else {
                            Color.gray.frame(height: 250)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(article.plainContent)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Статья")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    @Environment(\.dismiss) private var dismiss
}

// MARK: - Превью
struct ArticlesView_Previews: PreviewProvider {
    static var previews: some View {
        ArticlesView()
    }
}

import SwiftUI
import FirebaseDatabase
import Firebase
import AppMetricaCore

// MARK: - Модели данных

struct CachedImageView: View {
    let url: String
    var placeholder: AnyView?
    
    @State private var uiImage: UIImage?
    @StateObject private var cache = ImageCache.shared

    var body: some View {
        Group {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
            } else {
                placeholder ?? AnyView(Color.gray)
            }
        }
        .onAppear {
            cache.loadImage(from: url) { image in
                self.uiImage = image
            }
        }
    }
}





struct Expert: Identifiable, Equatable {
    var id: String
    var name: String
    var title: String
    var experience: String
    var description: String
    var photoUrl: String
    var certificates: [ExpertCertificate]?
    var techniques: [String: String]? // Ключ – идентификатор техники, значение – название
    var skills: Skills?
    var tipUrl: String?
    var order: Int
}

struct ExpertCertificate: Identifiable, Equatable {
    var id = UUID().uuidString
    var title: String
    var imageUrl: String
}

struct Skills: Equatable {
    var massageTechnique: Double?
    var anatomyKnowledge: Double?
    var clientCommunication: Double?
    var handStrength: Double?
    var attentionToDetail: Double?
    var clinicalThinking: Double?
}

struct Technique: Identifiable, Equatable {
    var id = UUID().uuidString
    var title: String
    var description: String
    var details: [String: String]?
}

// MARK: - ViewModel

class SpecialistsViewModel: ObservableObject {
    @Published var experts: [Expert] = []
    @Published var titles: [String: String] = [:]
    
    private var ref: DatabaseReference!
    
    init() {
        ref = Database.database().reference()
        fetchExperts()
    }
    
    func fetchExperts() {
        ref.child("experts").observe(.value) { snapshot, _ in
            guard let data = snapshot.value as? [String: Any] else { return }
            
            if let titlesData = data["titles"] as? [String: String] {
                DispatchQueue.main.async {
                    self.titles = titlesData
                }
            }
            
            var expertsArray: [Expert] = []
            for (key, value) in data where key != "titles" {
                if let expertDict = value as? [String: Any],
                   let name = expertDict["name"] as? String,
                   let title = expertDict["title"] as? String,
                   let experience = expertDict["experience"] as? String,
                   let description = expertDict["description"] as? String,
                   let photoUrl = expertDict["photoUrl"] as? String,
                   let order = expertDict["order"] as? Int {
                    
                    var certificates: [ExpertCertificate] = []
                    if let certsArray = expertDict["certificates"] as? [[String: Any]] {
                        for certDict in certsArray {
                            if let certTitle = certDict["title"] as? String,
                               let imageUrl = certDict["imageUrl"] as? String {
                                certificates.append(ExpertCertificate(title: certTitle, imageUrl: imageUrl))
                            }
                        }
                    }
                    
                    var techniques: [String: String] = [:]
                    if let techs = expertDict["techniques"] as? [String: Any] {
                        for (techKey, techValue) in techs {
                            if let techName = techValue as? String {
                                techniques[techKey] = techName
                            }
                        }
                    }
                    
                    var skills: Skills? = nil
                    if let skillsDict = expertDict["skills"] as? [String: Any] {
                        skills = Skills(
                            massageTechnique: skillsDict["massageTechnique"] as? Double,
                            anatomyKnowledge: skillsDict["anatomyKnowledge"] as? Double,
                            clientCommunication: skillsDict["clientCommunication"] as? Double,
                            handStrength: skillsDict["handStrength"] as? Double,
                            attentionToDetail: skillsDict["attentionToDetail"] as? Double,
                            clinicalThinking: skillsDict["clinicalThinking"] as? Double
                        )
                    }
                    
                    let expert = Expert(
                        id: key,
                        name: name,
                        title: title,
                        experience: experience,
                        description: description,
                        photoUrl: photoUrl,
                        certificates: certificates.isEmpty ? nil : certificates,
                        techniques: techniques.isEmpty ? nil : techniques,
                        skills: skills,
                        tipUrl: expertDict["tipUrl"] as? String,
                        order: order
                    )
                    
                    expertsArray.append(expert)
                }
            }
            expertsArray.sort { $0.order < $1.order }
            DispatchQueue.main.async {
                self.experts = expertsArray
            }
        }
    }
    
    func fetchTechnique(techniqueKey: String, completion: @escaping (Technique?) -> Void) {
        ref.child("massageTechniques").child(techniqueKey).observeSingleEvent(of: .value) { snapshot, _ in
            if let techDict = snapshot.value as? [String: Any],
               let title = techDict["title"] as? String,
               let description = techDict["description"] as? String {
                let details = techDict["details"] as? [String: String]
                let technique = Technique(title: title, description: description, details: details)
                completion(technique)
            } else {
                completion(nil)
            }
        }
    }
}

// MARK: - ZoomableScrollView (UIViewRepresentable)

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    let minScale: CGFloat
    let maxScale: CGFloat

    init(minScale: CGFloat = 1.0, maxScale: CGFloat = 5.0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.minScale = minScale
        self.maxScale = maxScale
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = maxScale
        scrollView.minimumZoomScale = minScale
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.decelerationRate = .fast
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        
        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = true
        hostedView.frame = scrollView.bounds
        scrollView.addSubview(hostedView)
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.view.frame = uiView.bounds
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableScrollView
        var hostingController: UIHostingController<Content>
        
        init(_ parent: ZoomableScrollView) {
            self.parent = parent
            self.hostingController = UIHostingController(rootView: parent.content)
            self.hostingController.view.backgroundColor = .clear
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostingController.view
        }
    }
}

// MARK: - Shimmer эффект

struct Shimmer: ViewModifier {
    @State private var phase: CGFloat = -100
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        let shimmerColors: [Color] = colorScheme == .dark ?
            [Color.white.opacity(0.1), Color.white.opacity(0.3), Color.white.opacity(0.1)] :
            [Color.white.opacity(0.3), Color.white.opacity(0.7), Color.white.opacity(0.3)]
        
        return content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: shimmerColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
            )
            .mask(content)
            .onAppear {
                withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        self.modifier(Shimmer())
    }
}

// MARK: - Основной список специалистов

struct SpecialistsView: View {
    @StateObject private var viewModel = SpecialistsViewModel()
    @State private var selectedExpert: Expert?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.experts) { expert in
                        HStack(spacing: 16) {
                            CachedImageView(url: expert.photoUrl, placeholder: AnyView(
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 80, height: 80)
                            ))
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80, alignment: .top)
                            .clipped()
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expert.name)
                                    .font(.headline)
                                Text(expert.title)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("\(viewModel.titles["experienceSection"] ?? "Опыт работы"): \(expert.experience)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
                        .padding(.horizontal)
                        .onTapGesture {
                            AppMetrica.reportEvent(
                                name: "Пользователь выбрал специалиста",
                                parameters: ["имя": expert.name]
                            )
                            selectedExpert = expert
                        }
                    }
                }
            }
            .navigationTitle("Специалисты")
            .sheet(item: $selectedExpert) { expert in
                SpecialistsDetailView(expert: expert, viewModel: viewModel)
            }
        }
    }
    
    
    // MARK: - Детальное представление специалиста
    
    struct SpecialistsDetailView: View {
        var expert: Expert
        @ObservedObject var viewModel: SpecialistsViewModel
        @Environment(\.dismiss) var dismiss
        
        // Локальное состояние для техники и дипломов
        @State private var selectedTechnique: Technique?
        @State private var selectedCertificate: ExpertCertificate?
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        // Фотография с наложением информации (ФИО, опыт)
                        ZStack(alignment: .bottomLeading) {
                            CachedImageView(url: expert.photoUrl, placeholder: AnyView(
                                Color.gray.frame(height: 300)
                            ))
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 300, alignment: .top)
                            .clipped()
                            LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)]),
                                           startPoint: .center,
                                           endPoint: .bottom)
                            .frame(height: 120)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(expert.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("\(viewModel.titles["experienceSection"] ?? "Опыт работы"): \(expert.experience)")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                            }
                            .padding()
                        }
                        
                        // Остальной контент: описание, техники, скиллы, дипломы
                        VStack(alignment: .leading, spacing: 16) {
                            Text(expert.description)
                                .padding(.horizontal)
                            
                            // Техники массажа
                            if let techniques = expert.techniques {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(viewModel.titles["techniquesSection"] ?? "Техники массажа")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    ForEach(Array(techniques.keys), id: \.self) { key in
                                        HStack {
                                            Text("• \(techniques[key] ?? "")")
                                            Spacer()
                                            Button {
                                                AppMetrica.reportEvent(
                                                    name: "Пользователь открыл информацию о технике",
                                                    parameters: ["техника": techniques[key] ?? ""]
                                                )
                                                viewModel.fetchTechnique(techniqueKey: key) { technique in
                                                    if let technique = technique {
                                                        selectedTechnique = technique
                                                    }
                                                }
                                            } label: {
                                                Image(systemName: "info.circle")
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            
                            // Скиллы
                            Text(viewModel.titles["skillsSection"] ?? "Скилы")
                                .font(.headline)
                                .padding(.horizontal)
                            if let skills = expert.skills {
                                SkillBarView(skillName: viewModel.titles["massageTechnique"] ?? "Массаж", value: skills.massageTechnique ?? 0)
                                SkillBarView(skillName: viewModel.titles["anatomyKnowledge"] ?? "Анатомия", value: skills.anatomyKnowledge ?? 0)
                                SkillBarView(skillName: viewModel.titles["clientCommunication"] ?? "Коммуникация", value: skills.clientCommunication ?? 0)
                                SkillBarView(skillName: viewModel.titles["handStrength"] ?? "Сила рук", value: skills.handStrength ?? 0)
                                SkillBarView(skillName: viewModel.titles["attentionToDetail"] ?? "Внимание к деталям", value: skills.attentionToDetail ?? 0)
                                SkillBarView(skillName: viewModel.titles["clinicalThinking"] ?? "Клиническое мышление", value: skills.clinicalThinking ?? 0)
                            }
                            
                            // Дипломы
                            Text(viewModel.titles["certificatesSection"] ?? "Дипломы")
                                .font(.headline)
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    if let certificates = expert.certificates {
                                        ForEach(certificates) { certificate in
                                            VStack {
                                                CachedImageView(url: certificate.imageUrl, placeholder: AnyView(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 200, height: 150)
                                                        .shimmer()
                                                ))
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 200, height: 150)
                                                .clipped()
                                                .cornerRadius(10)
                                                Text(certificate.title)
                                                    .multilineTextAlignment(.center)
                                            }
                                            .onTapGesture {
                                                AppMetrica.reportEvent(
                                                    name: "Пользователь открыл диплом специалиста",
                                                    parameters: ["диплом": certificate.title]
                                                )
                                                selectedCertificate = certificate
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // Кнопка "Оставить чаевые"
                            if let tipUrl = expert.tipUrl, let url = URL(string: tipUrl) {
                                Button("Оставить чаевые") {
                                    AppMetrica.reportEvent(name: "Пользователь нажал 'Оставить чаевые'")
                                    UIApplication.shared.open(url)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(5)
                                .padding(.horizontal)
                            }
                        }
                        Spacer().frame(height: 40)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Закрыть") {
                            dismiss()
                        }
                    }
                }
                .sheet(item: $selectedTechnique) { technique in
                    TechniqueModalView(technique: technique)
                }
                .sheet(item: $selectedCertificate) { certificate in
                    CertificateModalView(certificate: certificate)
                }
            }
        }
    }
    
    // MARK: - Дополнительные представления
    
    struct SkillBarView: View {
        var skillName: String
        var value: Double
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(skillName)
                ProgressView(value: value, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            .padding(.horizontal)
        }
    }
    
    // Модальное окно для диплома с использованием ZoomableScrollView
    struct CertificateModalView: View, Identifiable {
        let id = UUID()
        var certificate: ExpertCertificate
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationView {
                VStack {
                    Text(certificate.title)
                        .font(.title)
                        .padding()
                    ZoomableScrollView {
                        CachedImageView(url: certificate.imageUrl, placeholder: AnyView(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .shimmer()
                        ))
                        .aspectRatio(contentMode: .fit)
                    }
                }
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
    }
    
    struct TechniqueModalView: View, Identifiable {
        let id = UUID()
        var technique: Technique
        @Environment(\.dismiss) var dismiss
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(technique.title)
                            .font(.largeTitle)
                            .bold()
                        
                        Text(technique.description)
                            .font(.body)
                        
                        if let details = technique.details {
                            ForEach(details.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                let cleanedKey = key.replacingOccurrences(of: #"^\d+_"#, with: "", options: .regularExpression)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(cleanedKey)
                                        .font(.headline)
                                    Text(value)
                                        .font(.body)
                                }
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                }
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
    }
    
    // MARK: - Previews
    
    struct SpecialistsView_Previews: PreviewProvider {
        static var previews: some View {
            SpecialistsView()
        }
    }
}

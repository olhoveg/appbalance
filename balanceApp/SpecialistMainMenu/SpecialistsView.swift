import SwiftUI
import FirebaseDatabase
import Firebase

// MARK: - Модели данных

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
                            AsyncImage(url: URL(string: expert.photoUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80, alignment: .top) // выравнивание по верхней части
                                    .clipped()
                                    .clipShape(Circle())
                            } placeholder: {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 80, height: 80)
                            }
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
                            selectedExpert = expert
                        }
                    }
                }
            }
            .navigationTitle("Специалисты")
            // Детальное окно специалиста открывается как sheet
            .sheet(item: $selectedExpert) { expert in
                SpecialistsDetailView(expert: expert, viewModel: viewModel)
            }
        }
    }
}

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




// MARK: - Детальное представление специалиста

struct SpecialistsDetailView: View {
    var expert: Expert
    @ObservedObject var viewModel: SpecialistsViewModel
    @Environment(\.dismiss) var dismiss

    // Локальное состояние для техники
    @State private var selectedTechnique: Technique?
    // Локальное состояние для диплома
    @State private var selectedCertificate: ExpertCertificate?
    
    // Переменная для зума в CertificateModalView
    @State private var certificateScale: CGFloat = 1.0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Зона фотографии с наложением информации о специалисте
                    ZStack(alignment: .bottomLeading) {
                        AsyncImage(url: URL(string: expert.photoUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 300, alignment: .top)
                                .clipped()
                        } placeholder: {
                            Color.gray.frame(height: 300)
                        }
                        
                        // Наложение с градиентом для читаемости текста
                        LinearGradient(gradient: Gradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)]),
                                       startPoint: .center,
                                       endPoint: .bottom)
                            .frame(height: 120)
                        
                        // Текст с ФИО и стажем (опыт работы)
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
                    
                    // Остальной контент: описание, техники, скиллы, дипломы и т.д.
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
                                            AsyncImage(url: URL(string: certificate.imageUrl)) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 200, height: 150)
                                                    .clipped()
                                                    .cornerRadius(10)
                                            } placeholder: {
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 200, height: 150)
                                                    .shimmer()
                                            }
                                            Text(certificate.title)
                                                .multilineTextAlignment(.center)
                                        }
                                        .onTapGesture {
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
            // Модальное окно для техники (поверх окна специалиста)
            .sheet(item: $selectedTechnique) { technique in
                TechniqueModalView(technique: technique)
            }
            // Модальное окно для диплома (поверх окна специалиста)
            .sheet(item: $selectedCertificate) { certificate in
                CertificateModalView(certificate: certificate, scale: $certificateScale)
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

struct CertificateModalView: View, Identifiable {
    let id = UUID()
    var certificate: ExpertCertificate
    @Binding var scale: CGFloat
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    VStack {
                        Text(certificate.title)
                            .font(.title)
                            .padding()
                        AsyncImage(url: URL(string: certificate.imageUrl)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height * 0.8
                                )
                                .scaleEffect(scale)
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            scale = value
                                        }
                                        .onEnded { _ in
                                            withAnimation {
                                                scale = 1.0
                                            }
                                        }
                                )
                                .padding()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height * 0.8
                                )
                                .shimmer() // применяем shimmer эффект
                        }
                    }
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

struct SpecialistsView_Previews: PreviewProvider {
    static var previews: some View {
        SpecialistsView()
    }
}

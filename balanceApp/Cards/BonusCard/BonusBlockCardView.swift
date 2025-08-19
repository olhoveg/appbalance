import SwiftUI
import FirebaseDatabase

struct BonusBlockCardView: View {
    let bonusCard: BonusCard
    @State private var imageUrl: String? = nil
    @StateObject private var imageCache = ImageCache()
    @State private var loadedImage: UIImage? = nil
    @State private var imageLoaded: Bool = false    // New state for animation
    @State private var showingDetail = false
    
    var body: some View {
        ZStack {
            // Skeleton placeholder shown while the card loads
            VStack(spacing: 12) {
                // Grey rectangle where the card image will appear
                Color.gray.opacity(0.2)
                    .frame(height: 200)
                    .cornerRadius(12)

                // Grey bars imitating the “Баланс” caption and the amount
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Color.gray.opacity(0.2)
                            .frame(width: 70, height: 18)
                            .cornerRadius(4)

                        Color.gray.opacity(0.2)
                            .frame(width: 110, height: 22)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal)
            .opacity(imageLoaded ? 0 : 1)

            VStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    // Container for image and placeholder with fade animation
                    ZStack {
                        // Placeholder
                        Color.gray.opacity(0.2)
                            .frame(height: 200)
                            .overlay(ProgressView())
                            .clipped()
                            .opacity(imageLoaded ? 0 : 1)

                        // Loaded image
                        if let image = loadedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipped()
                                .opacity(imageLoaded ? 1 : 0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)

                    // Номер карты, отображается справа сверху
                    Text("№ \(bonusCard.number)")
                        .font(.subheadline)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding([.top, .trailing], 12)
                }

                // Баланс карты, красиво оформленный под изображением
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Баланс")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.2f", bonusCard.balance)) ₽")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.blue)
                    }
                    Spacer()
                }
            }
            .opacity(imageLoaded ? 1 : 0)
            .padding(.horizontal)
        }
        .animation(.easeInOut(duration: 0.4), value: imageLoaded)
        .onTapGesture {
            showingDetail = true
        }
        .onAppear {
            print("🎯 BonusBlockCardView appeared for card: \(bonusCard.number)")
            print("🎯 Card balance: \(bonusCard.balance)")
            print("🎯 Card type: \(bonusCard.type.title)")
            fetchBonusCardImage()
        }
        .sheet(isPresented: $showingDetail) {
            BonusCardDetailView(bonusCard: bonusCard)
        }
    }
    
    private func fetchBonusCardImage() {
        print("🖼️ Fetching bonus card image for type: \(bonusCard.type.title)")
        
        let dbRef = Database.database(url: "https://balance-ddb48-default-rtdb.europe-west1.firebasedatabase.app").reference()
        let ref = dbRef.child("bonuscard_image")
        
        print("🔥 Querying Firebase for bonuscard_image...")
        
        ref.observeSingleEvent(of: .value) { snapshot in
            print("🔥 Firebase response received")
            if let dict = snapshot.value as? [String: Any] {
                print("🔥 Firebase data received: \(dict.keys)")
                
                // выбираем URL как ранее
                var selectedURL: String? = nil
                if let title = dict["title"] as? String,
                   let url = dict["image_url"] as? String,
                   title.lowercased() == bonusCard.type.title.lowercased() {
                    print("🖼️ Found direct match for title: \(title)")
                    selectedURL = url
                } else if let nested = dict[bonusCard.type.title] as? [String: Any],
                          let nestedUrl = nested["image_url"] as? String {
                    print("🖼️ Found nested match for title: \(bonusCard.type.title)")
                    selectedURL = nestedUrl
                } else {
                    print("❌ No image found for card type: \(bonusCard.type.title)")
                    print("❌ Available titles in Firebase: \(dict.keys)")
                }
                
                DispatchQueue.main.async {
                    self.imageUrl = selectedURL
                    if let urlString = selectedURL {
                        print("🖼️ Loading image from URL: \(urlString)")
                        imageCache.loadImage(from: urlString) { img in
                            if img != nil {
                                print("✅ Image loaded successfully")
                            } else {
                                print("❌ Failed to load image")
                            }
                            loadedImage = img
                            withAnimation {
                                imageLoaded = true
                            }
                        }
                    } else {
                        print("❌ No image URL found, showing placeholder")
                        withAnimation {
                            imageLoaded = true
                        }
                    }
                }
            } else {
                print("❌ No data found in Firebase bonuscard_image")
            }
        }
    }
}

struct BonusBlockCardView_Previews: PreviewProvider {
    static var previews: some View {
        BonusBlockCardView(bonusCard: BonusCard(
            id: 51883748,
            number: "777",
            balance: 798.55,
            points: 0,
            paidAmount: 26934,
            soldAmount: 53118,
            visitsCount: 410,
            typeId: 45913,
            salonGroupId: 415038,
            maxDiscountPercent: 0,
            maxDiscountAmount: 0,
            type: BonusCardType(
                id: 45913,
                title: "Бонусная карта",
                salonGroupId: 415038,
                serviceItemType: "any_allowed",
                goodItemType: "any_allowed"
            ),
            transactions: [
                BonusCardTransaction(
                    type: "Начисление", 
                    amount: 100, 
                    date: Date(),
                    description: "Начисление за покупку услуги",
                    serviceName: "Массаж"
                ),
                BonusCardTransaction(
                    type: "Списание", 
                    amount: 50, 
                    date: Date(),
                    description: "Оплата услуги бонусами",
                    serviceName: "Маникюр"
                )
            ],
            programs: nil
        ))
        .previewLayout(.sizeThatFits)
    }
}

// Представление для отображения программ лояльности
struct LoyaltyProgramsView: View {
    let card: BonusCard
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Заголовок
                    VStack(spacing: 8) {
                        Text("Программы лояльности")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Карта №\(card.number)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Список программ
                    if let programs = card.programs, !programs.isEmpty {
                        LazyVStack(spacing: 12) {
                            ForEach(programs, id: \.id) { program in
                                LoyaltyProgramCard(program: program)
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "star.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            
                            Text("Нет активных программ")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// Карточка программы лояльности
struct LoyaltyProgramCard: View {
    let program: LoyaltyProgram
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок программы
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(program.loyaltyType.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Процент кешбэка
                VStack(spacing: 2) {
                    Text("\(program.value)%")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("кешбэк")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Описание программы
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                
                Text("Нажмите для подробностей")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// Детальное представление программы лояльности
struct LoyaltyProgramDetailView: View {
    let program: LoyaltyProgram
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Заголовок с кешбэком
                    VStack(spacing: 16) {
                        // Большой процент кешбэка
                        VStack(spacing: 8) {
                            Text("\(program.value)%")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.green)
                            
                            Text("кешбэк")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.green.opacity(0.1),
                                    Color.green.opacity(0.05)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // Название программы
                        Text(program.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Информация о программе
                    VStack(spacing: 16) {
                        InfoCard(
                            icon: "star.fill",
                            title: "Тип программы",
                            description: program.loyaltyType.title,
                            color: .orange
                        )
                        
                        InfoCard(
                            icon: program.loyaltyType.isCashback ? "dollarsign.circle.fill" : "percent",
                            title: "Тип начисления", 
                            description: program.loyaltyType.isCashback ? "Кешбэк" : "Скидка",
                            color: .blue
                        )
                        
                        if program.loyaltyType.isStatic {
                            InfoCard(
                                icon: "equal.circle.fill",
                                title: "Система начисления",
                                description: "Фиксированный процент",
                                color: .purple
                            )
                        }
                        
                        InfoCard(
                            icon: "creditcard.fill",
                            title: "Применение",
                            description: getApplicationDescription(),
                            color: .indigo
                        )
                        
                        // Единица измерения
                        InfoCard(
                            icon: "number.circle.fill",
                            title: "Единица измерения",
                            description: program.valueUnit == "percent" ? "Проценты" : program.valueUnit,
                            color: .teal
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Программа лояльности")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Закрыть") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func getApplicationDescription() -> String {
        var description = ""
        
        if program.serviceItemType == "any_allowed" {
            description += "Все услуги"
        } else if program.serviceItemType == "custom_allowed" {
            description += "Выбранные услуги"
        } else {
            description += "Услуги не включены"
        }
        
        if program.goodItemType == "any_allowed" {
            if !description.isEmpty { description += ", " }
            description += "все товары"
        } else if program.goodItemType == "custom_allowed" {
            if !description.isEmpty { description += ", " }
            description += "выбранные товары"
        }
        
        return description.isEmpty ? "Не указано" : description
    }
}

// Карточка с информацией
struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(description)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}



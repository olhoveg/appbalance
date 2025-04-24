//
//  MainView.swift
//  balanceApp
//
//  Created by Evgeniy Olkhov on 20.02.2025.
//

import SwiftUI
import OneSignalFramework

struct MainView: View {
    @Binding var selectedTab: Tab
    @StateObject var recordViewModel = RecordViewModel.sharedInstance
    @StateObject var bonusCardVM = LoyaltyBonusCardViewModel()      // для бонусных карт
    @StateObject var abonementVM = LoyaltyAbonementViewModel()        // для абонементов
    @StateObject var certificateVM = LoyaltyCertificateViewModel()    // для сертификатов
    @AppStorage("userPhone") var userPhone: String = ""
    // Создаем единый viewModel для сторис
    @StateObject var storiesVM = StoriesViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                CustomNavigationBar()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Stories остаются всегда
                        StoriesView(viewModel: storiesVM)
                        
                        // Если пользователь не авторизован — показываем кнопку «Войти» и пропускаем блоки личного кабинета
                        if userPhone.isEmpty {
                            NavigationLink(destination: ProfileView()) {
                                Text("Войти")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        } else {
                            // Запись на солярий
                            Button(action: {
                                selectedTab = .solarium
                            }) {
                                Text("Записаться")
                                    .font(.headline)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            
                            // Личный блок
                            RecordView(viewModel: recordViewModel)
                            Divider()
                            BalanceBlockView()
                            Divider()
                            LoyaltyBonusCardMainView(viewModel: bonusCardVM)
                            Divider()
                            LoyaltyAbonementMainView(viewModel: abonementVM)
                            Divider()
                            LoyaltyCertificateMainView(viewModel: certificateVM)
                        }
                        
                        // Рекомендации, услуги и статьи отображаются всегда
                        Divider()
                        RecommendationsBlockView()
                    }
                    .padding(.vertical)
                }
                .ignoresSafeArea(edges: .horizontal)
                .refreshable {
                    print("MainView: Refreshable вызван – обновляем данные всех блоков.")
                    recordViewModel.refreshData()
                    if !userPhone.isEmpty {
                        bonusCardVM.fetchBonusCards(phone: userPhone)
                        abonementVM.fetchAbonements(phone: userPhone)
                        certificateVM.fetchCertificates(phone: userPhone)
                        // Обновляем сторис
                        storiesVM.fetchStories()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                OneSignalService.shared.requestPermissionIfNeeded()
                
                if !userPhone.isEmpty {
                    OneSignalService.shared.setExternalUserId(userPhone)
                }
            }
        }
    }
}


    
    
    



// MARK: - Кастомный NavigationBar
struct CustomNavigationBar: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            NavigationLink(destination: ProfileView()) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 30, height: 30)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .padding(10)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(1)
            
            Spacer()
            
            Text("Главная")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Spacer()
            
            HStack(spacing: 15) {
                Button(action: {
                    if let url = URL(string: "https://wa.me/79615805108") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "message.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.green)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: {
                    if let url = URL(string: "tel://+79615805108") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Image(systemName: "phone.fill")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .shadow(color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}



// MARK: - Пример блока рекомендаций
struct RecommendationsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Рекомендации")
                .font(.headline)
                .padding(.leading)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(0..<5, id: \.self) { index in
                        NavigationLink(destination: RecommendationDetailView(id: index)) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green)
                                .frame(width: 150, height: 100)
                                .overlay(Text("Рекомендация \(index + 1)").foregroundColor(.white))
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}



// MARK: - Детальные страницы
struct RecommendationDetailView: View {
    var id: Int
    var body: some View {
        Text("Детальная страница рекомендации \(id + 1)")
            .font(.largeTitle)
    }
}

struct ArticleDetailView: View {
    var id: Int
    var body: some View {
        Text("Детальная страница статьи \(id + 1)")
            .font(.largeTitle)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            MainView(selectedTab: .constant(.main))
        }
    }
}

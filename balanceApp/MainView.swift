//
//  MainView.swift
//  balanceApp
//
//  Created by Evgeniy Olkhov on 20.02.2025.
//

import SwiftUI
import OneSignalFramework
import AppMetricaCore

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
                        .simultaneousGesture(TapGesture().onEnded {
                            AppMetrica.reportEvent(name: "Пользователь нажал на кнопку 'Войти'")
                        })
                    } else {
                        // Запись на солярий
                        Button(action: {
                            AppMetrica.reportEvent(name: "Пользователь нажал на кнопку 'Записаться'")
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
                    bonusCardVM.refreshBonusCards(phone: userPhone)
                    abonementVM.fetchAbonements(phone: userPhone)
                    certificateVM.fetchCertificates(phone: userPhone)
                    // Обновляем сторис
                    storiesVM.fetchStories()
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                OneSignalService.shared.requestPermissionIfNeeded()
                
                if !userPhone.isEmpty {
                    OneSignalService.shared.setExternalUserId(userPhone)
                    // Загружаем данные при первом открытии
                    bonusCardVM.refreshBonusCards(phone: userPhone)
                    abonementVM.fetchAbonements(phone: userPhone)
                    certificateVM.fetchCertificates(phone: userPhone)
                }
            }
        }
    }
}


    
    
    



// MARK: - Кастомный NavigationBar
struct CustomNavigationBar: View {
    @Environment(\.colorScheme) var colorScheme
    @StateObject private var balanceViewModel = BalanceBlockViewModel()
    @AppStorage("userPhone") var userPhone: String = ""

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
            .simultaneousGesture(TapGesture().onEnded {
                AppMetrica.reportEvent(name: "Пользователь нажал на иконку профиля")
            })
            .zIndex(1)
            
            Spacer()
            
            // Личный счет по центру (только для авторизованных пользователей)
            if !userPhone.isEmpty && balanceViewModel.balanceLoaded {
                HStack(spacing: 8) {
                    Image(systemName: "rublesign.circle.fill")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.green)
                    Text("\(balanceViewModel.balance) ₽")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
            
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
                .simultaneousGesture(TapGesture().onEnded {
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку чата")
                })
                
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
                .simultaneousGesture(TapGesture().onEnded {
                    AppMetrica.reportEvent(name: "Пользователь нажал на иконку телефона")
                })
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .shadow(color: colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .onAppear {
            if !userPhone.isEmpty {
                balanceViewModel.fetchData()
            }
        }
        .onChange(of: userPhone) { newPhone in
            if !newPhone.isEmpty {
                balanceViewModel.fetchData()
            } else {
                balanceViewModel.resetBalance()
            }
        }
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
        MainView(selectedTab: .constant(.main))
    }
}

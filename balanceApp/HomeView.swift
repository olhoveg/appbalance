import SwiftUI
import Firebase
import FirebaseFirestore

struct HomeView: View {
    @State private var messages: [String] = [] // Список для данных из Firestore

    var body: some View {
        VStack {
            List(messages, id: \.self) { message in
                Text(message)
            }
            
            Button("Добавить тестовые данные") {
                addTestDataToFirestore()
            }
            .padding()
        }
        .onAppear {
            fetchDataFromFirestore()
        }
        // Скрываем навигационную панель, чтобы не было кнопок "назад" и прочего
        .navigationBarHidden(true)
    }
    
    // Функция добавления тестовых данных
    func addTestDataToFirestore() {
        let db = Firestore.firestore()
        let testMessage = ["message": "Привет из Firestore! \(Int.random(in: 1...100))"]
        
        db.collection("messages").addDocument(data: testMessage) { error in
            if let error = error {
                print("Ошибка при добавлении данных: \(error.localizedDescription)")
            } else {
                print("Данные успешно добавлены!")
                fetchDataFromFirestore() // Обновляем список после добавления
            }
        }
    }
    
    // Функция загрузки данных из Firestore
    func fetchDataFromFirestore() {
        let db = Firestore.firestore()
        
        db.collection("messages").getDocuments { snapshot, error in
            if let error = error {
                print("Ошибка при загрузке данных: \(error.localizedDescription)")
                return
            }
            
            if let snapshot = snapshot {
                messages = snapshot.documents.compactMap { document in
                    document["message"] as? String
                }
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

import SwiftUI

struct CertificateCardView: View {
    let certificate: Certificate

    var body: some View {
        VStack {
            if let imageUrl = certificate.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.gray)
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 200)
                .cornerRadius(20)
                .padding()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .foregroundColor(.gray)
                    .cornerRadius(20)
                    .padding()
            }

            Text("Сертификат № \(certificate.number)")
                .font(.title2)
                .bold()
                .padding(.bottom, 5)

            Text("Баланс: \(certificate.balance) руб.")
                .font(.headline)
                .foregroundColor(.green)

            Text("Дата покупки: \(formatDate(certificate.createdDate))")
                .font(.subheadline)
                .foregroundColor(.gray)

            Text("Срок окончания: \(formatDate(certificate.expirationDate) ?? "Бессрочный")")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 5)
    }

    private func formatDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct CertificateCardView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateCardView(certificate: Certificate(
            id: 409726,
            number: "888",
            balance: 9000,
            defaultBalance: 9000,
            typeID: 27841,
            statusID: 2,
            createdDate: Date(),
            expirationDate: nil,
            imageUrl: nil,
            type: CertificateType(title: "Массаж"),
            status: CertificateStatus(name: "Активен")
        ))
            .previewLayout(.sizeThatFits)
            .padding()
    }
}

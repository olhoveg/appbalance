import Foundation
import CryptoKit

class VKCloudUploader {
    static let shared = VKCloudUploader()
    
    private let accessKey = "4KzCbTtC2Egv1fj5mQ48qZ"
    private let secretKey = "2GW6MS974aFZgkXpuJog24BRVdTbcea9eq5NTb9LXDbR"
    private let bucketName = "24balancemp"
    private let service = "s3"
    private let region = "ru-msk"
    private let host = "hb.ru-msk.vkcloud-storage.ru"
    
    private init() {}
    
    private var progressObservations: [NSKeyValueObservation] = []
    
    private func nowDate() -> (String, String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let amzDate = formatter.string(from: Date())
        
        formatter.dateFormat = "yyyyMMdd"
        let dateStamp = formatter.string(from: Date())
        return (amzDate, dateStamp)
    }
    
    private func sign(key: Data, message: String) -> Data {
        let key = SymmetricKey(data: key)
        let data = message.data(using: .utf8)!
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(signature)
    }
    
    private func getSignatureKey(key: String, dateStamp: String, regionName: String, serviceName: String) -> Data {
        let kDate = sign(key: ("AWS4" + key).data(using: .utf8)!, message: dateStamp)
        let kRegion = sign(key: kDate, message: regionName)
        let kService = sign(key: kRegion, message: serviceName)
        let kSigning = sign(key: kService, message: "aws4_request")
        return kSigning
    }
    
    /// Загрузить файл
    func upload(
        fileURL: URL,
        fileName: String,
        progress: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let (amzDate, dateStamp) = nowDate()
        let objectKey = fileName
        let canonicalURI = "/\(objectKey)"
        let method = "PUT"

        let payloadDigest = SHA256.hash(data: try! Data(contentsOf: fileURL))
        let payloadHash = Data(payloadDigest).map { String(format: "%02x", $0) }.joined()

        let canonicalHeaders =
            "host:\(bucketName).\(host)\n" +
            "x-amz-acl:public-read\n" +
            "x-amz-content-sha256:\(payloadHash)\n" +
            "x-amz-date:\(amzDate)\n"
        let signedHeaders = "host;x-amz-acl;x-amz-content-sha256;x-amz-date"
        let canonicalRequest =
            "\(method)\n\(canonicalURI)\n\n\(canonicalHeaders)\n\(signedHeaders)\n\(payloadHash)"

        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let canonicalRequestDigest = SHA256.hash(data: canonicalRequest.data(using: .utf8)!)
        let stringToSign =
            "\(algorithm)\n\(amzDate)\n\(credentialScope)\n\(Data(canonicalRequestDigest).map { String(format: "%02x", $0) }.joined())"

        let signingKey = getSignatureKey(key: secretKey, dateStamp: dateStamp, regionName: region, serviceName: service)
        let signatureData = HMAC<SHA256>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: SymmetricKey(data: signingKey))
        let signature = Data(signatureData).map { String(format: "%02x", $0) }.joined()

        let authorizationHeader =
            "\(algorithm) Credential=\(accessKey)/\(credentialScope), " +
            "SignedHeaders=\(signedHeaders), Signature=\(signature)"

        let uploadURL = URL(string: "https://\(bucketName).\(host)/\(objectKey)")!
        var request = URLRequest(url: uploadURL)
        request.httpMethod = method
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")
        request.setValue("public-read", forHTTPHeaderField: "x-amz-acl")

        let task = URLSession.shared.uploadTask(with: request, fromFile: fileURL) { _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(uploadURL))
                }
            }
        }

        let obs = task.progress.observe(\.fractionCompleted) { prog, _ in
            DispatchQueue.main.async {
                progress(prog.fractionCompleted)
            }
        }
        progressObservations.append(obs)

        task.resume()
    }
    
    /// Удалить файл
    func delete(
        fileName: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let (amzDate, dateStamp) = nowDate()
        let objectKey = fileName
        let canonicalURI = "/\(objectKey)"
        let method = "DELETE"

        let payloadHash = SHA256.hash(data: Data()).map { String(format: "%02x", $0) }.joined()

        let canonicalHeaders =
            "host:\(bucketName).\(host)\n" +
            "x-amz-content-sha256:\(payloadHash)\n" +
            "x-amz-date:\(amzDate)\n"
        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"
        let canonicalRequest =
            "\(method)\n\(canonicalURI)\n\n\(canonicalHeaders)\n\(signedHeaders)\n\(payloadHash)"

        let algorithm = "AWS4-HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let canonicalRequestDigest = SHA256.hash(data: canonicalRequest.data(using: .utf8)!)
        let stringToSign =
            "\(algorithm)\n\(amzDate)\n\(credentialScope)\n\(Data(canonicalRequestDigest).map { String(format: "%02x", $0) }.joined())"

        let signingKey = getSignatureKey(key: secretKey, dateStamp: dateStamp, regionName: region, serviceName: service)
        let signatureData = HMAC<SHA256>.authenticationCode(for: stringToSign.data(using: .utf8)!, using: SymmetricKey(data: signingKey))
        let signature = Data(signatureData).map { String(format: "%02x", $0) }.joined()

        let authorizationHeader =
            "\(algorithm) Credential=\(accessKey)/\(credentialScope), " +
            "SignedHeaders=\(signedHeaders), Signature=\(signature)"

        let deleteURL = URL(string: "https://\(bucketName).\(host)/\(objectKey)")!
        var request = URLRequest(url: deleteURL)
        request.httpMethod = method
        request.setValue(payloadHash, forHTTPHeaderField: "x-amz-content-sha256")
        request.setValue(amzDate, forHTTPHeaderField: "x-amz-date")
        request.setValue(authorizationHeader, forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { _, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }

        task.resume()
    }
}

// MARK: - Утилита

private extension Data {
    var hexString: String {
        self.map { String(format: "%02x", $0) }.joined()
    }
}

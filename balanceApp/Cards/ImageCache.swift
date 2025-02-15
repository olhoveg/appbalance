//
//  ImageCache.swift
//  balanceApp
//
//  Created by Evgen on 15.02.2025.
//

import SwiftUI

class ImageCache: ObservableObject {
    @Published var cachedImages: [String: UIImage] = [:]

    func loadImage(from url: String, completion: @escaping (UIImage?) -> Void) {
        if let cachedImage = cachedImages[url] {
            completion(cachedImage)
            return
        }

        guard let imageUrl = URL(string: url) else {
            completion(nil)
            return
        }

        DispatchQueue.global(qos: .background).async {
            if let data = try? Data(contentsOf: imageUrl), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.cachedImages[url] = image
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
}

import Foundation

struct ProductInfo {
    var name: String
    var category: Category?
}

/// Looks up a barcode in Open Food Facts, a free, open product database.
enum ProductLookup {
    static func lookup(_ barcode: String) async -> ProductInfo? {
        guard let code = barcode.addingPercentEncoding(withAllowedCharacters: .alphanumerics),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=product_name,product_name_en,brands,quantity,categories_tags")
        else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        request.setValue("Stocked/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            guard decoded.status == 1, let product = decoded.product else { return nil }

            let brand = product.brands?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
            let title = product.product_name_en.nonEmpty ?? product.product_name.nonEmpty ?? ""
            guard !title.isEmpty || !brand.isEmpty else { return nil }

            var name = title
            if !brand.isEmpty, !title.localizedCaseInsensitiveContains(brand) {
                name = title.isEmpty ? brand : "\(brand) \(title)"
            }
            if let size = product.quantity.nonEmpty, !name.localizedCaseInsensitiveContains(size) {
                name += " \(size)"
            }
            return ProductInfo(name: name, category: guessCategory(product.categories_tags ?? []))
        } catch {
            return nil
        }
    }

    /// Maps Open Food Facts category tags to a kitchen category.
    static func guessCategory(_ tags: [String]) -> Category? {
        let all = tags.joined(separator: " ")
        let rules: [(Category, [String])] = [
            (.freezer, ["frozen", "ice-creams"]),
            (.herbs, ["spices", "herbs", "seasonings", "condiments-in-powder", "peppers"]),
            (.tinned, ["canned", "tinned"]),
            (.fridge, ["dairies", "cheeses", "yogurts", "fresh", "meats", "eggs", "butters", "chilled", "hams", "sausages", "fish"]),
            (.dry, ["pastas", "rices", "cereals", "flours", "breakfasts", "snacks", "biscuits", "legumes", "dried", "sugars", "teas", "coffees", "crackers", "noodles"]),
        ]
        for (category, words) in rules where words.contains(where: { all.contains($0) }) {
            return category
        }
        return nil
    }

    private struct Response: Decodable {
        let status: Int?
        let product: Product?
    }

    private struct Product: Decodable {
        let product_name: String?
        let product_name_en: String?
        let brands: String?
        let quantity: String?
        let categories_tags: [String]?
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}

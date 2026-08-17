import Foundation

enum JsonEditorAPI {
    private static let baseURL = "https://api.jsoneditoronline.org/v2"
    private static let referer = "https://jsoneditoronline.org/"

    private static func request(method: String, path: String, body: Data? = nil) throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw JCloudError.invalidResponse
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(referer, forHTTPHeaderField: "Referer")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }

        var resultData: Data?
        var resultError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        URLSession.shared.dataTask(with: req) { data, response, error in
            defer { semaphore.signal() }
            if let error { resultError = error; return }
            guard let http = response as? HTTPURLResponse else {
                resultError = JCloudError.invalidResponse; return
            }
            guard (200..<300).contains(http.statusCode) else {
                let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                resultError = JCloudError.http(http.statusCode, body)
                return
            }
            resultData = data
        }.resume()

        semaphore.wait()
        if let error = resultError { throw error }
        return resultData ?? Data()
    }

    static func create(name: String, content: String) throws -> String {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let data = try request(method: "POST", path: "/docs?name=\(encoded)", body: content.data(using: .utf8))
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = json["_id"] as? String else {
            throw JCloudError.missingField("_id")
        }
        return id
    }

    static func read(id: String) throws -> String {
        let data = try request(method: "GET", path: "/docs/\(id)/data")
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func update(id: String, content: String) throws {
        _ = try request(method: "PUT", path: "/docs/\(id)/data", body: content.data(using: .utf8))
    }

    static func delete(id: String) throws {
        _ = try request(method: "DELETE", path: "/docs/\(id)")
    }
}

import Foundation

struct OllamaMessage: Codable {
    let role: String
    let content: String
}

struct OllamaRequest: Codable {
    let model: String
    let messages: [OllamaMessage]
}

struct OllamaResponse: Codable {
    let message: OllamaMessage
}

class OllamaClient {
    static let shared = OllamaClient()
    let baseURL = URL(string: "http://localhost:11434/api/chat")!

    func chat(model: String, messages: [OllamaMessage], completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OllamaRequest(model: model, messages: messages)
        request.httpBody = try? JSONEncoder().encode(body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Ollama 请求错误：\(error)")
            }
            guard let data, error == nil else {
                completion(nil)
                return
            }
            if let str = String(data: data, encoding: .utf8) {
                print("Ollama 返回内容：\(str)")
                let lines = str.split(separator: "\n")
                let allContents = lines.compactMap { line -> String? in
                    if let jsonData = line.data(using: .utf8),
                       let decoded = try? JSONDecoder().decode(OllamaResponse.self, from: jsonData) {
                        return decoded.message.content
                    }
                    return nil
                }
                completion(allContents.joined())
            } else {
                completion(nil)
            }
        }.resume()
    }
}

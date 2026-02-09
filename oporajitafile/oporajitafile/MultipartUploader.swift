//
//  MultipartUploader.swift
//  oporajitafile
//
//  Created by Adib Anwar on 9/2/26.
//


import Foundation

enum MultipartUploader {
    static func upload(
        to url: URL,
        fieldName: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        additionalFields: [String: String],
        headers: [String: String]
    ) async throws {

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        var body = Data()

        for (k, v) in additionalFields {
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Disposition: form-data; name=\"\(k)\"\r\n\r\n")
            body.appendString("\(v)\r\n")
        }

        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")

        request.httpBody = body

        let (respData, resp) = try await URLSession.shared.data(for: request)
        guard let http = resp as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: respData, encoding: .utf8) ?? ""
            throw NSError(domain: "UploadError", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Server returned \(http.statusCode): \(msg)"
            ])
        }
    }
}

private extension Data {
    mutating func appendString(_ s: String) {
        if let d = s.data(using: .utf8) { append(d) }
    }
}
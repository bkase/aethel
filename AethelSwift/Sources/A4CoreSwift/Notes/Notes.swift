import Foundation

public enum FrontMatterSplit: Sendable {
    case none(body: Data)
    case present(header: Data, body: Data)

    public var header: Data? {
        switch self {
        case .none:
            return nil
        case .present(let header, _):
            return header
        }
    }

    public var body: Data {
        switch self {
        case .none(let body):
            return body
        case .present(_, let body):
            return body
        }
    }
}

public enum Notes {
    public static func splitFrontMatter(_ bytes: Data) -> FrontMatterSplit {
        guard let content = String(data: bytes, encoding: .utf8) else {
            return .none(body: bytes)
        }

        let lines = content.components(separatedBy: "\n")

        guard lines.count >= 3,
              lines[0] == "---"
        else {
            return .none(body: bytes)
        }

        for i in 1..<lines.count {
            if lines[i] == "---" {
                let headerLines = lines[1..<i]
                let bodyLines = lines[(i + 1)...]

                let headerContent = headerLines.joined(separator: "\n")
                let bodyContent = bodyLines.joined(separator: "\n")

                if let headerData = headerContent.data(using: .utf8),
                   let bodyData = bodyContent.data(using: .utf8)
                {
                    return .present(header: headerData, body: bodyData)
                }
            }
        }

        return .none(body: bytes)
    }

    public static func joinFrontMatter(header: Data?, body: Data) -> Data {
        guard let header = header else {
            return body
        }

        var result = Data()

        result.append("---\n".data(using: .utf8)!)

        result.append(header)

        if !header.isEmpty {
            let lastByte = header[header.count - 1]
            if lastByte != 10 {  // '\n' is 10 in ASCII
                result.append("\n".data(using: .utf8)!)
            }
        }

        result.append("---\n".data(using: .utf8)!)

        result.append(body)

        return result
    }
}
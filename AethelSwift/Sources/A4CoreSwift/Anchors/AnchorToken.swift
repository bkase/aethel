import Foundation

public struct AnchorToken: Equatable, Sendable {
    public let prefix: String
    public let hhmm: String
    public let suffix: String?

    public init(parse token: String) throws {
        let pattern = #"^([a-z][a-z0-9-]{1,24})-(\d{4})(?:__(.+))?$"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])

        guard let match = regex.firstMatch(
            in: token,
            options: [],
            range: NSRange(location: 0, length: token.utf16.count)
        ) else {
            throw A4Error.invalidAnchor(
                "Token '\(token)' does not match pattern ^<prefix>-<HHMM>(__suffix)?"
            )
        }

        let prefixRange = match.range(at: 1)
        let hhmmRange = match.range(at: 2)
        let suffixRange = match.range(at: 3)

        guard let prefixNSRange = Range(prefixRange, in: token),
              let hhmmNSRange = Range(hhmmRange, in: token)
        else {
            throw A4Error.invalidAnchor("Failed to extract components from token: \(token)")
        }

        self.prefix = String(token[prefixNSRange])
        self.hhmm = String(token[hhmmNSRange])

        if suffixRange.location != NSNotFound,
           let suffixNSRange = Range(suffixRange, in: token)
        {
            self.suffix = String(token[suffixNSRange])
        } else {
            self.suffix = nil
        }

        guard prefix.count >= 2 && prefix.count <= 25 else {
            throw A4Error.invalidAnchor(
                "Prefix '\(prefix)' must be 2-25 characters"
            )
        }

        guard let hour = Int(String(hhmm.prefix(2))),
              let minute = Int(String(hhmm.suffix(2))),
              hour >= 0 && hour <= 23,
              minute >= 0 && minute <= 59
        else {
            throw A4Error.invalidAnchor("Invalid time '\(hhmm)' - must be valid HHMM format")
        }
    }

    public func marker() -> String {
        if let suffix = suffix {
            return "^\(prefix)-\(hhmm)__\(suffix)"
        } else {
            return "^\(prefix)-\(hhmm)"
        }
    }
}
import Foundation

/// Redacts sensitive material from diagnostic text before it is displayed or
/// exported.
///
/// Diagnostics must never leak credentials, tokens, private keys, or the user's
/// home-directory layout. This is best-effort and conservative: when unsure, it
/// prefers redacting more, not less.
public struct Redactor: Sendable {
    public struct Rule: Sendable {
        public let pattern: String
        public let replacement: String
        public init(_ pattern: String, _ replacement: String) {
            self.pattern = pattern
            self.replacement = replacement
        }
    }

    /// Ordered rules, applied in sequence.
    public static let defaultRules: [Rule] = [
        // PEM private key blocks (multi-line).
        Rule(
            "-----BEGIN [A-Z ]*PRIVATE KEY-----[\\s\\S]*?-----END [A-Z ]*PRIVATE KEY-----",
            "[REDACTED PRIVATE KEY]"
        ),
        // Authorization / bearer tokens.
        Rule("(?i)bearer\\s+[A-Za-z0-9._\\-]+", "Bearer [REDACTED]"),
        Rule("(?i)authorization\\s*[:=]\\s*\\S+", "authorization: [REDACTED]"),
        // Common secret assignments: token=..., password=..., api_key=...
        Rule(
            "(?i)\\b(api[_-]?key|token|password|passwd|secret|client[_-]?secret)\\b\\s*[:=]\\s*[\"']?([^\\s\"']+)[\"']?",
            "$1=[REDACTED]"
        ),
        // AWS-style access keys.
        Rule("\\bAKIA[0-9A-Z]{16}\\b", "[REDACTED_AWS_KEY_ID]"),
        // Long hex/base64 blobs that look like keys (>= 32 chars).
        Rule("\\b[A-Fa-f0-9]{32,}\\b", "[REDACTED_HEX]"),
        // IPv4 — often sensitive topology when exporting.
        Rule("\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b", "[REDACTED_IP]"),
        // Home directory usernames.
        Rule("/Users/[^/\\s]+", "/Users/[USER]"),
        // Generic email addresses.
        Rule("[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}", "[REDACTED_EMAIL]"),
    ]

    public let rules: [Rule]

    public init(rules: [Rule] = Redactor.defaultRules) {
        self.rules = rules
    }

    public func redact(_ input: String) -> String {
        var output = input
        for rule in rules {
            guard let regex = try? NSRegularExpression(
                pattern: rule.pattern,
                options: [.dotMatchesLineSeparators]
            ) else { continue }
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: rule.replacement
            )
        }
        return output
    }
}

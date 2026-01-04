import Foundation

/// Filters sensitive information from notes before syncing/publishing
class SecretFilter {
    /// Patterns for detecting secrets
    private let patterns: [(name: String, regex: NSRegularExpression)]

    init() {
        // Compile regex patterns for common secrets
        let patternStrings: [(String, String)] = [
            // API Keys (generic)
            ("API Key", #"(?i)(api[_-]?key|apikey)\s*[:=]\s*['"]?([a-zA-Z0-9_\-]{20,})['"]?"#),

            // AWS
            ("AWS Access Key", #"AKIA[0-9A-Z]{16}"#),
            ("AWS Secret Key", #"(?i)aws[_-]?secret[_-]?access[_-]?key\s*[:=]\s*['"]?([a-zA-Z0-9/+=]{40})['"]?"#),

            // GitHub
            ("GitHub Token", #"gh[pousr]_[A-Za-z0-9_]{36,}"#),
            ("GitHub Personal Token", #"github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}"#),

            // Slack
            ("Slack Token", #"xox[baprs]-[0-9]{10,13}-[0-9]{10,13}[a-zA-Z0-9-]*"#),
            ("Slack Webhook", #"https://hooks\.slack\.com/services/[A-Z0-9]+/[A-Z0-9]+/[a-zA-Z0-9]+"#),

            // Stripe
            ("Stripe Key", #"(?:sk|pk)_(?:test|live)_[a-zA-Z0-9]{24,}"#),

            // Private Keys
            ("Private Key", #"-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----"#),

            // JWT
            ("JWT Token", #"eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]+"#),

            // Generic secrets
            ("Secret", #"(?i)(secret|password|passwd|pwd|token|auth[_-]?token)\s*[:=]\s*['"]?([^\s'"]{8,})['"]?"#),

            // Bearer tokens
            ("Bearer Token", #"(?i)bearer\s+[a-zA-Z0-9_\-\.~\+\/]+=*"#),

            // Database URLs
            ("Database URL", #"(?i)(postgres|mysql|mongodb|redis)://[^\s]+"#),

            // SSH Keys
            ("SSH Private Key", #"-----BEGIN OPENSSH PRIVATE KEY-----"#),
        ]

        patterns = patternStrings.compactMap { name, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                return nil
            }
            return (name, regex)
        }
    }

    /// Filter secrets from a note, returning a sanitized copy
    func filter(_ note: Note) -> Note {
        var filtered = note
        filtered.content = filterContent(note.content)
        return filtered
    }

    /// Filter secrets from content string
    func filterContent(_ content: String) -> String {
        var result = content

        for (name, regex) in patterns {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: range,
                withTemplate: "[\(name) REDACTED]"
            )
        }

        return result
    }

    /// Check if content contains potential secrets
    func containsSecrets(_ content: String) -> Bool {
        for (_, regex) in patterns {
            let range = NSRange(content.startIndex..., in: content)
            if regex.firstMatch(in: content, options: [], range: range) != nil {
                return true
            }
        }
        return false
    }

    /// Get list of detected secret types in content
    func detectSecretTypes(_ content: String) -> [String] {
        var detected: [String] = []

        for (name, regex) in patterns {
            let range = NSRange(content.startIndex..., in: content)
            if regex.firstMatch(in: content, options: [], range: range) != nil {
                detected.append(name)
            }
        }

        return detected
    }
}

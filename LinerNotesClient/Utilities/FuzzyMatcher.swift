import Foundation

struct FuzzyMatcher {
    static func matches(answer: String, correctAnswers: [String]) -> Bool {
        let normalizedAnswer = normalize(answer)

        for correctAnswer in correctAnswers {
            let normalizedCorrect = normalize(correctAnswer)

            if normalizedAnswer == normalizedCorrect {
                return true
            }

            if matchesWithoutArticles(normalizedAnswer, normalizedCorrect) {
                return true
            }

            if levenshteinDistance(normalizedAnswer, normalizedCorrect) <= 2 {
                return true
            }
        }

        return false
    }

    private static func normalize(_ string: String) -> String {
        return string
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private static func matchesWithoutArticles(_ answer: String, _ correct: String) -> Bool {
        let articles = ["the", "a", "an"]

        let answerWithoutArticles = removeLeadingArticles(answer, articles: articles)
        let correctWithoutArticles = removeLeadingArticles(correct, articles: articles)

        return answerWithoutArticles == correctWithoutArticles
    }

    private static func removeLeadingArticles(_ string: String, articles: [String]) -> String {
        var result = string

        for article in articles {
            if result.hasPrefix(article + " ") {
                result = String(result.dropFirst(article.count + 1))
            }
        }

        return result
    }

    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)

        for i in 0...s1Array.count {
            matrix[i][0] = i
        }

        for j in 0...s2Array.count {
            matrix[0][j] = j
        }

        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        return matrix[s1Array.count][s2Array.count]
    }
}

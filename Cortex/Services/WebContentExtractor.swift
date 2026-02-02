import Foundation
import WebKit

class WebContentExtractor: NSObject {
    private let urlSession: URLSession
    private let timeout: TimeInterval = 30.0
    
    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        config.httpMaximumConnectionsPerHost = 4
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        
        self.urlSession = URLSession(configuration: config)
        super.init()
    }
    
    func extractContent(from url: URL) async -> WebContent {
        do {
            // First, try to fetch the HTML content
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return createEmptyContent()
            }
            
            // Detect encoding
            let encoding = detectEncoding(from: httpResponse, data: data)
            guard let html = String(data: data, encoding: encoding) else {
                return createEmptyContent()
            }
            
            // Parse HTML and extract content
            return await parseHTML(html, originalURL: url)
            
        } catch {
            print("Failed to extract content from \(url): \(error)")
            return createEmptyContent()
        }
    }
    
    private func parseHTML(_ html: String, originalURL: URL) async -> WebContent {
        // Extract title using regex
        let title = extractTitle(from: html)
        
        // Extract meta description using regex
        let description = extractMetaDescription(from: html)
        
        // Extract and clean main content
        let textContent = await extractMainContent(from: html)
        
        // Analyze content structure
        let hasVideo = await checkForVideo(in: html)
        let hasImages = await checkForImages(in: html)
        let hasCode = await checkForCode(in: html, textContent: textContent)
        let isArticle = await checkIfArticle(in: html, textContent: textContent)
        let isTutorial = await checkIfTutorial(in: html, textContent: textContent)
        
        return WebContent(
            title: title?.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines),
            textContent: textContent,
            hasVideo: hasVideo,
            hasImages: hasImages,
            hasCode: hasCode,
            isArticle: isArticle,
            isTutorial: isTutorial
        )
    }
    
    private func extractTitle(from html: String) -> String? {
        let titlePattern = "<title[^>]*>([^<]+)</title>"
        guard let regex = try? NSRegularExpression(pattern: titlePattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: html.count)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        return String(html[titleRange])
    }
    
    private func extractMetaDescription(from html: String) -> String? {
        let metaPattern = "<meta[^>]*name=[\"']description[\"'][^>]*content=[\"']([^\"']*)[\"'][^>]*>"
        guard let regex = try? NSRegularExpression(pattern: metaPattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: html.count)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let descRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        return String(html[descRange])
    }
    
    private func extractMainContent(from html: String) async -> String {
        var cleanedHTML = html
        
        // Remove script, style, nav, footer, header elements
        let unwantedTags = ["script", "style", "nav", "footer", "header", "noscript", "iframe"]
        for tag in unwantedTags {
            cleanedHTML = removeHTMLTag(cleanedHTML, tag: tag)
        }
        
        // Try to extract main content using various selectors
        let contentSelectors = [
            "<main[^>]*>([\\s\\S]*?)</main>",
            "<article[^>]*>([\\s\\S]*?)</article>",
            "class=[\"']main-content[\"'][^>]*>([\\s\\S]*?)<",
            "class=[\"']content[\"'][^>]*>([\\s\\S]*?)<",
            "class=[\"']post-content[\"'][^>]*>([\\s\\S]*?)<",
            "class=[\"']entry-content[\"'][^>]*>([\\s\\S]*?)<",
            "id=[\"']content[\"'][^>]*>([\\s\\S]*?)<",
            "id=[\"']main[\"'][^>]*>([\\s\\S]*?)<"
        ]
        
        var extractedContent = ""
        
        for pattern in contentSelectors {
            if let content = extractContentWithPattern(from: cleanedHTML, pattern: pattern) {
                extractedContent = content
                break
            }
        }
        
        // Fallback: extract body content
        if extractedContent.isEmpty {
            if let bodyContent = extractContentWithPattern(from: cleanedHTML, pattern: "<body[^>]*>([\\s\\S]*?)</body>") {
                extractedContent = bodyContent
            } else {
                extractedContent = cleanedHTML
            }
        }
        
        // Strip all HTML tags and get plain text
        let plainText = stripHTMLTags(from: extractedContent)
        
        // Clean and limit content
        return cleanAndLimitText(plainText)
    }
    
    private func removeHTMLTag(_ html: String, tag: String) -> String {
        let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return html
        }
        
        let range = NSRange(location: 0, length: html.count)
        return regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: "")
    }
    
    private func extractContentWithPattern(from html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        
        let range = NSRange(location: 0, length: html.count)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let contentRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        
        let content = String(html[contentRange])
        return content.isEmpty ? nil : content
    }
    
    private func stripHTMLTags(from html: String) -> String {
        let htmlTagPattern = "<[^>]+>"
        guard let regex = try? NSRegularExpression(pattern: htmlTagPattern, options: []) else {
            return html
        }
        
        let range = NSRange(location: 0, length: html.count)
        let plainText = regex.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: " ")
        
        // Decode HTML entities
        return decodeHTMLEntities(plainText)
    }
    
    private func decodeHTMLEntities(_ text: String) -> String {
        var decoded = text
        let entities = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&#39;": "'",
            "&#x27;": "'",
            "&#x2F;": "/",
            "&#x60;": "`",
            "&#x3D;": "="
        ]
        
        for (entity, replacement) in entities {
            decoded = decoded.replacingOccurrences(of: entity, with: replacement)
        }
        
        return decoded
    }
    
    private func checkForVideo(in html: String) async -> Bool {
        let videoPatterns = [
            "<video[^>]*>",
            "youtube\\.com",
            "youtu\\.be",
            "vimeo\\.com",
            "twitch\\.tv",
            "video-player",
            "youtube-player",
            "data-video"
        ]
        
        let lowercaseHTML = html.lowercased()
        for pattern in videoPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: html.count)
                if regex.firstMatch(in: html, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func checkForImages(in html: String) async -> Bool {
        let imgPattern = "<img[^>]*>"
        guard let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) else {
            return false
        }
        
        let range = NSRange(location: 0, length: html.count)
        let matches = regex.matches(in: html, options: [], range: range)
        return matches.count > 2 // More than just logo/icons
    }
    
    private func checkForCode(in html: String, textContent: String) async -> Bool {
        // Check for code elements in HTML
        let codePatterns = ["<code[^>]*>", "<pre[^>]*>", "class=[\"']highlight[\"']", "class=[\"']code[\"']"]
        
        for pattern in codePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: html.count)
                if regex.firstMatch(in: html, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        // Check for programming-related keywords in content
        let codeKeywords = [
            "function", "class", "import", "export", "const", "let", "var",
            "def", "public", "private", "static", "return", "if", "else",
            "for", "while", "loop", "array", "object", "string", "int",
            "boolean", "try", "catch", "throw", "async", "await", "promise"
        ]
        
        let lowercaseContent = textContent.lowercased()
        let keywordCount = codeKeywords.filter { lowercaseContent.contains($0) }.count
        
        return keywordCount >= 3
    }
    
    private func checkIfArticle(in html: String, textContent: String) async -> Bool {
        // Check for article elements
        let articlePatterns = ["<article[^>]*>", "class=[\"']article[\"']", "class=[\"']post[\"']", "class=[\"']blog-post[\"']"]
        
        for pattern in articlePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: html.count)
                if regex.firstMatch(in: html, options: [], range: range) != nil {
                    return true
                }
            }
        }
        
        // Check content length (articles are typically longer)
        let wordCount = textContent.split(separator: " ").count
        if wordCount > 300 {
            return true
        }
        
        // Check for article-like metadata
        if html.lowercased().contains("og:type") && html.lowercased().contains("article") {
            return true
        }
        
        return false
    }
    
    private func checkIfTutorial(in html: String, textContent: String) async -> Bool {
        let tutorialKeywords = [
            "tutorial", "guide", "how to", "step by step", "instructions",
            "walkthrough", "beginner", "learn", "course", "lesson", "chapter"
        ]
        
        let lowercaseContent = textContent.lowercased()
        let keywordCount = tutorialKeywords.filter { lowercaseContent.contains($0) }.count
        
        // Check title for tutorial indicators
        if let title = extractTitle(from: html) {
            let lowercaseTitle = title.lowercased()
            let titleKeywordCount = tutorialKeywords.filter { lowercaseTitle.contains($0) }.count
            
            return keywordCount >= 2 || titleKeywordCount >= 1
        }
        
        return keywordCount >= 2
    }
    
    private func cleanAndLimitText(_ text: String) -> String {
        // Remove extra whitespace and normalize
        let cleaned = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limit to reasonable length for processing (about 5000 characters)
        if cleaned.count > 5000 {
            let index = cleaned.index(cleaned.startIndex, offsetBy: 5000)
            return String(cleaned[..<index]) + "..."
        }
        
        return cleaned
    }
    
    private func detectEncoding(from response: HTTPURLResponse, data: Data) -> String.Encoding {
        // Check Content-Type header for charset
        if let contentType = response.value(forHTTPHeaderField: "Content-Type") {
            let charset = extractCharset(from: contentType)
            return stringEncodingFromCharset(charset)
        }
        
        // Check HTML meta charset
        if let htmlString = String(data: data, encoding: .utf8) {
            let charsetPattern = "<meta[^>]*charset\\s*=\\s*[\"']?([^\"'\\s>]+)"
            if let regex = try? NSRegularExpression(pattern: charsetPattern, options: .caseInsensitive) {
                let range = NSRange(location: 0, length: min(htmlString.count, 1024))
                if let match = regex.firstMatch(in: htmlString, options: [], range: range) {
                    let charsetRange = Range(match.range(at: 1), in: htmlString)
                    if let charsetRange = charsetRange {
                        let charset = String(htmlString[charsetRange])
                        return stringEncodingFromCharset(charset)
                    }
                }
            }
        }
        
        return .utf8 // Default fallback
    }
    
    private func extractCharset(from contentType: String) -> String {
        let components = contentType.components(separatedBy: ";")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("charset=") {
                return String(trimmed.dropFirst(8)).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            }
        }
        return "utf-8"
    }
    
    private func stringEncodingFromCharset(_ charset: String) -> String.Encoding {
        let lowercaseCharset = charset.lowercased()
        switch lowercaseCharset {
        case "utf-8", "utf8":
            return .utf8
        case "iso-8859-1", "latin1":
            return .isoLatin1
        case "windows-1252", "cp1252":
            return .windowsCP1252
        case "utf-16", "utf16":
            return .utf16
        default:
            return .utf8
        }
    }
    
    private func createEmptyContent() -> WebContent {
        return WebContent(
            title: nil,
            description: nil,
            textContent: "",
            hasVideo: false,
            hasImages: false,
            hasCode: false,
            isArticle: false,
            isTutorial: false
        )
    }
}
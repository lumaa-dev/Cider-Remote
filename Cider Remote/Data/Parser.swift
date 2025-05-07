// Made by Lumaa & ChatGPT

import Foundation

/// Parses the XML of the `rise.cider.sh` responses
class Parser: NSObject, XMLParserDelegate {
    var lyrics: [LyricLine]
    private var currentText: String
    private var currentBegin: String?

    init(lyrics: [LyricLine] = []) {
        self.lyrics = lyrics
        self.currentText = ""
        self.currentBegin = nil
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:])
    {
        if elementName == "p" {
            // Save the 'begin' time (as string) when <p> starts, reset text.
            currentBegin = attributeDict["begin"]
            currentText = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        // Accumulate text (including inside nested tags) for the current <p>.
        currentText += string
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?)
    {
        if elementName == "p" {
            // We reached </p>, so finalize this lyric line.
            let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            // Ignore empty lines
            if !trimmedText.isEmpty, let beginString = currentBegin {
                // Convert "HH:MM:SS.mmm" to seconds
                let parts = beginString.split(separator: ":")
                let hours = Double(parts[0]) ?? 0
                let minutes = Double(parts[1]) ?? 0
                let seconds = Double(parts[2]) ?? 0
                let timestamp = hours * 3600 + minutes * 60 + seconds
                // Check if entire lyric is parenthesized
                let isMain = trimmedText.hasPrefix("(") && trimmedText.hasSuffix(")")
                let lyricLine = LyricLine(text: trimmedText,
                                          timestamp: timestamp,
                                          isMainLyric: isMain)
                lyrics.append(lyricLine)
            }
            // Reset for next <p>
            currentBegin = nil
            currentText = ""
        }
    }
}

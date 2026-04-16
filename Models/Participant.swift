import Foundation

struct Participant: Codable, Equatable {
    let id: String          // MSConversation participant UUID
    let initial: String
    let color: String       // hex string

    // Fixed palette assigned by thread position (matches MVP participant colors)
    static let palette: [String] = [
        "#FF6B9D",  // pink
        "#34C759",  // green
        "#007AFF",  // blue
        "#FF9F0A",  // orange
        "#BF5AF2",  // purple
        "#FF375F",  // red
    ]

    static func color(for index: Int) -> String {
        palette[index % palette.count]
    }
}

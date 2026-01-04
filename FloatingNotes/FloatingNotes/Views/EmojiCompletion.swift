import SwiftUI

/// Emoji completion popup view
struct EmojiCompletionPopup: View {
    @Binding var searchText: String
    @Binding var isPresented: Bool
    var onSelect: (String) -> Void

    @State private var selectedIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            if filteredEmojis.isEmpty {
                Text("No matching emojis")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(filteredEmojis.enumerated()), id: \.element.shortcode) { index, emoji in
                                EmojiRow(emoji: emoji, isSelected: index == selectedIndex)
                                    .id(emoji.shortcode)
                                    .onTapGesture {
                                        onSelect(emoji.emoji)
                                    }
                            }
                        }
                        .padding(4)
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        if filteredEmojis.indices.contains(newValue) {
                            withAnimation {
                                proxy.scrollTo(filteredEmojis[newValue].shortcode, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 280, height: min(CGFloat(filteredEmojis.count) * 32 + 8, 200))
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .shadow(radius: 8)
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredEmojis.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.return) {
            if filteredEmojis.indices.contains(selectedIndex) {
                onSelect(filteredEmojis[selectedIndex].emoji)
            }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.tab) {
            if filteredEmojis.indices.contains(selectedIndex) {
                onSelect(filteredEmojis[selectedIndex].emoji)
            }
            return .handled
        }
        .onChange(of: searchText) { _, _ in
            selectedIndex = 0
        }
    }

    private var filteredEmojis: [EmojiData] {
        if searchText.isEmpty {
            return Array(EmojiDatabase.all.prefix(20))
        }

        let searchLower = searchText.lowercased()
        return EmojiDatabase.all.filter { emoji in
            emoji.shortcode.lowercased().contains(searchLower) ||
            emoji.keywords.contains { $0.lowercased().contains(searchLower) }
        }.prefix(20).map { $0 }
    }
}

/// Single emoji row in the completion popup
struct EmojiRow: View {
    let emoji: EmojiData
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(emoji.emoji)
                .font(.title2)

            Text(":\(emoji.shortcode):")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(isSelected ? .white : .primary)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .cornerRadius(4)
    }
}

/// Emoji data structure
struct EmojiData: Identifiable {
    var id: String { shortcode }
    let emoji: String
    let shortcode: String
    let keywords: [String]
}

/// Emoji database with common emojis
struct EmojiDatabase {
    static let all: [EmojiData] = [
        // Smileys
        EmojiData(emoji: "😀", shortcode: "grinning", keywords: ["smile", "happy"]),
        EmojiData(emoji: "😃", shortcode: "smiley", keywords: ["smile", "happy"]),
        EmojiData(emoji: "😄", shortcode: "smile", keywords: ["happy", "joy"]),
        EmojiData(emoji: "😁", shortcode: "grin", keywords: ["smile", "happy"]),
        EmojiData(emoji: "😅", shortcode: "sweat_smile", keywords: ["hot", "happy"]),
        EmojiData(emoji: "😂", shortcode: "joy", keywords: ["laugh", "crying"]),
        EmojiData(emoji: "🤣", shortcode: "rofl", keywords: ["laugh", "rolling"]),
        EmojiData(emoji: "😊", shortcode: "blush", keywords: ["smile", "happy"]),
        EmojiData(emoji: "😇", shortcode: "innocent", keywords: ["angel", "halo"]),
        EmojiData(emoji: "🙂", shortcode: "slightly_smiling_face", keywords: ["smile"]),
        EmojiData(emoji: "🙃", shortcode: "upside_down_face", keywords: ["silly"]),
        EmojiData(emoji: "😉", shortcode: "wink", keywords: ["flirt"]),
        EmojiData(emoji: "😌", shortcode: "relieved", keywords: ["calm"]),
        EmojiData(emoji: "😍", shortcode: "heart_eyes", keywords: ["love"]),
        EmojiData(emoji: "🥰", shortcode: "smiling_face_with_hearts", keywords: ["love"]),
        EmojiData(emoji: "😘", shortcode: "kissing_heart", keywords: ["love", "kiss"]),
        EmojiData(emoji: "😗", shortcode: "kissing", keywords: ["kiss"]),
        EmojiData(emoji: "😙", shortcode: "kissing_smiling_eyes", keywords: ["kiss"]),
        EmojiData(emoji: "😚", shortcode: "kissing_closed_eyes", keywords: ["kiss"]),
        EmojiData(emoji: "😋", shortcode: "yum", keywords: ["tasty", "delicious"]),
        EmojiData(emoji: "😛", shortcode: "stuck_out_tongue", keywords: ["playful"]),
        EmojiData(emoji: "😜", shortcode: "stuck_out_tongue_winking_eye", keywords: ["playful"]),
        EmojiData(emoji: "🤪", shortcode: "zany_face", keywords: ["crazy", "wild"]),
        EmojiData(emoji: "😝", shortcode: "stuck_out_tongue_closed_eyes", keywords: ["playful"]),
        EmojiData(emoji: "🤑", shortcode: "money_mouth_face", keywords: ["rich", "dollar"]),
        EmojiData(emoji: "🤗", shortcode: "hugs", keywords: ["hug"]),
        EmojiData(emoji: "🤭", shortcode: "hand_over_mouth", keywords: ["oops"]),
        EmojiData(emoji: "🤫", shortcode: "shushing_face", keywords: ["quiet", "secret"]),
        EmojiData(emoji: "🤔", shortcode: "thinking", keywords: ["hmm", "think"]),

        // Gestures
        EmojiData(emoji: "👍", shortcode: "thumbsup", keywords: ["yes", "ok", "good", "+1"]),
        EmojiData(emoji: "👎", shortcode: "thumbsdown", keywords: ["no", "bad", "-1"]),
        EmojiData(emoji: "👌", shortcode: "ok_hand", keywords: ["perfect"]),
        EmojiData(emoji: "✌️", shortcode: "v", keywords: ["peace", "victory"]),
        EmojiData(emoji: "🤞", shortcode: "crossed_fingers", keywords: ["luck"]),
        EmojiData(emoji: "🤟", shortcode: "love_you_gesture", keywords: ["love"]),
        EmojiData(emoji: "🤘", shortcode: "metal", keywords: ["rock"]),
        EmojiData(emoji: "👋", shortcode: "wave", keywords: ["hello", "bye"]),
        EmojiData(emoji: "🙌", shortcode: "raised_hands", keywords: ["celebrate"]),
        EmojiData(emoji: "👏", shortcode: "clap", keywords: ["applause"]),
        EmojiData(emoji: "🙏", shortcode: "pray", keywords: ["please", "thanks"]),
        EmojiData(emoji: "💪", shortcode: "muscle", keywords: ["strong", "flex"]),

        // Hearts
        EmojiData(emoji: "❤️", shortcode: "heart", keywords: ["love", "red"]),
        EmojiData(emoji: "🧡", shortcode: "orange_heart", keywords: ["love"]),
        EmojiData(emoji: "💛", shortcode: "yellow_heart", keywords: ["love"]),
        EmojiData(emoji: "💚", shortcode: "green_heart", keywords: ["love"]),
        EmojiData(emoji: "💙", shortcode: "blue_heart", keywords: ["love"]),
        EmojiData(emoji: "💜", shortcode: "purple_heart", keywords: ["love"]),
        EmojiData(emoji: "🖤", shortcode: "black_heart", keywords: ["love"]),
        EmojiData(emoji: "💔", shortcode: "broken_heart", keywords: ["sad"]),

        // Objects
        EmojiData(emoji: "⭐", shortcode: "star", keywords: ["favorite"]),
        EmojiData(emoji: "🌟", shortcode: "star2", keywords: ["sparkle"]),
        EmojiData(emoji: "✨", shortcode: "sparkles", keywords: ["magic", "clean"]),
        EmojiData(emoji: "💡", shortcode: "bulb", keywords: ["idea", "light"]),
        EmojiData(emoji: "🔥", shortcode: "fire", keywords: ["hot", "lit"]),
        EmojiData(emoji: "💯", shortcode: "100", keywords: ["perfect", "score"]),
        EmojiData(emoji: "✅", shortcode: "white_check_mark", keywords: ["done", "complete"]),
        EmojiData(emoji: "❌", shortcode: "x", keywords: ["no", "wrong"]),
        EmojiData(emoji: "⚠️", shortcode: "warning", keywords: ["caution"]),
        EmojiData(emoji: "📝", shortcode: "memo", keywords: ["note", "write"]),
        EmojiData(emoji: "📌", shortcode: "pushpin", keywords: ["pin"]),
        EmojiData(emoji: "📎", shortcode: "paperclip", keywords: ["attach"]),
        EmojiData(emoji: "🔗", shortcode: "link", keywords: ["url"]),
        EmojiData(emoji: "📅", shortcode: "date", keywords: ["calendar"]),
        EmojiData(emoji: "🕐", shortcode: "clock1", keywords: ["time"]),
        EmojiData(emoji: "⏰", shortcode: "alarm_clock", keywords: ["time", "wake"]),
        EmojiData(emoji: "📧", shortcode: "email", keywords: ["mail"]),
        EmojiData(emoji: "💻", shortcode: "computer", keywords: ["laptop", "mac"]),
        EmojiData(emoji: "🖥️", shortcode: "desktop_computer", keywords: ["pc"]),
        EmojiData(emoji: "📱", shortcode: "iphone", keywords: ["phone", "mobile"]),
        EmojiData(emoji: "🎉", shortcode: "tada", keywords: ["party", "celebrate"]),
        EmojiData(emoji: "🎊", shortcode: "confetti_ball", keywords: ["party"]),
        EmojiData(emoji: "🎁", shortcode: "gift", keywords: ["present"]),
        EmojiData(emoji: "🏆", shortcode: "trophy", keywords: ["win", "award"]),
        EmojiData(emoji: "🥇", shortcode: "1st_place_medal", keywords: ["gold", "first"]),
        EmojiData(emoji: "🚀", shortcode: "rocket", keywords: ["launch", "ship"]),
        EmojiData(emoji: "💎", shortcode: "gem", keywords: ["diamond"]),
        EmojiData(emoji: "🔒", shortcode: "lock", keywords: ["secure", "private"]),
        EmojiData(emoji: "🔓", shortcode: "unlock", keywords: ["open"]),
        EmojiData(emoji: "🔑", shortcode: "key", keywords: ["password"]),

        // Arrows & Symbols
        EmojiData(emoji: "➡️", shortcode: "arrow_right", keywords: ["next"]),
        EmojiData(emoji: "⬅️", shortcode: "arrow_left", keywords: ["back"]),
        EmojiData(emoji: "⬆️", shortcode: "arrow_up", keywords: ["up"]),
        EmojiData(emoji: "⬇️", shortcode: "arrow_down", keywords: ["down"]),
        EmojiData(emoji: "↩️", shortcode: "leftwards_arrow_with_hook", keywords: ["return"]),
        EmojiData(emoji: "🔄", shortcode: "arrows_counterclockwise", keywords: ["refresh", "reload"]),

        // Nature
        EmojiData(emoji: "☀️", shortcode: "sunny", keywords: ["sun", "weather"]),
        EmojiData(emoji: "🌙", shortcode: "crescent_moon", keywords: ["night"]),
        EmojiData(emoji: "⛅", shortcode: "partly_sunny", keywords: ["cloud"]),
        EmojiData(emoji: "🌈", shortcode: "rainbow", keywords: ["colors"]),
        EmojiData(emoji: "🌸", shortcode: "cherry_blossom", keywords: ["flower", "spring"]),
        EmojiData(emoji: "🌺", shortcode: "hibiscus", keywords: ["flower"]),
        EmojiData(emoji: "🌻", shortcode: "sunflower", keywords: ["flower"]),
        EmojiData(emoji: "🌲", shortcode: "evergreen_tree", keywords: ["pine"]),
        EmojiData(emoji: "🌴", shortcode: "palm_tree", keywords: ["tropical"]),

        // Food & Drink
        EmojiData(emoji: "☕", shortcode: "coffee", keywords: ["cafe", "espresso"]),
        EmojiData(emoji: "🍵", shortcode: "tea", keywords: ["drink"]),
        EmojiData(emoji: "🍺", shortcode: "beer", keywords: ["drink", "alcohol"]),
        EmojiData(emoji: "🍷", shortcode: "wine_glass", keywords: ["drink"]),
        EmojiData(emoji: "🍕", shortcode: "pizza", keywords: ["food"]),
        EmojiData(emoji: "🍔", shortcode: "hamburger", keywords: ["burger", "food"]),
        EmojiData(emoji: "🍟", shortcode: "fries", keywords: ["food"]),
        EmojiData(emoji: "🍩", shortcode: "doughnut", keywords: ["donut", "food"]),
        EmojiData(emoji: "🍰", shortcode: "cake", keywords: ["birthday", "dessert"]),
        EmojiData(emoji: "🍎", shortcode: "apple", keywords: ["fruit", "red"]),

        // Animals
        EmojiData(emoji: "🐶", shortcode: "dog", keywords: ["puppy", "pet"]),
        EmojiData(emoji: "🐱", shortcode: "cat", keywords: ["kitten", "pet"]),
        EmojiData(emoji: "🐭", shortcode: "mouse", keywords: ["rodent"]),
        EmojiData(emoji: "🐰", shortcode: "rabbit", keywords: ["bunny"]),
        EmojiData(emoji: "🦊", shortcode: "fox_face", keywords: ["animal"]),
        EmojiData(emoji: "🐻", shortcode: "bear", keywords: ["animal"]),
        EmojiData(emoji: "🐼", shortcode: "panda_face", keywords: ["animal"]),
        EmojiData(emoji: "🦁", shortcode: "lion", keywords: ["animal", "king"]),
        EmojiData(emoji: "🐯", shortcode: "tiger", keywords: ["animal"]),
        EmojiData(emoji: "🦄", shortcode: "unicorn", keywords: ["magic", "horse"]),

        // Developer
        EmojiData(emoji: "🐛", shortcode: "bug", keywords: ["debug", "error"]),
        EmojiData(emoji: "🔧", shortcode: "wrench", keywords: ["tool", "fix"]),
        EmojiData(emoji: "⚙️", shortcode: "gear", keywords: ["settings", "config"]),
        EmojiData(emoji: "🛠️", shortcode: "hammer_and_wrench", keywords: ["tools", "build"]),
        EmojiData(emoji: "📦", shortcode: "package", keywords: ["box", "ship"]),
        EmojiData(emoji: "🗃️", shortcode: "card_file_box", keywords: ["database"]),
        EmojiData(emoji: "📊", shortcode: "bar_chart", keywords: ["graph", "stats"]),
        EmojiData(emoji: "📈", shortcode: "chart_with_upwards_trend", keywords: ["growth"]),
        EmojiData(emoji: "📉", shortcode: "chart_with_downwards_trend", keywords: ["decline"]),
        EmojiData(emoji: "🧪", shortcode: "test_tube", keywords: ["experiment", "test"]),
        EmojiData(emoji: "🔬", shortcode: "microscope", keywords: ["science", "research"]),
    ]
}

#Preview {
    EmojiCompletionPopup(
        searchText: .constant("smile"),
        isPresented: .constant(true),
        onSelect: { _ in }
    )
}

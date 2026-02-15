import Foundation

struct InterestOption: Hashable, Identifiable {
    let emoji: String
    let title: String

    var id: String { title }
    var chipLabel: String { "\(emoji) \(title)" }
}

struct InterestGroup: Hashable, Identifiable {
    let title: String
    let subtitle: String
    let options: [InterestOption]

    var id: String { title }
}

enum InterestCatalog {
    static let groups: [InterestGroup] = [
        InterestGroup(
            title: "Career & Business",
            subtitle: "Work, strategy, and growth",
            options: [
                InterestOption(emoji: "💼", title: "Business"),
                InterestOption(emoji: "🚀", title: "Startups"),
                InterestOption(emoji: "📣", title: "Marketing"),
                InterestOption(emoji: "🧭", title: "Leadership"),
                InterestOption(emoji: "🤝", title: "Negotiation")
            ]
        ),
        InterestGroup(
            title: "Tech & Science",
            subtitle: "Build, analyze, and discover",
            options: [
                InterestOption(emoji: "📱", title: "Technology"),
                InterestOption(emoji: "👨‍💻", title: "Programming"),
                InterestOption(emoji: "📊", title: "Data Science"),
                InterestOption(emoji: "🤖", title: "Artificial Intelligence"),
                InterestOption(emoji: "🔐", title: "Cybersecurity"),
                InterestOption(emoji: "🧪", title: "Science")
            ]
        ),
        InterestGroup(
            title: "Money & Markets",
            subtitle: "Finance and decision-making",
            options: [
                InterestOption(emoji: "💰", title: "Finance"),
                InterestOption(emoji: "📉", title: "Investing"),
                InterestOption(emoji: "🌑", title: "Crypto"),
                InterestOption(emoji: "🏘️", title: "Real Estate")
            ]
        ),
        InterestGroup(
            title: "Culture & Ideas",
            subtitle: "Meaning, history, and perspective",
            options: [
                InterestOption(emoji: "🧑‍🎨", title: "Art"),
                InterestOption(emoji: "📜", title: "History"),
                InterestOption(emoji: "🧩", title: "Philosophy"),
                InterestOption(emoji: "📚", title: "Literature"),
                InterestOption(emoji: "🌍", title: "Culture"),
                InterestOption(emoji: "🏛️", title: "Politics")
            ]
        ),
        InterestGroup(
            title: "Entertainment",
            subtitle: "Stories, media, and fun",
            options: [
                InterestOption(emoji: "🎬", title: "Cinema"),
                InterestOption(emoji: "🎵", title: "Music"),
                InterestOption(emoji: "🎮", title: "Gaming"),
                InterestOption(emoji: "🎙️", title: "Podcasts"),
                InterestOption(emoji: "📺", title: "TV Series"),
                InterestOption(emoji: "🎭", title: "Theater")
            ]
        ),
        InterestGroup(
            title: "Health & Mind",
            subtitle: "Wellbeing and human performance",
            options: [
                InterestOption(emoji: "💚", title: "Mental Health"),
                InterestOption(emoji: "🧠", title: "Psychology"),
                InterestOption(emoji: "🩺", title: "Health Care"),
                InterestOption(emoji: "💪", title: "Fitness"),
                InterestOption(emoji: "🥗", title: "Nutrition")
            ]
        ),
        InterestGroup(
            title: "Learning & Lifestyle",
            subtitle: "Skills and daily habits",
            options: [
                InterestOption(emoji: "🎯", title: "Productivity"),
                InterestOption(emoji: "🎓", title: "Education"),
                InterestOption(emoji: "🗣️", title: "Language Learning"),
                InterestOption(emoji: "🍳", title: "Cooking"),
                InterestOption(emoji: "🥐", title: "Baking")
            ]
        ),
        InterestGroup(
            title: "Sports & Movement",
            subtitle: "Active interests",
            options: [
                InterestOption(emoji: "⚽", title: "Sports"),
                InterestOption(emoji: "🏃", title: "Running"),
                InterestOption(emoji: "🚴", title: "Cycling"),
                InterestOption(emoji: "🧗", title: "Climbing"),
                InterestOption(emoji: "🏊", title: "Swimming"),
                InterestOption(emoji: "🧘", title: "Yoga")
            ]
        ),
        InterestGroup(
            title: "Outdoors & Planet",
            subtitle: "Nature and the world",
            options: [
                InterestOption(emoji: "🌿", title: "Nature"),
                InterestOption(emoji: "🌦️", title: "Climate"),
                InterestOption(emoji: "🧭", title: "Geography"),
                InterestOption(emoji: "🪐", title: "Space"),
                InterestOption(emoji: "🦋", title: "Wildlife"),
                InterestOption(emoji: "🍀", title: "Botany")
            ]
        ),
        InterestGroup(
            title: "Travel & Exploration",
            subtitle: "Places and adventures",
            options: [
                InterestOption(emoji: "✈️", title: "Travel"),
                InterestOption(emoji: "🧳", title: "Backpacking"),
                InterestOption(emoji: "🏕️", title: "Camping"),
                InterestOption(emoji: "✈️", title: "Aviation"),
                InterestOption(emoji: "🚗", title: "Cars"),
                InterestOption(emoji: "🏍️", title: "Motorcycles")
            ]
        ),
        InterestGroup(
            title: "Design & Creative",
            subtitle: "Visual and product craft",
            options: [
                InterestOption(emoji: "🎨", title: "Design"),
                InterestOption(emoji: "🏗️", title: "Architecture"),
                InterestOption(emoji: "📷", title: "Photography"),
                InterestOption(emoji: "👗", title: "Fashion"),
                InterestOption(emoji: "🖌️", title: "Illustration"),
                InterestOption(emoji: "🧵", title: "Crafts")
            ]
        ),
        InterestGroup(
            title: "Community & Identity",
            subtitle: "People, society, and causes",
            options: [
                InterestOption(emoji: "🏳️‍🌈", title: "LGBTQ+"),
                InterestOption(emoji: "⚖️", title: "Law"),
                InterestOption(emoji: "🫶", title: "Social Impact"),
                InterestOption(emoji: "🌐", title: "Global Affairs"),
                InterestOption(emoji: "🤲", title: "Volunteering"),
                InterestOption(emoji: "📰", title: "Current Events")
            ]
        ),
        InterestGroup(
            title: "Curiosity Zone",
            subtitle: "Niche and playful topics",
            options: [
                InterestOption(emoji: "🛸", title: "UFO"),
                InterestOption(emoji: "🪄", title: "Mythology"),
                InterestOption(emoji: "🧬", title: "Biotech"),
                InterestOption(emoji: "🧮", title: "Mathematics"),
                InterestOption(emoji: "🐶", title: "Dogs"),
                InterestOption(emoji: "🐱", title: "Cats"),
                InterestOption(emoji: "🐦", title: "Birds"),
                InterestOption(emoji: "🪼", title: "Marine Life")
            ]
        )
    ]

    static let all: [InterestOption] = groups.flatMap(\.options)
}

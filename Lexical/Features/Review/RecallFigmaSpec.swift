import SwiftUI
import LexicalCore

struct RecallFigmaSpec {
    let baseWidth: CGFloat = 393

    let screenTitle = "Recall Session"
    let screenSubtitle = "Daily active recall"

    let lightBackgroundHex = "F5F5F7"
    let darkBackgroundHex = "0A101A"

    let titleLightHex = "0F1216"
    let titleDarkHex = "F5F6F8"
    let subtitleLightHex = "6B717A"
    let subtitleDarkHex = "8B96A6"

    let headerTitleFontSize: CGFloat = 24
    let headerSubtitleFontSize: CGFloat = 16
    let sectionLabelFontSize: CGFloat = 11
    let sentenceFontSize: CGFloat = 25
    let answerWordFontSize: CGFloat = 34
    let supportingFontSize: CGFloat = 15

    let horizontalPadding: CGFloat = 24
    let headerTopPadding: CGFloat = 16
    let headerBottomPadding: CGFloat = 12
    let contentTopSpacing: CGFloat = 12

    let progressTrackHex = "BCBCBC"
    let progressFillHex = "144932"
    let progressHeight: CGFloat = 4
    let progressCornerRadius: CGFloat = 2

    let cardCornerRadius: CGFloat = 14
    let cardMinHeight: CGFloat = 292
    let cardLightFillHex = "FFFFFF"
    let cardDarkFillHex = "192131"
    let cardLightOpacity: Double = 0.84
    let cardDarkOpacity: Double = 0.92
    let cardStrokeLightHex = "DADDE3"
    let cardStrokeDarkHex = "455166"
    let cardShadowOpacity: Double = 0.09
    let cardShadowRadius: CGFloat = 18
    let cardShadowYOffset: CGFloat = 12

    let neutralActionBackgroundHex = "E7E8EC"
    let neutralActionTextHex = "444B56"
    let neutralActionCornerRadius: CGFloat = 16
    let neutralActionHeight: CGFloat = 52

    let gradeAgainHex = "E8B7B5"
    let gradeHardHex = "E6D2A5"
    let gradeGoodHex = "AFD7C5"
    let gradeEasyHex = "A4DBBA"
    let gradeTextHex = "2A333E"
    let gradeButtonSize = CGSize(width: 60, height: 60)
    let gradeButtonCornerRadius: CGFloat = 20

    let primaryActionHex = "507760"
    let primaryActionTextHex = "FFFFFF"
    let primaryActionCornerRadius: CGFloat = 18
    let primaryActionHeight: CGFloat = 54

    let revealDuration: Double = 0.16
    let advanceDuration: Double = 0.22

    func scale(for width: CGFloat) -> CGFloat {
        let normalized = width / baseWidth
        return min(max(normalized, 0.88), 1.2)
    }

    func backgroundColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? darkBackgroundHex : lightBackgroundHex)
    }

    func titleColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? titleDarkHex : titleLightHex)
    }

    func subtitleColor(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? subtitleDarkHex : subtitleLightHex)
    }

    func progressTrackColor(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(hex: progressTrackHex).opacity(0.28)
        }
        return Color(hex: progressTrackHex).opacity(0.72)
    }

    func progressFillColor(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(hex: "5C9E7A")
        }
        return Color(hex: progressFillHex)
    }

    func cardFill(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(hex: cardDarkFillHex).opacity(cardDarkOpacity)
        }
        return Color(hex: cardLightFillHex).opacity(cardLightOpacity)
    }

    func cardStroke(for colorScheme: ColorScheme) -> Color {
        Color(hex: colorScheme == .dark ? cardStrokeDarkHex : cardStrokeLightHex)
            .opacity(colorScheme == .dark ? 0.64 : 0.8)
    }

    func cardShadow(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.34)
        }
        return Color.black.opacity(cardShadowOpacity)
    }

    func neutralActionFill(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(hex: "273041")
        }
        return Color(hex: neutralActionBackgroundHex)
    }

    func neutralActionText(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(hex: "D8DDE7")
        }
        return Color(hex: neutralActionTextHex)
    }

    func gradeFill(for grade: Int, colorScheme: ColorScheme) -> Color {
        let hex: String = switch grade {
        case 1: gradeAgainHex
        case 2: gradeHardHex
        case 3: gradeGoodHex
        default: gradeEasyHex
        }
        return Color(hex: hex).opacity(colorScheme == .dark ? 0.8 : 1.0)
    }

    func gradeTextColor(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(hex: "0E141C")
        }
        return Color(hex: gradeTextHex)
    }

    func primaryFill(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return Color(hex: "6A9C7F")
        }
        return Color(hex: primaryActionHex)
    }

    var primaryTextColor: Color {
        Color(hex: primaryActionTextHex)
    }
}

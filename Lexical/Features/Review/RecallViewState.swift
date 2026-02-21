import Foundation

enum RecallViewState: Equatable {
    case loading
    case question
    case answer
    case completion(RecallCompletionState)
}

enum RecallCompletionState: Equatable {
    case dueComplete
    case noDue
    case fallbackComplete
    case fallbackUnavailable
}

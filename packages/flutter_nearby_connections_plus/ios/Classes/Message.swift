import Foundation

struct Message: Codable {
    let body: String
}

// MARK: - Existing response models

struct ReceivedResponse: Codable {
    let message: MessageReponse?
}

struct MessageReponse: Codable {
    let items: MessageItemCollection?
}

struct MessageResponseItem: Codable {
    let id: Int?
    let message: String?
}

struct MessageItemCollection: Codable {
    let items: [MessageResponseItem]?
}

struct MessageItemCollectionStatus: Codable {
    let status: String?
}
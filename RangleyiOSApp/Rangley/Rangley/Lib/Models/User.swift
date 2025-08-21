import Foundation

public struct User: Sendable, Codable, Hashable, Identifiable {
    public var id: Int64 { UserId }

    public let UserId   : Int64
    public let FirstName: String
    public let LastName : String
    public let CellPhone: String
    public let Email    : String
    public let UID      : String

    public init(UserId: Int64, FirstName: String, LastName: String,
                CellPhone: String, Email: String, UID: String) {
        self.UserId    = UserId
        self.FirstName = FirstName
        self.LastName  = LastName
        self.CellPhone = CellPhone
        self.Email     = Email
        self.UID       = UID
    }

    public var fullName: String { "\(FirstName) \(LastName)".trimmingCharacters(in: .whitespaces) }
}

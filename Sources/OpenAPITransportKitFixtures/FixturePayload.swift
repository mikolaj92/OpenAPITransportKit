public import Foundation
public import HTTPTypes

public struct FixtureResponseMetadata: Sendable {
    public var status: HTTPResponse.Status?
    public var headerFields: HTTPFields?

    public init(
        status: HTTPResponse.Status? = nil,
        headerFields: HTTPFields? = nil
    ) {
        self.status = status
        self.headerFields = headerFields
    }
}

public struct FixtureResponseMetadataDocument: Codable, Equatable, Sendable {
    public var status: Int?
    public var reasonPhrase: String?
    public var headers: [String: String]?
    public var headerFields: [FixtureHeaderFieldDocument]?

    public init(
        status: Int? = nil,
        reasonPhrase: String? = nil,
        headers: [String: String]? = nil,
        headerFields: [FixtureHeaderFieldDocument]? = nil
    ) {
        self.status = status
        self.reasonPhrase = reasonPhrase
        self.headers = headers
        self.headerFields = headerFields
    }

    public init(metadata: FixtureResponseMetadata) {
        self.status = metadata.status?.code
        self.reasonPhrase = metadata.status?.reasonPhrase
        self.headers = nil
        self.headerFields = metadata.headerFields.map { fields in
            fields.map {
                FixtureHeaderFieldDocument(name: $0.name.rawName, value: $0.value)
            }
        }
    }

    public func metadata() throws -> FixtureResponseMetadata {
        var headerFields = HTTPFields()
        var hasHeaderFields = false
        if let headers {
            for (name, value) in headers {
                guard let fieldName = HTTPField.Name(name) else {
                    throw FixtureError.invalidHeaderName(name)
                }
                headerFields[fieldName] = value
            }
            hasHeaderFields = true
        }

        if let fields = self.headerFields {
            for field in fields {
                guard let fieldName = HTTPField.Name(field.name) else {
                    throw FixtureError.invalidHeaderName(field.name)
                }
                headerFields.append(HTTPField(name: fieldName, value: field.value))
            }
            hasHeaderFields = true
        }

        let status = status.map {
            HTTPResponse.Status(code: $0, reasonPhrase: reasonPhrase ?? "")
        }

        return FixtureResponseMetadata(
            status: status,
            headerFields: hasHeaderFields ? headerFields : nil
        )
    }
}

public struct FixtureHeaderFieldDocument: Codable, Equatable, Sendable {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct FixturePayload: Sendable {
    public var data: Data
    public var metadata: FixtureResponseMetadata?

    public init(data: Data, metadata: FixtureResponseMetadata? = nil) {
        self.data = data
        self.metadata = metadata
    }

    public init(string: String, metadata: FixtureResponseMetadata? = nil) {
        self.data = Data(string.utf8)
        self.metadata = metadata
    }
}

public struct FixtureResponseDefaults: Sendable {
    public var status: HTTPResponse.Status
    public var headerFields: HTTPFields

    public init(
        status: HTTPResponse.Status = .ok,
        headerFields: HTTPFields = [:]
    ) {
        self.status = status
        self.headerFields = headerFields
    }

    public static var jsonOK: Self {
        var fields = HTTPFields()
        fields[.contentType] = "application/json"
        return .init(status: .ok, headerFields: fields)
    }
}

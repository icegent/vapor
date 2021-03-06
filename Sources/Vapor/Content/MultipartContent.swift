import Multipart
import HTTP
import Foundation

extension MultipartForm: Content {
    /// Encodes a MultipartForm as Data
    public func encode(to encoder: Encoder) throws {
        try MultipartSerializer(form: self).serialize().encode(to: encoder)
    }
    
    /// Creates a new MultipartForm from decoded Data
    public init(from decoder: Decoder) throws {
        let data = try Data(from: decoder)
        
        self = try MultipartParser(data: data, boundary: MultipartParser.boundary(for: data)).parse()
    }
    
    /// See Content.defaultMediaType
    public static var defaultMediaType: MediaType {
        return .multipart
    }
    
    /// See RequestEncodable.encode
    public func encode(using container: Container) throws -> Future<Request> {
        guard let boundary = String(bytes: self.boundary, encoding: .utf8) else {
            throw VaporError(identifier: "boundary-utf8", reason: "The Multipart boundary was not valid UTF-8", source: .capture())
        }

        let req = Request(using: container)
        let data = MultipartSerializer(form: self).serialize()
        req.http.body = HTTPBody(data)
        req.http.headers[.contentType] = "multipart/form-data; boundary=" + boundary
        return Future(req)
    }
    
    /// See ResponseEncodable.encode
    public func encode(for req: Request) throws -> Future<Response> {
        guard let boundary = String(bytes: self.boundary, encoding: .utf8) else {
            throw VaporError(identifier: "boundary-utf8", reason: "The Multipart boundary was not valid UTF-8", source: .capture())
        }

        let res = req.makeResponse()
        let data = MultipartSerializer(form: self).serialize()
        res.http.body = HTTPBody(data)
        res.http.headers[.contentType] = "multipart/form-data; boundary=" + boundary
        return Future(res)
    }
    
    /// See RequestDecodable.decode
    public static func decode(from req: Request) throws -> Future<MultipartForm> {
        guard let boundary = req.http.headers[.contentType, "boundary"] else {
            throw VaporError(identifier: "boundary-utf8", reason: "The Multipart boundary was not found in the headers", source: .capture())
        }

        let config = try req.make(MultipartFormConfig.self)
        return req.http.body.makeData(max: config.maxSize).map(to: MultipartForm.self) { data in
            return try MultipartParser(data: data, boundary: Array(boundary.utf8)).parse()
        }
    }
    
    /// See ResponseDecodable.decode
    public static func decode(from res: Response, for req: Request) throws -> Future<MultipartForm> {
        guard let boundary = req.http.headers[.contentType, "boundary"] else {
            throw VaporError(identifier: "boundary-utf8", reason: "The Multipart boundary was not found in the headers", source: .capture())
        }

        let config = try req.make(MultipartFormConfig.self)
        return req.http.body.makeData(max: config.maxSize).map(to: MultipartForm.self) { data in
            return try MultipartParser(data: data, boundary: Array(boundary.utf8)).parse()
        }
    }
}

/// Configure Multipart forms.
public struct MultipartFormConfig: ServiceType {
    /// Max supported message size.
    public var maxSize: Int

    /// Creates a new `MultipartFormConfig`
    public init(maxSize: Int) {
        self.maxSize = maxSize
    }

    /// Creates a default `MultipartFormConfig`
    public static func `default`() -> MultipartFormConfig {
        return .init(maxSize: 1_000_000)
    }

    /// See `ServiceType.makeService(for:)`
    public static func makeService(for worker: Container) throws -> MultipartFormConfig {
        return .default()
    }

}

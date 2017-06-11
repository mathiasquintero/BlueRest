
import Foundation
import CoreBluetooth

struct Message: Codable {
    let resource: String
    let code: Int
    let info: [String : String]
    let body: Data?
}

extension Message {
    
    func decode<V: Decodable>() throws -> V? {
        guard let body = body else {
            return nil
        }
        let decoder = JSONDecoder()
        return try decoder.decode(V.self, from: body)
    }
    
}

class RESTBLEServer {
    
    typealias ServerHandler = (Message, Response) -> Void
    
    struct Response {
        let message: Message
        let response: Server.Response
        
        func respond(with data: Data?,
                     code: Int = 200,
                     info: [String : String] = [:]) {
            
            let responseMessage = Message(resource: message.resource, code: code, info: info, body: data)
            let data = try? JSONEncoder().encode(responseMessage)
            response.respond(data: data)
        }
        
        func respond<V: Encodable>(with value: V?,
                                   code: Int = 200,
                                   info: [String : String] = [:]) {
            
            guard let value = value else {
                return respond(with: nil, code: code, info: info)
            }
            respond(with: try? JSONEncoder().encode(value), code: 200, info: info)
        }
        
    }
    
    private let server: Server
    
    init(uuid: CBUUID, handler: @escaping ServerHandler) {
        server = Server(uuid: uuid) { request, response in
            guard let data = request.data,
                let message = try? JSONDecoder().decode(Message.self, from: data) else {
                    
                return
            }
            let response = Response(message: message, response: response)
            handler(message, response)
        }
    }
    
    func start() {
        server.start()
    }
    
    func stop() {
        server.stop()
    }
    
}


import CoreBluetooth

public func fetch<V: Encodable>(uuid: CBUUID, resource: String, info: [String : String] = [:], body: V?, completion: (Message?) -> Void) {
    let data: Data?
    if let body = body, let encoded = try? JSONEncoder().encode(body) {
        data = encoded
    } else {
        data = nil
    }
    fetch(uuid: uuid, resource: resource, info: info, body: data, completion: completion)
}

public func fetch(uuid: CBUUID, resource: String, info: [String : String] = [:], body: Data? = nil, completion: @escaping (Message?) -> Void) {
    let message = Message(resource: resource, code: 200, info: info, body: body)
    let data = try? JSONEncoder().encode(message)
    fetch(uuid: uuid, data: data) { response in
        guard let data = response.data else {
            return completion(nil)
        }
        let message = try? JSONDecoder().decode(Message.self, from: data)
        completion(message)
    }
}

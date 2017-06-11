
import CoreBluetooth

func fetch(uuid: CBUUID, message: Message, completion: @escaping (Message?) -> Void) {
    let data = try? JSONEncoder().encode(message)
    fetch(uuid: uuid, data: data) { response in
        guard let data = response.data else {
            return completion(nil)
        }
        let message = try? JSONDecoder().decode(Message.self, from: data)
        completion(message)
    }
}

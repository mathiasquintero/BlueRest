
import CoreBluetooth

public class Server: NSObject {
    
    public struct Request {
        let device: UUID
        let data: Data?
    }
    
    public class Response {
        
        private var request: Request
        private unowned var server: Server
        
        init(request: Request, server: Server) {
            self.request = request
            self.server = server
        }
        
        deinit {
            server.remove(request: request)
        }
        
        func respond(data: Data?) {
            server.respond(with: data, to: request)
        }
        
    }
    
    public typealias ServerHandler = (Request, Response) -> Void
    
    private let uuid: CBUUID
    private let handler: ServerHandler
    
    private var psm: CBL2CAPPSM!
    
    private var channels = [CBL2CAPChannel]()
    
    private lazy var manager: CBPeripheralManager = {
       return CBPeripheralManager(delegate: self, queue: nil)
    }()
    
    private var advertisementData: [String : Any] {
        return  [
            CBAdvertisementDataIsConnectable: NSNumber(booleanLiteral: true),
            CBAdvertisementDataServiceUUIDsKey: [uuid],
            CBAdvertisementDataLocalNameKey: String(psm.bigEndian)
        ]
    }
    
    public init(uuid: CBUUID, handler: @escaping ServerHandler) {
        self.uuid = uuid
        self.handler = handler
    }
    
    public func start() {
        _ = manager
    }
    
    public func stop() {
        manager.stopAdvertising()
    }
    
}

extension Server {
    
    func channel(for uuid: UUID) -> CBL2CAPChannel? {
        return channels.reduce(nil) { result, channel in
            guard uuid == channel.peer.identifier else {
                return result
            }
            return result ?? channel
        }
    }
    
    func channel(for request: Request) -> CBL2CAPChannel? {
        return channel(for: request.device)
    }
    
    func remove(channel: CBL2CAPChannel) {
        guard let index = channels.index(where: { $0 == channel }) else { return }
        channel.inputStream.close()
        channel.outputStream.close()
        channels.remove(at: index)
    }
    
    func remove(device: UUID) {
        guard let channel = channel(for: device) else {
            return
        }
        remove(channel: channel)
    }
    
    func remove(request: Request) {
        remove(device: request.device)
    }
    
}

extension Server {
    
    func respond(with data: Data?, to channel: CBL2CAPChannel) {
        guard let stream = channel.outputStream else {
            return
        }
        send(data: data, in: stream) {
            print("SENT!")
        }
    }
    
    func respond(with data: Data?, to request: Request) {
        guard let channel = channel(for: request) else {
            return
        }
        respond(with: data, to: channel)
    }
    
}

extension Server {
    
    func handle(data: Data?, in channel: CBL2CAPChannel) {
        let request = Request(device: channel.peer.identifier, data: data)
        let response = Response(request: request, server: self)
        handler(request, response)
    }
    
}

extension Server: CBPeripheralManagerDelegate {
    
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            peripheral.publishL2CAPChannel(withEncryption: true)
        default:
            break
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        print("Did publish")
        self.psm = PSM
        manager.startAdvertising(advertisementData)
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didUnpublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        print("Did unpublish")
        self.psm = nil
        manager.stopAdvertising()
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard error == nil, let channel = channel, let stream = channel.inputStream else {
            return
        }
        channels.append(channel)
        receive(from: stream) { [weak self] data in
            self?.handle(data: data, in: channel)
        }
    }
    
}


import CoreBluetooth

var requests = [Request]()

func fetch(uuid: CBUUID, device: UUID? = nil, data: Data? = nil, completion: @escaping (Request.Response) -> Void) {
    var called = false
    let request = Request(uuid: uuid, device: device, data: data) { request, response in
        called = true
        completion(response)
        guard let index = requests.index(where: { $0 == request }) else {
            return
        }
        requests.remove(at: index)
    }
    request.perform()
    if !called {
        requests.append(request)
    }
}

class Request: NSObject {
    
    struct Response {
        let device: UUID
        let data: Data?
    }
    
    typealias Completion = (Request, Response) -> Void
    
    private let uuid: CBUUID
    private let device: UUID?
    private let data: Data?
    private let completion: Completion
    private lazy var manager: CBCentralManager = {
       return CBCentralManager(delegate: self, queue: nil)
    }()
    
    private var peripheral: CBPeripheral!
    private var channel: CBL2CAPChannel!
    private var psm: CBL2CAPPSM!
    
    var shouldCheckDevice: Bool {
        return device != nil
    }
    
    init(uuid: CBUUID, device: UUID? = nil, data: Data?, completion: @escaping Completion) {
        self.uuid = uuid
        self.device = device
        self.data = data
        self.completion = completion
    }
    
    deinit {
        manager.stopScan()
        if peripheral != nil {
            manager.cancelPeripheralConnection(peripheral)
        }
    }
    
    func perform() {
        _ = manager
    }
    
    func retry() {
        if let peripheral = peripheral {
            manager.cancelPeripheralConnection(peripheral)
        }
    }
    
}

extension Request {
    
    func start() {
        send(data: data, in: channel.outputStream) { [weak self] in
            self?.listen()
        }
    }
    
    func listen() {
        receive(from: channel.inputStream) { [weak self] data in
            self?.finish(with: data)
        }
    }
    
    func finish(with data: Data) {
        let response = Response(device: peripheral.identifier, data: data)
        completion(self, response)
    }
    
}

extension Request: CBCentralManagerDelegate {
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: [uuid], options: nil)
        default:
            break
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let isConnectable = (advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber) ?? 0
        guard let string = advertisementData[CBAdvertisementDataLocalNameKey] as? String, let number = UInt16(string) else {
            return
        }
        psm = CBL2CAPPSM(bigEndian: number)
        guard isConnectable.boolValue else {
            return
        }
        if shouldCheckDevice, peripheral.identifier != device {
            return
        }
        self.peripheral = peripheral
        central.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.openL2CAPChannel(psm)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if error == nil {
            central.scanForPeripherals(withServices: [uuid], options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // TODO: FUUUCK!!!
    }
    
}

extension Request: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard let channel = channel, error == nil else {
            print("Encountered Error: \(String(describing: error))")
            retry()
            return
        }
        self.channel = channel
        start()
    }
    
}


import Foundation

var receivers = [Receiver]()

func receive(from stream: InputStream, in completion: @escaping (Data) -> Void) {
    var called = false
    let receiver = Receiver(stream: stream) { receiver, data in
        called = true
        completion(data)
        guard let index = receivers.index(where: { $0 == receiver }) else {
            return
        }
        receivers.remove(at: index)
    }
    if !called {
        receivers.append(receiver)
    }
}

class Receiver: NSObject {
    
    typealias Completion = (Receiver, Data) -> Void
    
    private let stream: InputStream
    private let completion: Completion
    
    init(stream: InputStream, completion: @escaping Completion) {
        self.stream = stream
        self.completion = completion
        super.init()
        if stream.streamStatus == .atEnd {
            finish()
        } else {
            stream.delegate = self
        }
    }
    
    func finish() {
        let data = Data(reading: stream)
        completion(self, data)
    }
    
}

extension Receiver: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard aStream == stream else {
            return
        }
        switch eventCode {
        case .endEncountered:
            finish()
        default:
            break
        }
    }
    
}

extension Data {
    
    init(reading input: InputStream) {
        self.init()
        input.open()
        
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        while input.hasBytesAvailable {
            let read = input.read(buffer, maxLength: bufferSize)
            self.append(buffer, count: read)
        }
        buffer.deallocate(capacity: bufferSize)
        
        input.close()
    }
    
}


import Foundation

var senders = [Sender]()

func send(data: Data?, in stream: OutputStream, completion: @escaping () -> Void) {
    var called = false
    let sender = Sender(stream: stream, data: data) { sender in
        called = true
        completion()
        guard let index = receivers.index(where: { $0 == sender }) else {
            return
        }
        receivers.remove(at: index)
    }
    if !called {
        senders.append(sender)
    }
}

class Sender: NSObject {
    
    typealias Completion = (Sender) -> Void
    
    private let stream: OutputStream
    private let data: Data
    private let completion: Completion
    
    init(stream: OutputStream, data: Data?, completion: @escaping Completion) {
        self.stream = stream
        self.data = data ?? Data()
        self.completion = completion
    }
    
    func send() {
        stream.delegate = self
        guard stream.hasSpaceAvailable else {
            return
        }
        stream.delegate = nil
        let buffer = [UInt8](data)
        stream.write(buffer, maxLength: buffer.count)
        completion(self)
    }
    
}

extension Sender: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        guard case .hasSpaceAvailable = eventCode else {
            return
        }
        send()
    }
    
}

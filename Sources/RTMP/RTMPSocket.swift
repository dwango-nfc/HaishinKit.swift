import Foundation

// MARK: -
final class RTMPSocket: NetSocket, RTMPSocketCompatible {
    var readyState: RTMPSocketReadyState = .uninitialized {
        didSet {
            delegate?.socket(self, readyState: readyState)
        }
    }
    var timestamp: TimeInterval {
        handshake.timestamp
    }
    var chunkSizeC: Int = RTMPChunk.defaultSize
    var chunkSizeS: Int = RTMPChunk.defaultSize
    weak var delegate: RTMPSocketDelegate?
    private var handshake = RTMPHandshake()
    private var isOutputUnavailable = false {
        didSet {
            if oldValue != isOutputUnavailable {
                let data = isOutputUnavailable ? RTMPConnection.Code.outputUnavailable.data("") : RTMPConnection.Code.outputRecovered.data("")
                self.delegate?.dispatch(event: Event(
                    type: .rtmpStatus,
                    bubbles: false,
                    data: data
                ))
            }
        }
    }

    override var totalBytesIn: Atomic<Int64> {
        didSet {
            delegate?.socket(self, totalBytesIn: totalBytesIn.value)
        }
    }

    override var connected: Bool {
        didSet {
            if connected {
                doOutput(data: handshake.c0c1packet)
                readyState = .versionSent
                return
            }
            readyState = .closed
            for event in events {
                delegate?.dispatch(event: event)
            }
            events.removeAll()
        }
    }
    private var events: [Event] = []

    @discardableResult
    func doOutput(chunk: RTMPChunk) -> Int {
        setOutputAvailability()
        let chunks: [Data] = chunk.split(chunkSizeS)
        for i in 0..<chunks.count - 1 {
            doOutput(data: chunks[i])
        }
        doOutput(data: chunks.last!)
        if logger.isEnabledFor(level: .trace) {
            logger.trace(chunk)
        }
        return chunk.message!.length
    }
    
    private func setOutputAvailability() {
        if let outputStream = self.outputStream, outputStream.hasSpaceAvailable {
            isOutputUnavailable = false
        } else {
            isOutputUnavailable = true
        }
    }

    override func listen() {
        switch readyState {
        case .versionSent:
            if inputBuffer.count < RTMPHandshake.sigSize + 1 {
                break
            }
            doOutput(data: handshake.c2packet(inputBuffer))
            inputBuffer.removeSubrange(0...RTMPHandshake.sigSize)
            readyState = .ackSent
            if RTMPHandshake.sigSize <= inputBuffer.count {
                listen()
            }
        case .ackSent:
            if inputBuffer.count < RTMPHandshake.sigSize {
                break
            }
            inputBuffer.removeAll()
            readyState = .handshakeDone
        case .handshakeDone:
            if inputBuffer.isEmpty {
                break
            }
            let bytes: Data = inputBuffer
            inputBuffer.removeAll()
            delegate?.socket(self, data: bytes)
        default:
            break
        }
    }

    override func initConnection() {
        handshake.clear()
        readyState = .uninitialized
        chunkSizeS = RTMPChunk.defaultSize
        chunkSizeC = RTMPChunk.defaultSize
        super.initConnection()
    }

    override func deinitConnection(isDisconnected: Bool) {
        if isDisconnected {
            let data: ASObject = (readyState == .handshakeDone) ?
                RTMPConnection.Code.connectClosed.data("") : RTMPConnection.Code.connectFailed.data("")
            events.append(Event(type: .rtmpStatus, bubbles: false, data: data))
        }
        readyState = .closing
        super.deinitConnection(isDisconnected: isDisconnected)
    }

    override func didTimeout() {
        deinitConnection(isDisconnected: false)
        delegate?.dispatch(.ioError, bubbles: false, data: nil)
        logger.warn("connection timedout")
    }
}

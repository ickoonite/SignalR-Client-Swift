//
//  SwiftWebSocketsTransport.swift
//  
//
//  Created by Gareth Potter on 02/05/2020.
//

import Foundation

@available(iOS 13.0, *)
class SwiftWebSocketsTransport : NSObject, Transport, URLSessionWebSocketDelegate {
    public weak var delegate: TransportDelegate?
    let delegateQueue = OperationQueue()
    var urlSession: URLSession!
    var task: URLSessionWebSocketTask!
    
    func start(url: URL, options: HttpConnectionOptions) {
        let wsUrl = convertUrl(url: url)
        self.urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
        self.task = urlSession.webSocketTask(with: wsUrl)
        didReceiveMessage() // this deserves an eye roll; see comment below
        task.resume()
    }
    
    func didReceiveMessage() {
        task.receive { [weak self] received in
            guard let self = self else {
                return
            }
            switch received {
            case let .success(msg):
                switch msg {
                case let .data(data):
                    self.delegate?.transportDidReceiveData(data)
                case let .string(string):
                    self.delegate?.transportDidReceiveData(string.data(using: .utf8)!)
                @unknown default:
                    fatalError()
                }
            case let .failure(e):
                self.delegate?.transportDidClose(SwiftWebSocketsTransportError.receive(underlying: e))
                return
            }
            
            // for some unknown reason, if we want to keep receiving messages
            // we have to keep hooking up the callback, so...
            // https://appspector.com/blog/websockets-in-ios-using-urlsessionwebsockettask
            self.didReceiveMessage()
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        delegate?.transportDidOpen()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        delegate?.transportDidClose(nil)
    }
    
    func send(data: Data, sendDidComplete: @escaping (_ error: Error?) -> Void) {
        if task.state == .canceling || task.state == .completed {
            sendDidComplete(SwiftWebSocketsTransportError.closed)
        }
        let message = URLSessionWebSocketTask.Message.data(data)
        task.send(message) { error in
            sendDidComplete(error)
        }
    }
    
    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
    
    private func convertUrl(url: URL) -> URL {
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if (components.scheme == "http") {
                components.scheme = "ws"
            } else if (components.scheme == "https") {
                components.scheme = "wss"
            }
            return components.url!
        }

        return url
    }
}

enum SwiftWebSocketsTransportError : Error {
    case closed
    case receive(underlying: Error)
}

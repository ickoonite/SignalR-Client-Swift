//
//  DefaultTransportFactory.swift
//  SignalRClient
//
//  Created by Pawel Kadluczka on 8/22/18.
//  Copyright © 2018 Pawel Kadluczka. All rights reserved.
//

import Foundation

internal class DefaultTransportFactory: TransportFactory {
    let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func createTransport(availableTransports: [TransportDescription]) throws -> Transport {
        for transport in availableTransports {
            if transport.transportType == .webSockets {
                if #available(iOS 13.0, *) {
                    return SwiftWebSocketsTransport()
                } else {
                    return WebsocketsTransport(logger: logger)
                }
            }
        }

        throw SignalRError.noSupportedTransportAvailable
    }
}

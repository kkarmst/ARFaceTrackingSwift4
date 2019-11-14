//
//  TCPUtil.swift
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-11-08.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

import Foundation

class TCPUtil: NSObject {
    
    // Streaming mode properties
    var host = "192.168.0.14"
    var port = 2020
    var inStream: InputStream!
    var outStream: OutputStream!
    private var connect: Bool = false
    private var isStreaming: Bool = false
    
    private let saveQueue = DispatchQueue.init(label: "stream")
    private let dispatchGroup = DispatchGroup()
    
    init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
    
    func streamData(data: String!) {
        if outStream.streamStatus == .error {
            stopStream()
            return
        }
        
        guard let streamdata = data else {return}
        dispatchGroup.enter()
        saveQueue.async {
            let endtag = "a"
            let dataStr = streamdata + endtag
            let dataBuffer = dataStr.data(using: .utf8)!
            if self.outStream.streamStatus == .open {
                _ = dataBuffer.withUnsafeBytes { self.outStream.write($0, maxLength: dataBuffer.count) }
            }
        }
    }
    
    func stopStream() {
        self.isStreaming = false
        // Stream Mode : Send "z" to server to tell that I'm stop streaming
        let dataStr = "z"
        let dataBuffer = dataStr.data(using: .utf8)!
        _ = dataBuffer.withUnsafeBytes { self.outStream.write($0, maxLength: dataBuffer.count) }
        outStream.close()
    }
    
    func startStream() {
        if outStream != nil {
            outStream.close()
        }
        
        var out: OutputStream?
        Stream.getStreamsToHost(withName: host, port: port, inputStream: nil, outputStream: &out)
        outStream = out!
        outStream.open()
        self.isStreaming = true  // This will let didUpdate delegate to stream data
        
    }
}

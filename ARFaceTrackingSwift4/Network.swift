//
//  Networking.swift
//  ARFaceTrackingSwift4
//
//  Created by Kieran Armstrong on 2019-09-10.
//  Copyright © 2019 Kieran Armstrong. All rights reserved.
//

import Foundation

class Network: NSObject, StreamDelegate {
    
    var streamEnabled: Bool = false
    var recordingEnabled: Bool = false
    static let sharedInstance = Network()
    
    //Socket Server
    var addr = "192.168.0.14"
    var port = 2020
    
    //Network Variables
    var inStream: InputStream?
    var outStream: OutputStream?
    
    //Data recieved
    var buffer = [UInt8](repeating: 0, count: 200)
    
    // Network Functions
    func NetworkEnable() {

        print("NetworkEnable")
        Stream.getStreamsToHost(withName: addr, port: port, inputStream: &inStream, outputStream: &outStream)

        inStream?.delegate = self
        outStream?.delegate = self

        inStream?.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)
        outStream?.schedule(in: RunLoop.current, forMode: RunLoop.Mode.default)

        inStream?.open()
        outStream?.open()

        buffer = [UInt8](repeating: 0, count: 200)
    }
    
    func NetworkDisable() {
        inStream?.close()
        inStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
        outStream?.close()
        outStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
    }
    
    func isNetworkEnabled() -> Bool {

        return streamEnabled
        
    }

    func stream(aStream: Stream, handleEvent eventCode: Stream.Event) {

        switch eventCode {
        case Stream.Event.endEncountered:
            print("EndEncountered")
            print("Connection stopped by server")
            inStream?.close()
            inStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
            outStream?.close()
            streamEnabled = false
            print("Stop outStream currentRunLoop")
            outStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
        case Stream.Event.errorOccurred:
            print("ErrorOccurred")

            inStream?.close()
            inStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
            outStream?.close()
            outStream?.remove(from: RunLoop.current, forMode: RunLoop.Mode.default)
            print("Failed to connect to server")
            streamEnabled = false

        case Stream.Event.hasBytesAvailable:
            print("HasBytesAvailable")

            if aStream == inStream {
                inStream!.read(&buffer, maxLength: buffer.count)
                let bufferStr = NSString(bytes: &buffer, length: buffer.count, encoding: String.Encoding.utf8.rawValue)
                print(bufferStr!)
            }

        case Stream.Event.hasSpaceAvailable:
            print("HasSpaceAvailable")
        case Stream.Event.openCompleted:
            print("OpenCompleted")
            print("Connected to server")
            streamEnabled = true
        default:
            print("Unknown")
        }
    }
    
    func sendData(val: String) {
        let data : Data = String(val).data(using: String.Encoding.utf8)!
        let dataMutablePointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)

        //Copies the bytes to the Mutable Pointer
        data.copyBytes(to: dataMutablePointer, count: data.count)

        //Cast to regular UnsafePointer
        let dataPointer = UnsafePointer<UInt8>(dataMutablePointer)
        outStream?.write(dataPointer, maxLength: data.count)
    }
}

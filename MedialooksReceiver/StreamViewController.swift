//
//  StreamViewController.swift
//  MedialooksReceiver
//
//  Created by admin on 11/8/17.
//  Copyright © 2017 admin. All rights reserved.
//

import UIKit
import AVFoundation
import SocketIO
import SVProgressHUD

//class StreamViewController: UIViewController,  RTCSessionDescriptionDelegate, RTCPeerConnectionDelegate, RTCEAGLVideoViewDelegate {

class StreamViewController: UIViewController, RTCEAGLVideoViewDelegate, RTCPeerConnectionDelegate, RTCSessionDescriptionDelegate {
    
    @IBOutlet weak var remoteVideoView: RTCEAGLVideoView!
    
    var accessURL: String = ""
    var accessRoom: String = ""
    var accessID: String = ""
    var remoteID: String = ""
    
    var socket: SocketIOClient!
    
    var iceServers: Array = [] as Array
    
    var peerConnectionFactory: RTCPeerConnectionFactory!
    var peerConnection: RTCPeerConnection!
    var pcConstraints: RTCMediaConstraints!
    
    var videoConstraints: RTCMediaConstraints!
    var audioConstraints: RTCMediaConstraints!
    var mediaConstraints: RTCMediaConstraints!
    
    var remoteVideoTrack: RTCVideoTrack!
    var remoteAudioTrack: RTCAudioTrack!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        SVProgressHUD.show()
        self.initWebRTC()
        
        remoteVideoView.delegate = self
        
        self.connectToSigServer()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func initWebRTC() {
        RTCPeerConnectionFactory.initializeSSL()
        peerConnectionFactory = RTCPeerConnectionFactory()
        
        pcConstraints = RTCMediaConstraints()
        videoConstraints = RTCMediaConstraints()
        audioConstraints = RTCMediaConstraints()
        mediaConstraints = RTCMediaConstraints(
            mandatoryConstraints: [
                RTCPair(key: "OfferToReceiveAudio", value: "true"),
                RTCPair(key: "OfferToReceiveVideo", value: "true")
            ],
            optionalConstraints: nil)
    }

    // MARK: - SocketIO
    func connectToSigServer() {
        self.socket = SocketIOClient(socketURL: URL(string: self.accessURL)!)
        
        self.socket.onAny {print("Got event: \($0.event), with items: \(String(describing: $0.items))")}
        
        self.socket.on("connect") { (data, emitter) in
            self.joinRoom()
        }
        
        self.socket.on("stunservers") { data, ack in
            let stunServers = data as NSArray
            for item in stunServers {
                let data = item as! NSArray
                for element in data {
                    let stunServer: [String: String] = element as! NSDictionary as! [String: String]
                    self.iceServers.append(RTCICEServer(uri: URL(string:stunServer["url"]!)!, username: "", password: ""))
                }
            }
        }
        
        self.socket.on("roommembers") { data, ack in
            let roomMembers = data as NSArray
            for roomMember in roomMembers {
                let tmp: [String: Any] = roomMember as! NSDictionary as! [String: Any]
                let clients = tmp["clients"] as! NSArray
                for client in clients {
                    let compareData: [String : String] = client as! NSDictionary as! [String: String]
                    if (compareData["id"] == self.accessID || compareData["nickname"] == self.accessID || compareData["nickName"] == self.accessID  || compareData["name"] == self.accessID  || compareData["strongId"] == self.accessID ) {
                        if (compareData["vidEncoder"] == "h264") {
                            self.createPeerConnection(data: compareData)
                        } else {
                            SVProgressHUD.dismiss()
                            self.disconnect()
                        }
                    }
                }
            }
        }
        
        self.socket.on("message") { data, ack in
            let json = data[0] as! NSDictionary
            let type = json["type"] as! String
            if (type == "candidate") {
                let payload = json["payload"] as! NSDictionary
                let candidate = payload["candidate"] as! NSDictionary
                self.peerConnection.add(RTCICECandidate(
                    mid: candidate["sdpMid"] as! String,
                    index: candidate["sdpMLineIndex"] as! Int,
                    sdp: candidate["candidate"] as! String
                ))
            } else if (type == "answer") {
                let payload = json["payload"] as! NSDictionary
                let sdp = payload["sdp"] as! String
                self.peerConnection.setRemoteDescriptionWith(self, sessionDescription: RTCSessionDescription(type: "answer", sdp: sdp))
            }
        }
        
        self.iceServers.removeAll()
        self.socket.connect()
    }
    
    func joinRoom() {
        print("Setting strongId:", self.socket.sid!)
        self.socket.emit("setinfo", ["nickName": "", "strongId": self.socket.sid, "mode": ""])
        print("Joining room...")
        self.socket.emit("join", self.accessRoom)
    }
    
    func createPeerConnection(data: [String: String]) {
        print("Creating peerConnection....")
        self.remoteID = data["id"]!
        let rtcConfig: RTCConfiguration = RTCConfiguration()
        rtcConfig.tcpCandidatePolicy = RTCTcpCandidatePolicy.disabled
        rtcConfig.bundlePolicy = RTCBundlePolicy.maxBundle
        rtcConfig.rtcpMuxPolicy = RTCRtcpMuxPolicy.require
        
        peerConnection = peerConnectionFactory.peerConnection(withICEServers: self.iceServers, constraints: pcConstraints, delegate: self)
        self.socket.emit("joinedRoom", self.accessRoom)
        peerConnection.createOffer(with: self, constraints: mediaConstraints)
    }
    
    func sendMessage(message: NSDictionary) {
        self.socket.emit("message", message)
    }
    
    // MARK: - RTCPeerConnectionDelegate
    func peerConnection(_ peerConnection: RTCPeerConnection!, gotICECandidate candidate: RTCICECandidate!) {
        if (candidate != nil) {
            let candidate:[String: AnyObject] = [
                "sdpMLineIndex" : candidate.sdpMLineIndex as AnyObject,
                "sdpMid" : candidate.sdpMid as AnyObject,
                "candidate" : candidate.sdp as AnyObject
            ]
            
            let payload: [String: AnyObject] = [
                "candidate": candidate as AnyObject
            ]
            
            let message:[String: AnyObject] = [
                "type" : "candidate" as AnyObject,
                "to" : self.remoteID as AnyObject,
                "sid" : self.socket.sid as AnyObject,
                "payload": payload as AnyObject
            ]
            self.sendMessage(message: message as NSDictionary)
        } else {
            print("End of candidates. -------------------")
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, signalingStateChanged stateChanged: RTCSignalingState) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, iceConnectionChanged newState: RTCICEConnectionState) {
        var stateString: String = ""
        switch newState {
        case RTCICEConnectionNew:
            stateString = "RTCICEConnectionNew"
        case RTCICEConnectionChecking:
            stateString = "RTCICEConnectionChecking"
        case RTCICEConnectionConnected:
            stateString = "RTCICEConnectionConnected"
        case RTCICEConnectionCompleted:
            stateString = "RTCICEConnectionCompleted"
        case RTCICEConnectionFailed:
            stateString = "RTCICEConnectionFailed"
        case RTCICEConnectionDisconnected:
            stateString = "RTCICEConnectionDisconnected"
            self.disconnect()
        case RTCICEConnectionClosed:
            stateString = "RTCICEConnectionClosed"
        default:
            stateString = "Unknown"
        }
        print("ICE connection : \(stateString)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, iceGatheringChanged newState: RTCICEGatheringState) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, addedStream stream: RTCMediaStream!) {
        if (peerConnection == nil) {
            return
        }
        
        if (stream.videoTracks.count == 1) {
            remoteVideoTrack = stream.videoTracks[0] as! RTCVideoTrack
            remoteVideoTrack.setEnabled(true)
            remoteVideoTrack.add(remoteVideoView)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, removedStream stream: RTCMediaStream!) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didOpen dataChannel: RTCDataChannel!) {
    }
    
    func peerConnection(onRenegotiationNeeded peerConnection: RTCPeerConnection!) {
    }
    
    // MARK: - RTCSessionDescriptionDelegate
    func peerConnection(_ peerConnection: RTCPeerConnection!, didCreateSessionDescription sdp: RTCSessionDescription!, error: Error!) {
        if (error == nil) {
            self.peerConnection.setLocalDescriptionWith(self, sessionDescription: sdp)
            let payload: [String: AnyObject] = [
                "sdp": sdp.description as AnyObject,
                "type": "offer" as AnyObject
            ]
            let message:[String: AnyObject] = [
                "type" : sdp.type as AnyObject,
                "to" : self.remoteID as AnyObject,
                "sid" : self.socket.sid as AnyObject,
                "payload": payload as AnyObject,
                "roomType": "video" as AnyObject
            ]
            self.sendMessage(message: message as NSDictionary)
        } else {
            print("sdp creation error: " + error.localizedDescription)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection!, didSetSessionDescriptionWithError error: Error!) {
    }
    
    // MARK: - RTCEAGLVideoViewDelegate
    func videoView(_ videoView: RTCEAGLVideoView!, didChangeVideoSize size: CGSize) {
        print(size)
        SVProgressHUD.dismiss()
    }
    
    func disconnect() {
        let alertVC = UIAlertController(title: "Notice", message: "Video streaming was disconnected from server. Please check server is lived now or Network is available.", preferredStyle: .alert)
        let okAct = UIAlertAction(title: "OK", style: .default) { (act) in
            if (self.peerConnection != nil) {
                self.peerConnection.close()
                self.peerConnection = nil
            }
            self.dismiss(animated: true, completion: nil)
        }
        alertVC.addAction(okAct)
        self.present(alertVC, animated: true, completion: nil)
    }

}

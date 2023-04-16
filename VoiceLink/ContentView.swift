import Accelerate
import AVFoundation
import SwiftUI
import WatchConnectivity

struct BulletedText: View {
    let text: String
    let bullet: String
    
    init(_ text: String, bullet: String = "•") {
        self.text = text
        self.bullet = bullet
    }
    
    var body: some View {
        let items = self.text.components(separatedBy: "\n")
        
        return VStack(alignment: .leading, spacing: 5) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 5) {
                    Text(self.bullet)
                    Text(item)
                }
            }
        }
    }
}

class WatchSessionManager: NSObject, WCSessionDelegate {
    var session: WCSession
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        self.session.delegate = self
        self.session.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WatchSessionManager: session activation failed with error: \(error.localizedDescription)")
        } else {
            print("WatchSessionManager: session activated with state: \(activationState.rawValue)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        print("WatchSessionManager: received message data from watch")
        print("WatchSessionManager: message data: \(messageData)")
        
        let audioPlayer = try? AVAudioPlayer(data: messageData)
        audioPlayer?.play()
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WatchSessionManager: session inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WatchSessionManager: session deactivated")
    }
}

struct ContentView: View {
    @State private var isRecording = false
    @State private var messageLog = [String]()
    @State private var volumeLevel: Float = 1.0
    
    let watchSessionManager = WatchSessionManager(session: WCSession.default)
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("VoiceLink")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Spacer()
            
            if self.isRecording {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(.red)
                    .overlay(
                        Circle()
                            .stroke(Color.red, lineWidth: 5)
                            .scaleEffect(CGFloat(self.volumeLevel))
                            .opacity(Double(2 - self.volumeLevel))
                            .animation(Animation.easeOut(duration: 1), value: self.volumeLevel)
                    )
                    .onTapGesture {
                        self.stopRecording()
                    }
                
                Text("Recording...")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "speaker.3.fill")
                        .font(.title2)
                        .padding(.leading, 10)
                    Slider(value: self.$volumeLevel, in: 0 ... 1)
                        .padding(.trailing, 10)
                }
            } else {
                Image(systemName: "mic.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(.red)
                    .onTapGesture {
                        self.startRecording()
                    }
                
                Text("Tap to start recording")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            if self.messageLog.count > 0 {
                Text("Message Log")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(self.messageLog, id: \.self) { message in
                            BulletedText(message)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .frame(height: 100)
            }
            
            Spacer()
            
            Text("[© 2023 Siddharth Praveen Bharadwaj](https://sid110307.github.io/Sid110307)")
                .font(.footnote)
                .font(.system(size: 8))
                .foregroundColor(.gray)
                .accentColor(.gray)
                .multilineTextAlignment(.center)
        }
    }
    
    func sendAudioData(_ data: Data) {
        guard WCSession.isSupported() else {
            self.messageLog.append("WatchConnectivity is not supported on this device")
            print("WatchConnectivity is not supported on this device")
            return
        }
        
        let session = WCSession.default
        self.messageLog.append("Watch connectivity is supported")
        
        if !session.isPaired {
            self.messageLog.append("Watch is not paired")
            print("Watch is not paired")
            
            return
        }
        
        if session.isReachable {
            session.sendMessageData(data, replyHandler: nil, errorHandler: { error in
                self.messageLog.append("Failed to send audio data to watch: \(error.localizedDescription)")
                print("Failed to send audio data to watch: \(error.localizedDescription)")
            })
        } else {
            self.messageLog.append("Watch is not reachable")
            print("Watch is not reachable")
        }
    }
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
            case .granted:
                self.messageLog.append("Microphone access is granted")
                print("Microphone access is granted")
            case .denied:
                self.messageLog.append("Microphone access is denied")
                print("Microphone access is denied")
                
                return
            case .undetermined:
                session.requestRecordPermission { granted in
                    if !granted {
                        self.messageLog.append("Microphone access is not granted")
                        print("Microphone access is not granted")
                        
                        return
                    }
                }
            @unknown default:
                print("startRecording(): unknown error \(session.recordPermission)")
        }
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        
        do {
            try session.setCategory(.record, mode: .default, options: [])
            try session.setActive(true, options: [])
            
            DispatchQueue.main.async {
                self.isRecording = true
            }
        } catch let error as NSError {
            self.messageLog.append("Failed to set audio session category and activate session: \(error.localizedDescription)")
            print("Failed to set audio session category and activate session: \(error.localizedDescription)")
            
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            let channelCount = buffer.format.channelCount
            let bufferLength = UInt32(buffer.frameLength)
            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(channelCount))
            let stride = buffer.stride
            
            var rms: Float = 0.0
            vDSP_rmsqv(channels[0], stride, &rms, vDSP_Length(bufferLength))
            
            let volume = rms * 5.0
            DispatchQueue.main.async {
                self.volumeLevel = volume
            }
            
            let data = Data(bytes: buffer.floatChannelData![0], count: Int(bufferLength * 4))
            self.sendAudioData(data)
        }
        
        do {
            try engine.start()
        } catch let error as NSError {
            self.messageLog.append("Failed to start audio engine: \(error.localizedDescription)")
            print("Failed to start audio engine: \(error.localizedDescription)")
            
            return
        }
        
        self.messageLog.append("Started recording")
        print("Started recording")
    }
    
    func stopRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
            DispatchQueue.main.async {
                self.isRecording = false
            }
        } catch {
            self.messageLog.append("Failed to stop audio session: \(error.localizedDescription)")
            print("Failed to stop audio session: \(error.localizedDescription)")
            
            return
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

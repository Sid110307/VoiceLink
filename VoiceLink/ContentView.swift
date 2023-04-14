import Accelerate
import AVFoundation
import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @State private var isRecording = false
    @State private var messageLog = [String]()
    @State private var volumeLevel: Float = 1.0
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("VoiceLink")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Spacer()
            
            if isRecording {
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(.red)
                    .overlay(
                        Circle()
                            .stroke(Color.red, lineWidth: 2)
                            .scaleEffect(1 + CGFloat(self.volumeLevel))
                            .opacity(Double(2 - self.volumeLevel))
                            .animation(Animation.easeOut(duration: 1), value: self.volumeLevel)
                    )
                    .onTapGesture {
                        stopRecording()
                    }
                
                Text("Recording...")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                HStack {
                    Image(systemName: "speaker.fill")
                        .font(.title2)
                    Slider(value: $volumeLevel, in: 0 ... 1)
                }
            } else {
                Image(systemName: "mic.circle")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(.red)
                    .onTapGesture {
                        startRecording()
                    }
                
                Text("Tap to start recording")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(messageLog, id: \.self) { message in
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
            
            Text("[© 2023 Siddharth Praveen Bharadwaj](https://sid110307.github.io/Sid110307)")
                .font(.footnote)
                .foregroundColor(.gray)
        }
    }
    
    func sendAudioData(_ data: Data) {
        guard WCSession.isSupported() else {
            messageLog.append("WatchConnectivity is not supported on this device")
            return
        }
        
        let message = ["audio": data]
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            DispatchQueue.main.async {
                self.messageLog.append("Failed to send audio data: \(error.localizedDescription)")
            }
        }
        
        let userInfo = ["audioSent": true]
        WCSession.default.transferUserInfo(userInfo)
    }
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
            case .granted:
                break
            case .denied:
                DispatchQueue.main.async {
                    self.messageLog.append("Microphone access is denied")
                }
                
                print("Microphone access is denied")
                return
            case .undetermined:
                session.requestRecordPermission { granted in
                    if !granted {
                        DispatchQueue.main.async {
                            self.messageLog.append("Microphone access is not granted")
                        }
                        
                        print("Microphone access is not granted")
                        return
                    }
                }
            @unknown default:
                break
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
            DispatchQueue.main.async {
                self.messageLog.append("Failed to set audio session category and activate session: \(error.localizedDescription)")
            }
            
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
            DispatchQueue.main.async {
                self.messageLog.append("Failed to start audio engine: \(error.localizedDescription)")
            }
            
            print("Failed to start audio engine: \(error.localizedDescription)")
            return
        }
    }
    
    func stopRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
            DispatchQueue.main.async {
                self.isRecording = false
            }
        } catch {
            DispatchQueue.main.async {
                self.messageLog.append("Failed to stop audio session: \(error.localizedDescription)")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

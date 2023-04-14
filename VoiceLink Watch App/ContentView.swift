import AVFoundation
import SwiftUI

class SessionManager: ObservableObject {
    @Published var receivedData: Data?
}

final class ContentView: NSObject, View, AVAudioPlayerDelegate {
    @ObservedObject var sessionManager = SessionManager()
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("VoiceLink")
                .font(.largeTitle)
                .foregroundColor(.red)
                .padding()
            
            Spacer()
            
            Image(systemName: isPlaying ? "speaker.wave.3.fill" : "speaker.wave.3")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .foregroundColor(.red)
                .onTapGesture {
                    if self.isPlaying {
                        self.stopPlaying()
                    } else if let data = self.sessionManager.receivedData {
                        self.startPlaying(data: data)
                    }
                }
            
            Text(isPlaying ? "Playing..." : "Tap to play")
                .font(.title2)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text("[© 2023 Siddharth Praveen Bharadwaj](https://sid110307.github.io/Sid110307)")
                .font(.footnote)
                .foregroundColor(.gray)
                .accentColor(.gray)
        }
        .onDisappear {
            self.stopPlaying()
        }
    }
    
    func startPlaying(data: Data) {
        do {
            let fileUrl = try FileManager.default
                .url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("voicelink.wav")
            
            try data.write(to: fileUrl)
            
            audioPlayer = try AVAudioPlayer(contentsOf: fileUrl)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to start playing audio: \(error.localizedDescription)")
        }
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        isPlaying = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        audioPlayer = nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

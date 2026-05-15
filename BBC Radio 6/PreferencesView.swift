import SwiftUI

struct PreferencesView: View {
    @ObservedObject var playerController: PlayerController
    @ObservedObject var lastFMService: LastFMService
    @AppStorage("showNowPlayingInMenuBar") private var showNowPlayingInMenuBar = true
    @AppStorage("leftClickToPause") private var leftClickToPause = true
    @State private var apiKey: String
    @State private var apiSecret: String
    @State private var isAuthenticating = false
    @State private var authError: String?

    init(playerController: PlayerController, lastFMService: LastFMService) {
        self.playerController = playerController
        self.lastFMService = lastFMService
        _apiKey = State(initialValue: lastFMService.apiKey)
        _apiSecret = State(initialValue: lastFMService.apiSecret)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Volume") {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                        Slider(value: $playerController.volume, in: 0...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    }
                }
                Toggle("Show now playing in menu bar", isOn: $showNowPlayingInMenuBar)
                Toggle("Left click to pause / play", isOn: $leftClickToPause)
            } header: {
                Label("Playback", systemImage: "headphones")
            }

            Section {
                LabeledContent("API Key") {
                    TextField("", text: $apiKey)
                        .onChange(of: apiKey) { lastFMService.apiKey = $0 }
                }
                LabeledContent("API Secret") {
                    SecureField("", text: $apiSecret)
                        .onChange(of: apiSecret) { lastFMService.apiSecret = $0 }
                }
            } header: {
                Label("Last.fm", systemImage: "music.note.list")
            } footer: {
                Text("Get an API key at last.fm/api/account/create")
                    .foregroundStyle(.secondary)
            }

            Section {
                if lastFMService.isConnected {
                    HStack {
                        Label("Connected as \(lastFMService.connectedUsername ?? "unknown")", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect", role: .destructive) {
                            lastFMService.disconnect()
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    HStack {
                        Button(isAuthenticating ? "Waiting for authorisation…" : "Connect Last.fm") {
                            startConnect()
                        }
                        .disabled(apiKey.isEmpty || apiSecret.isEmpty || isAuthenticating)

                        if isAuthenticating {
                            Spacer()
                            Button("I've authorised, complete setup") {
                                finishConnect()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                if let error = authError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 430)
    }

    private func startConnect() {
        authError = nil
        lastFMService.startAuth { result in
            switch result {
            case .success(let url):
                isAuthenticating = true
                NSWorkspace.shared.open(url)
            case .failure(let error):
                authError = error.localizedDescription
            }
        }
    }

    private func finishConnect() {
        lastFMService.completeAuth { result in
            isAuthenticating = false
            if case .failure(let error) = result {
                authError = error.localizedDescription
            }
        }
    }
}

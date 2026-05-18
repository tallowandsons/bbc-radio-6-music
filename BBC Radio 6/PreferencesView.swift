import SwiftUI
import AppKit

// MARK: - Pastable text field wrappers

private struct PastableTextField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}

private struct PastableSecureField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSSecureTextField {
        let field = NSSecureTextField()
        field.delegate = context.coordinator
        field.bezelStyle = .roundedBezel
        field.focusRingType = .none
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        return field
    }

    func updateNSView(_ nsView: NSSecureTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text = field.stringValue
        }
    }
}

// MARK: - Preferences view

struct PreferencesView: View {
    @ObservedObject var playerController: PlayerController
    @ObservedObject var lastFMService: LastFMService
    @AppStorage("showNowPlayingInMenuBar") private var showNowPlayingInMenuBar = true
    @AppStorage("leftClickToPause") private var leftClickToPause = true
    @AppStorage("lastfm_scrobbling_enabled") private var scrobblingEnabled = false
    @State private var apiKey: String
    @State private var apiSecret: String
    @State private var showSecret = false
    @State private var isAuthenticating = false
    @State private var authError: String?

    init(playerController: PlayerController, lastFMService: LastFMService) {
        self.playerController = playerController
        self.lastFMService = lastFMService
        _apiKey = State(initialValue: lastFMService.apiKey)
        _apiSecret = State(initialValue: lastFMService.apiSecret)
    }

    private var lastFMLogo: NSImage {
        if let url = Bundle.main.url(forResource: "lastfm", withExtension: "svg"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            return image
        }
        return NSImage(systemSymbolName: "music.note.list", accessibilityDescription: nil)!
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
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
                Toggle("Enable scrobbling", isOn: $scrobblingEnabled)
                LabeledContent("API Key") {
                    PastableTextField(text: $apiKey)
                        .onChange(of: apiKey) { lastFMService.apiKey = $0 }
                }
                LabeledContent("API Secret") {
                    HStack {
                        if showSecret {
                            PastableTextField(text: $apiSecret)
                                .onChange(of: apiSecret) { lastFMService.apiSecret = $0 }
                        } else {
                            PastableSecureField(text: $apiSecret)
                                .onChange(of: apiSecret) { lastFMService.apiSecret = $0 }
                        }
                        Button {
                            showSecret.toggle()
                        } label: {
                            Image(systemName: showSecret ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            } header: {
                Label {
                    Text("Last.fm")
                } icon: {
                    Image(nsImage: lastFMLogo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .offset(y: 1)
                }
            } footer: {
                HStack(spacing: 0) {
                    Text("Get an API key at ")
                        .foregroundColor(.secondary)
                    Link("last.fm/api/account/create",
                         destination: URL(string: "https://www.last.fm/api/account/create")!)
                        .foregroundColor(.secondary)
                        .underline()
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                        }
                }
                .font(.footnote)
            }

            Section {
                if lastFMService.isConnected {
                    HStack {
                        Label("Connected as \(lastFMService.connectedUsername ?? "unknown")", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect", role: .destructive) {
                            lastFMService.disconnect()
                            scrobblingEnabled = false
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

        Divider()

        HStack {
            Text("v\(appVersion)")
                .foregroundColor(.secondary)
                .font(.caption)
            Spacer()
            Link("View on GitHub",
                 destination: URL(string: "https://github.com/tallowandsons/bbc-radio-6-music")!)
                .foregroundColor(.secondary)
                .font(.caption)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)

        } // VStack
        .frame(minWidth: 480, minHeight: 480)
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

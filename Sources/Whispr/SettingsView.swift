import SwiftUI
import AVFoundation
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var modelManager: ModelManager

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }

            textProcessingTab
                .tabItem { Label("Text", systemImage: "textformat") }

            modelTab
                .tabItem { Label("Models", systemImage: "brain") }

            audioTab
                .tabItem { Label("Audio", systemImage: "mic") }
        }
        .frame(width: 500, height: 420)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Hotkey") {
                LabeledContent("Toggle Recording") {
                    Text("⌥ Space")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { newValue in
                        appState.launchAtLogin = newValue
                        LaunchAtLoginManager.setEnabled(newValue)
                    }
                ))
            }

            Section("Text Injection") {
                Toggle("Use clipboard paste (⌘V) instead of keystrokes", isOn: $appState.useClipboardFallback)
                Text("Enable this if text isn't appearing in some apps (e.g., secure text fields).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Text Processing

    private var textProcessingTab: some View {
        Form {
            Section("Post-Processing") {
                Toggle("Trim leading/trailing whitespace", isOn: $appState.trimWhitespace)
                Toggle("Auto-capitalize first letter of sentences", isOn: $appState.autoCapitalize)
                Toggle("Ensure sentences end with punctuation", isOn: $appState.ensurePunctuation)
            }

            Section {
                Text("These transformations are applied to transcribed text before it's typed into the target app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Models

    private var modelTab: some View {
        Form {
            Section("Whisper Model") {
                ForEach(WhisperModel.allCases) { model in
                    modelRow(model)
                }
            }

            if modelManager.isDownloading, let current = modelManager.currentDownload {
                Section("Downloading \(current.displayName)") {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: modelManager.downloadProgress)
                            .progressViewStyle(.linear)

                        HStack {
                            Text("\(Int(modelManager.downloadProgress * 100))%")
                                .font(.caption.monospacedDigit())
                            Spacer()
                            if modelManager.totalBytes > 0 {
                                Text("\(ModelManager.formatBytes(modelManager.bytesDownloaded)) / \(ModelManager.formatBytes(modelManager.totalBytes))")
                                    .font(.caption.monospacedDigit())
                            }
                        }
                        .foregroundStyle(.secondary)

                        Button("Cancel Download") {
                            modelManager.cancelDownload()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            if let error = modelManager.downloadError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func modelRow(_ model: WhisperModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.headline)
                    if appState.selectedModel == model {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                HStack(spacing: 8) {
                    Text(model.sizeLabel)
                    Text("•")
                    Text(model.speedLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if modelManager.isDownloaded(model) {
                if appState.selectedModel == model {
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    HStack(spacing: 8) {
                        Button("Select") {
                            appState.selectedModel = model
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button(role: .destructive) {
                            try? modelManager.delete(model)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } else {
                Button("Download") {
                    Task {
                        try? await modelManager.download(model)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(modelManager.isDownloading)
            }
        }
    }

    // MARK: - Audio

    private var audioTab: some View {
        Form {
            Section("Input Device") {
                AudioDevicePicker()
            }

            Section {
                Text("Whispr records at 16 kHz mono for optimal transcription quality. The selected input device is used system-wide by Whispr.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Audio Device Picker

struct AudioDevicePicker: View {
    @State private var devices: [AudioDeviceInfo] = []
    @State private var selectedDeviceID: AudioDeviceID = 0

    var body: some View {
        Picker("Microphone", selection: $selectedDeviceID) {
            Text("System Default").tag(AudioDeviceID(0))
            ForEach(devices, id: \.id) { device in
                Text(device.name).tag(device.id)
            }
        }
        .onAppear { refreshDevices() }
        .onChange(of: selectedDeviceID) { _, newValue in
            // For now we use the system default via AVAudioEngine.
            // A future version could set the preferred input device.
            UserDefaults.standard.set(Int(newValue), forKey: "preferredAudioDeviceID")
        }
    }

    private func refreshDevices() {
        devices = AudioDeviceInfo.availableInputDevices()
        selectedDeviceID = AudioDeviceID(UserDefaults.standard.integer(forKey: "preferredAudioDeviceID"))
    }
}

/// Simple representation of a Core Audio input device.
struct AudioDeviceInfo: Identifiable {
    let id: AudioDeviceID
    let name: String

    static func availableInputDevices() -> [AudioDeviceInfo] {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &propertySize
        ) == noErr else { return [] }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &propertySize,
            &deviceIDs
        ) == noErr else { return [] }

        return deviceIDs.compactMap { deviceID -> AudioDeviceInfo? in
            // Check if device has input channels
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )

            var size: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &size) == noErr,
                  size > 0 else { return nil }

            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferListPointer.deallocate() }

            guard AudioObjectGetPropertyData(deviceID, &inputAddress, 0, nil, &size, bufferListPointer) == noErr else {
                return nil
            }

            let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            let inputChannels = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard inputChannels > 0 else { return nil }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )

            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
            var unmanagedName: Unmanaged<CFString>?
            guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &unmanagedName) == noErr,
                  let cfName = unmanagedName?.takeUnretainedValue() else {
                return nil
            }

            return AudioDeviceInfo(id: deviceID, name: cfName as String)
        }
    }
}

// MARK: - Launch at Login

enum LaunchAtLoginManager {
    static func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login error: \(error)")
            }
        }
    }

    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }
}

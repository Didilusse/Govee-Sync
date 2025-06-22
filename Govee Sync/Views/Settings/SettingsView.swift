import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .padding([.top, .horizontal], 20)
                .padding(.bottom, 10)
            
            Divider()
                .padding(.horizontal, 20)
            
            Form {
                
                Section {
                    ToggleRow(
                        title: "Turn On on Connect",
                        icon: "power.circle.fill",
                        isOn: $appSettings.powerOnConnect
                    )

                    ToggleRow(
                        title: "Turn Off on Disconnect",
                        icon: "bolt.slash.fill",
                        isOn: $appSettings.powerOffDisconnect
                    )
                } header: {
                    SectionHeader("Automation")
                }
                
                Section {
                    StepperRow(
                        title: "Capture FPS",
                        icon: "speedometer",
                        value: $appSettings.captureFPS,
                        range: 1...30,
                        format: "\(appSettings.captureFPS)"
                    )
                    
                    StepperRow(
                        title: "Capture Width",
                        icon: "arrow.left.and.right",
                        value: $appSettings.captureWidth,
                        range: 16...256,
                        step: 8,
                        format: "\(appSettings.captureWidth) px"
                    )
                    
                    StepperRow(
                        title: "Capture Height",
                        icon: "arrow.up.and.down",
                        value: $appSettings.captureHeight,
                        range: 9...144,
                        step: 8,
                        format: "\(appSettings.captureHeight) px"
                    )
                } header: {
                    SectionHeader("Screen Sync Settings")
                } footer: {
                    Text("Lower resolution and FPS may improve performance on older machines. Changes will apply the next time you start Screen Sync.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
            .formStyle(.grouped)
        }
        .frame(minWidth: 450, minHeight: 500)
    }
}

// MARK: - Reusable Components
struct SectionHeader: View {
    let title: String
    
    init(_ title: String) {
        self.title = title
    }
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.secondary)
            .padding(.top, 8)
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon)
                .padding(.vertical, 6)
        }
        .toggleStyle(.switch)
    }
}

struct StepperRow: View {
    let title: String
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let format: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .frame(width: 150, alignment: .leading)
            
            Spacer()
            
            Text(format)
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
                .frame(width: 80, alignment: .trailing)
            
            Stepper(value: $value, in: range, step: step) {
                Text(title)
            }
            .labelsHidden()
            .tint(Color.accentColor)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Preview
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let settings = AppSettings()
        SettingsView()
            .environmentObject(settings)
            .frame(width: 500, height: 600)
    }
}

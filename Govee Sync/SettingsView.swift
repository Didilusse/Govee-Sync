//
//  SettingsView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appSettings: AppSettings
    
    var body: some View {
        Form {
            Section(header: Text("Automation")) {
                Toggle(isOn: $appSettings.powerOnConnect) {
                    Label("Turn On on Connect", systemImage: "power.circle.fill")
                }
                
                Toggle(isOn: $appSettings.powerOffDisconnect) {
                    Label("Turn Off on Disconnect", systemImage: "power.slash")
                }
            }
            
            Section(
                header: Text("Screen Sync Settings"),
                footer:
                    Text("Lower resolution and FPS may improve performance on older machines. Changes will apply the next time you start Screen Sync.")
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
            ) {
                
                HStack {
                    Label("Capture FPS", systemImage: "speedometer")
                    Spacer()
                    Text("\(appSettings.captureFPS)")
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                    Stepper("", value: $appSettings.captureFPS, in: 1...30)
                        .labelsHidden()
                }
                
                HStack {
                    Label("Capture Width", systemImage: "arrow.left.and.right")
                    Spacer()
                    Text("\(appSettings.captureWidth) px")
                        .foregroundColor(.secondary)
                        .frame(width: 55, alignment: .trailing)
                    Stepper("", value: $appSettings.captureWidth, in: 16...256, step: 8)
                        .labelsHidden()
                }
                
                HStack {
                    Label("Capture Height", systemImage: "arrow.up.and.down")
                    Spacer()
                    Text("\(appSettings.captureHeight) px")
                        .foregroundColor(.secondary)
                        .frame(width: 55, alignment: .trailing)
                    Stepper("", value: $appSettings.captureHeight, in: 9...144, step: 8)
                        .labelsHidden()
                }
            }
        }
        .padding(20)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppSettings())
    }
}

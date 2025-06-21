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
            Section(header: Text("Screen Sync Settings"),
                    footer: Text("Lower resolution and FPS may improve performance on older machines. Changes will apply the next time you start Screen Sync.")) {
                
                // Stepper for Capture FPS
                Stepper(value: $appSettings.captureFPS, in: 1...30) {
                    HStack {
                        Label("Capture FPS", systemImage: "speedometer")
                        Spacer()
                        Text("\(appSettings.captureFPS)").foregroundColor(.secondary)
                    }
                }
                
                // Stepper for Capture Width
                Stepper(value: $appSettings.captureWidth, in: 16...256, step: 8) {
                    HStack {
                        Label("Capture Width", systemImage: "arrow.left.and.right")
                        Spacer()
                        Text("\(appSettings.captureWidth) px").foregroundColor(.secondary)
                    }
                }
                
                // Stepper for Capture Height
                Stepper(value: $appSettings.captureHeight, in: 9...144, step: 8) {
                    HStack {
                        Label("Capture Height", systemImage: "arrow.up.and.down")
                        Spacer()
                        Text("\(appSettings.captureHeight) px").foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppSettings())
    }
}

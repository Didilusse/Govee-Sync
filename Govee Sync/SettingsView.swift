//
//  SettingsView.swift
//  Govee Sync
//
//  Created by Adil Rahmani on 6/21/25.
//


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
        // The Form itself should not have extra padding; it manages its own insets.
        Form {
            Section(
                header: Text("Screen Sync Settings"),
                footer:
                    Text("Lower resolution and FPS may improve performance on older machines. Changes will apply the next time you start Screen Sync.")
                        // This modifier is crucial. It tells the text view to take up all the vertical
                        // space it needs, preventing it from being horizontally compressed by the Form.
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5) // Add a little space between the controls and footer.
            ) {
                
                // We now define each row with its own HStack for precise layout control.
                HStack {
                    Label("Capture FPS", systemImage: "speedometer")
                    Spacer()
                    Text("\(appSettings.captureFPS)")
                        .foregroundColor(.secondary)
                        .frame(width: 35, alignment: .trailing)
                    // The Stepper's own label is hidden, as we've created one manually.
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
        // Apply padding to the content *within* the Form, not the Form itself.
        .padding(20)
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppSettings())
    }
}

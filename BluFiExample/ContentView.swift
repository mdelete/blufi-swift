//
//  ContentView.swift
//  BluFiExample
//
//  Created by Marc Delling on 24.12.19.
//  Copyright © 2019 Marc Delling. All rights reserved.
//

import SwiftUI
import BluFi

struct ContentView: View {
    var body: some View {
        VStack {
            Button(action: {
                print("Custom tapped!")
                let data = "NOOB".data(using: .ascii)!
                BluFiManager.shared.writeCustomData(data)
            }) {
                Text("Custom Data")
                .fontWeight(.semibold)
                .font(.title)
                .padding()
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(40)
            }
            Button(action: {
                print("Wifi tapped!")
                BluFiManager.shared.triggerWifiList()
            }) {
                Text("Wifi-List")
                .fontWeight(.semibold)
                .font(.title)
                .padding()
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(40)
            }
            Button(action: {
                print("Status tapped!")
                BluFiManager.shared.triggerDeviceInfo()
            }) {
                Text("Status")
                .fontWeight(.semibold)
                .font(.title)
                .padding()
                .foregroundColor(.white)
                .background(Color.red)
                .cornerRadius(40)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

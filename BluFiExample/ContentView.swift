//
//  ContentView.swift
//  BluFiExample
//
//  Created by Marc Delling on 24.12.19.
//  Copyright © 2019 Marc Delling. All rights reserved.
//

import SwiftUI
import BluFi
import Combine

struct ModalView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var wifi: Wifi
    
    var body: some View {
        NavigationView() {
            List(wifi.list) { wifi in
                HStack {
                    Text("\(wifi.rssi)")
                        .frame(width: 50, height: 30, alignment: .leading)
                    VStack {
                        Text(wifi.id)
                    }
                }.font(.title)
            }.navigationBarTitle(Text("Networks"))
                .navigationBarItems(trailing:
                    Button("Dismiss") {
                        self.presentationMode.wrappedValue.dismiss()
                    }
            )
        }
    }
}

struct Wifi : Identifiable {
    let id = UUID()
    struct List : Identifiable {
        let id : String
        let rssi : Int8
    }
    let current : String? = nil
    let list : [List]
}

struct ContentView: View {
    
    @State private var wifiList: Wifi? = nil
    
    var body: some View {
        ZStack {
            SomeDelegateObserver { list in
                self.wifiList = list
            }
            VStack(alignment: .center, spacing: 15) {
                
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
                        .background(Color("Orange"))
                        .cornerRadius(40)
                }.sheet(item: self.$wifiList, onDismiss: {
                    print("dismissed")
                }) { list in
                    ModalView(wifi: .constant(list)) // FIXME: this seems wrong
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
                        .background(Color("Orange"))
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
                        .background(Color("Orange"))
                        .cornerRadius(40)
                }
            }
        }
    }
}

struct SomeDelegateObserver: UIViewControllerRepresentable {
    let vc = UIViewController()
    var foo: (Wifi) -> Void
    func makeUIViewController(context: Context) -> UIViewController {
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
    func makeCoordinator() -> Coordinator {
        Coordinator(vc: vc, foo: foo)
    }
    
    class Coordinator: NSObject, BluFiManagerDelegate {
        var foo: (Wifi) -> Void
        init(vc: UIViewController, foo: @escaping (Wifi) -> Void) {
            self.foo = foo
            super.init()
            BluFiManager.shared.delegate = self
        }
        
        func didStopScanning(_ manager: BluFiManager) {
            print("didStopScanning")
        }
        
        func didConnect(_ manager: BluFiManager) {
            print("didConnect")
        }
        
        func didDisconnect(_ manager: BluFiManager) {
            print("didDisconnect")
        }
        
        func didUpdate(_ manager: BluFiManager, status: String?) {
            print("didUpdate: \(status ?? "n/a")")
        }
        
        func didReceive(_ manager: BluFiManager, wifi: [BluFiWifi]) {
            print("Wifi: \(wifi)")
            foo(Wifi(list: wifi.map {
                Wifi.List(id: $0.ssid, rssi: $0.rssi)
            }))
        }
        
        func didReceive(_ manager: BluFiManager, error: BluFiError) {
            print("Error: \(error)")
        }
        
        func didReceive(_ manager: BluFiManager, deviceInfo: BluFiDeviceInfo) {
            print("Device: \(deviceInfo)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct ModalView_Previews: PreviewProvider {
    static var previews: some View {
        ModalView(wifi: .constant(Wifi(list: [Wifi.List(id: "MyNet", rssi: -42)])))
    }
}

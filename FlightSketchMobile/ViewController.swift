//
//  ViewController.swift
//  FlightSketchMobile
//
//  Created by Russell P. Parrish on 5/18/18.
//  Copyright © 2018 Russell P. Parrish. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var lbRSSI: UILabel!
    @IBOutlet weak var devTable: UITableView!
    var btItems = [(peripheral: CBPeripheral,  lastUpdate: Date?, RSSI: NSNumber)]()
    var centralManager: CBCentralManager!
    var txChar: CBCharacteristic!
    var altPeripheral: CBPeripheral!
    let service_ID = CBUUID(string: "49535343-fe7d-4ae5-8fa9-9fafd205e455")
    
    var devTimer: Timer!
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return btItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = devTable.dequeueReusableCell(withIdentifier: "devID")!
        var text = "name"
        if (btItems[indexPath.row].peripheral.name != nil) {
            text = btItems[indexPath.row].peripheral.name!
            text = text + ",         RSSI:"
            text = text + btItems[indexPath.row].RSSI.stringValue
        }
        else {
            text = "no name"
        }
        cell.textLabel?.text = text
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        print("selected...")
        btItems[indexPath.row].peripheral.delegate = self
        altPeripheral = btItems[indexPath.row].peripheral
        centralManager.connect(btItems[indexPath.row].peripheral, options: nil)
        
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        devTable.dataSource = self
        devTable.delegate = self
        centralManager = CBCentralManager(delegate: self, queue: nil)
        devTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateDevTable), userInfo: nil, repeats: true)

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    @objc func updateDevTable() {
        for i in (0..<btItems.count).reversed() {
            if btItems[i].lastUpdate!.timeIntervalSinceNow < -5.0 { // 2s max inactivity
                btItems.remove(at: i)
                devTable.reloadData()
            }
        }
    }
    
    func parseData(byte: Data) {
        print("data rx...")
    }
    
    

}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            
        case .unknown:
            NSLog("unknown")
        case .resetting:
            NSLog("resetting")
        case .unsupported:
            NSLog("unsupported")
        case .unauthorized:
            NSLog("unauthorized")
        case .poweredOff:
            NSLog("powered off")
        case .poweredOn:
            NSLog("powered on")
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if let i = btItems.index(where: ({ $0.peripheral === peripheral })) {
            btItems[i].RSSI = RSSI
            btItems[i].lastUpdate = Date()
            devTable.reloadData()
        }
        else {
            btItems.append((peripheral, Date(), RSSI))
            btItems.sort { ($0.RSSI.floatValue ) > ($1.RSSI.floatValue ) } // optionally sort array to signal strength
            devTable.reloadData()
        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        altPeripheral.discoverServices([service_ID])
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        print(RSSI)
        lbRSSI.text = RSSI.stringValue
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
            print("service found...")
            print(service.uuid)
            print("end service...")
            
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print(characteristic)
            if characteristic.properties.contains(.read) {
                print("\(characteristic.uuid): properties contains .read")
            }
            if characteristic.properties.contains(.notify) {
                print("\(characteristic.uuid): properties contains .notify")
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.writeWithoutResponse) {
                print("\(characteristic.uuid): properties contains .read")
                txChar = characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        switch characteristic.uuid {
            
        default:
            //print("Unhandled Characteristic UUID: \(characteristic.uuid)")
            readData(from: characteristic)
        }
    }
    
    private func readData(from characteristic: CBCharacteristic) {
        altPeripheral.readRSSI()
        parseData(byte: characteristic.value!)
        
    }
    
    
    
    
}


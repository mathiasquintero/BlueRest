//
//  ViewController.swift
//  BlueRest
//
//  Created by mathiasquintero on 06/12/2017.
//  Copyright (c) 2017 mathiasquintero. All rights reserved.
//

import UIKit
import CoreBluetooth
import BlueRest

class ViewController: UIViewController {
    
    let uuid = CBUUID(string: "")
    
    var server: RESTBLEServer!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func serve(_ sender: Any) {
        server = RESTBLEServer.init(uuid: uuid) { (message, response) in
            response.respond(with: "Hello World")
        }
        server.start()
    }
    
    @IBAction func fetch(_ sender: Any) {
        fetch(uuid: uuid, resource: "hello") { message in
            guard let response: String = message.decode() else {
                return
            }
            print(response)
        }
    }
    
    
}


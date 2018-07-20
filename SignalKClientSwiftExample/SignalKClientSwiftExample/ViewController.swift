//
//  ViewController.swift
//  SignalKClientSwiftExample
//
//  Created by Scott Bender on 7/20/18.
//  Copyright © 2018 Scott Bender. All rights reserved.
//

import UIKit

import SignalKClient

class ViewController: UIViewController, SignalKDelegate, BrowseTableViewControllerDelegate
{
  @IBOutlet weak var host: UITextField!
  @IBOutlet weak var port: UITextField!
  @IBOutlet weak var isSSL: UISwitch!
  @IBOutlet weak var windSpeed: UILabel!
  @IBOutlet weak var windAngle: AngleView!
  
  var signalk: SignalK?

  override func viewDidLoad()
  {
    super.viewDidLoad()
  }
  
  override func didReceiveMemoryWarning()
  {
    super.didReceiveMemoryWarning()
  }
  
  func browseTableViewControllerDidSelectHost(host: String, port: Int, isSecure: Bool)
  {
    self.host.text = host
    self.port.text = String(port)
    self.isSSL.isOn = isSecure
    self.navigationController?.popViewController(animated: true);
  }
  
  @IBAction func connect(_ sender: Any)
  {
    if (( self.signalk ) != nil)
    {
      self.signalk?.close()
    }
    
    self.signalk = SignalK.init(host: self.host.text, port: Int(self.port.text!)!)
    self.signalk?.delegate = self
    self.signalk?.subscription = "none"
    self.signalk?.ssl = self.isSSL.isOn
    
    self.signalk?.registerSKDelegate(self.windAngle, forPath: "environment.wind.angleApparent")
    
    self.signalk?.connect(completionHandler: { (error) in
      if ( error != nil )
      {
        DispatchQueue.main.async {
            self.showMessage(message: (error?.localizedDescription)!, title: "Error Connecting")
        }
      }
    })
  }
  
  func showMessage( message: String, title: String )
  {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    self.present(alert, animated: true)
  }
  
  func signalK(_ signalk: SignalK!, webSocketFailed reason: String!) {
    DispatchQueue.main.async {
      self.showMessage(message: reason, title: "Streaming Error")
    }
  }
  
  func signalK(_ signalK: SignalK!, didReceivePath path: String!, andValue value: Any!, forContext context: String!) {
    if ( path == "environment.wind.speedApparent" )
    {
      let n = value as? NSNumber
      DispatchQueue.main.async {
        self.windSpeed.text = String(format: "%0.2f m/s", (n?.floatValue)!)
      }
    }
  }
  
  func signalKWebSocketDidOpen(_ signalk: SignalK!) {
    let subscription = [ "context": "vessels.self",
                         "subscribe": [
                          [
                            "path": "environment.wind.speedApparent",
                            "period": 1000,
                            ],
                          [
                            "path": "environment.wind.angleApparent",
                            "period": 1000,
                          ]
      ]
      ] as [String : Any]
    
    self.signalk?.sendSubscription(subscription)
  }
  
  func signalK(_ signalk: SignalK!, untrustedServer host: String!, withCompletionHandler completionHandler: ((Bool) -> Void)? = nil) {
    completionHandler?(true)
  }
  
  override func viewWillAppear(_ animated: Bool)
  {
    self.signalk?.startStreaming()
  }
  
  override func viewWillDisappear(_ animated: Bool)
  {
    self.signalk?.stopStreaming()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?)
  {
    let tc = segue.destination as! BrowseTableViewController
    tc.delegate = self
  }

}


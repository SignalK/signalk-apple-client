//
//  AngleView.swift
//  SignalKClientSwiftExample
//
//  Created by Scott Bender on 7/20/18.
//  Copyright © 2018 Scott Bender. All rights reserved.
//

import UIKit
import SignalKClient

class AngleView: UILabel, SignalKPathValueDelegate
{
  
  func signalK(_ signalK: SignalK!, didReceivePath path: String!, andValue value: Any!, forContext context: String!)
  {
    let n = value as! NSNumber
    let factor = 360.0/(2.0 * Double.pi) as Double
    DispatchQueue.main.async {
      self.text = String(format: "%0.0f°", n.doubleValue * factor)
    }
  }

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}

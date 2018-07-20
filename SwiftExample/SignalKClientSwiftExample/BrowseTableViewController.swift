//
//  BrowseTableViewController.swift
//  SignalKClientSwiftExample
//
//  Created by Scott Bender on 7/20/18.
//  Copyright © 2018 Scott Bender. All rights reserved.
//

import UIKit
import SignalKClient

protocol BrowseTableViewControllerDelegate: AnyObject
{
  func browseTableViewControllerDidSelectHost(host: String, port: Int, isSecure: Bool)
}

class BrowseTableViewController: UITableViewController, SignalKBrowserDelegate
{
  weak var delegate: BrowseTableViewControllerDelegate?
  var browser: SignalKBrowser
  var vesselServices: Dictionary<String, [VesselService]>?
  var vesselNames: Array<String>?
  
  required init?(coder aDecoder: NSCoder)
  {
    self.browser = SignalKBrowser.init()
    super.init(coder: aDecoder)
    self.browser.add(self)
  }
  
  override func viewDidLoad()
  {
    super.viewDidLoad()
  }
  
  func availableServicesChanged(_ browser: SignalKBrowser!)
  {
    self.vesselServices = self.browser.getServicesByName()
    self.vesselNames = self.vesselServices?.keys.sorted()
    self.tableView.reloadData()
  }

  override func didReceiveMemoryWarning()
  {
    super.didReceiveMemoryWarning()
  }

    // MARK: - Table view data source

  override func numberOfSections(in tableView: UITableView) -> Int
  {
    return 1
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
  {
    return self.vesselNames != nil ? (self.vesselNames?.count)! : 0
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
  {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

    let label = cell.viewWithTag(100) as! UILabel
    label.text = self.vesselNames?[indexPath.row]
    
    return cell
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
  {
    let services = self.vesselServices?[(self.vesselNames?[indexPath.row])!]
    if let best = self.browser.getBestService(services)
    {
      self.delegate?.browseTableViewControllerDidSelectHost(host: (best.service.hostName)!, port: best.service.port, isSecure: (best.isSecure))
    }
  }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

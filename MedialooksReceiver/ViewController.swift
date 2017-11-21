//
//  ViewController.swift
//  MedialooksReceiver
//
//  Created by admin on 11/8/17.
//  Copyright © 2017 admin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var accessLikeTextInput: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func startBtn(_ sender: Any) {
        let accessLink: String = self.accessLikeTextInput.text!
        let tmp = accessLink.split(separator: "/")
        print(tmp.count)
        if (tmp.count < 4) {
            let alertController = UIAlertController(title: "Notice", message: "Please enter the valid access link.", preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alertController, animated: true, completion: nil)
            return
        }
        let access_url = tmp[1]
        let access_room = tmp[2]
        let access_id = tmp[3]
        
//        print(access_url, access_room, access_id)
        
        let streamVC = self.storyboard?.instantiateViewController(withIdentifier: "streamVC") as!StreamViewController
        streamVC.accessURL = String("https://" + access_url)
        streamVC.accessRoom = String(access_room)
        streamVC.accessID = String(access_id)
        self.present(streamVC, animated: true, completion: nil)
    }
    
}


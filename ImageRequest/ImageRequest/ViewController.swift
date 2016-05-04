//
//  ViewController.swift
//  ImageRequest
//
//  Created by Jarrod Parkes on 11/3/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {

    // MARK: Outlets
    
    @IBOutlet weak var imageView: UIImageView!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let imageURL = NSURL(string: "https://upload.wikimedia.org/wikipedia/commons/4/4d/Cat_November_2010-1a.jpg") else {
            return
        }
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(imageURL) {
            data, response, error in
            guard let data = data else {
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                self.imageView.image = UIImage(data: data)
            }
        }
        
        task.resume()
    }
}

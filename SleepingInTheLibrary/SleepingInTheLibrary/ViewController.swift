//
//  ViewController.swift
//  SleepingInTheLibrary
//
//  Created by Jarrod Parkes on 11/3/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {

    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var grabImageButton: UIButton!
    
    // MARK: Actions
    
    @IBAction func grabNewImage(sender: AnyObject) {
        setUIEnabled(false)
        getImageFromFlickr()
    }
    
    // MARK: Configure UI
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        grabImageButton.enabled = enabled
        
        if enabled {
            grabImageButton.alpha = 1.0
        } else {
            grabImageButton.alpha = 0.5
        }
    }
    
    // MARK: Make Network Request
    
    private func showNetworkError(message: String) {
        let alertController = UIAlertController(title: "Error!", message: message, preferredStyle: .Alert)
        let okayAction = UIAlertAction(title: "Okay", style: .Default) {
            action in
            self.setUIEnabled(true)
        }
        
        alertController.addAction(okayAction)
        
        dispatch_async(dispatch_get_main_queue()) {
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    private func getImageFromFlickr() {
        let methodParameters = [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.GalleryPhotosMethod,
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.GalleryID: Constants.FlickrParameterValues.GalleryID,
            Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
        ]
        
        let urlString = Constants.Flickr.APIBaseURL + escapeParameters(methodParameters)
        let url = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
            data, response, error in
            
            guard let data = data else {
                return
            }
            
            guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
                return
            }
            
            var parsedResult: AnyObject
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch {
                self.showNetworkError("Can't parse json data")
                return
            }
            
            guard let photosDict = (parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject]) else {
                self.showNetworkError("Can't get photos dict")
                return
            }
            
            guard let photoArr = photosDict[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]] else {
                self.showNetworkError("Can't get photo array")
                return
            }
            
            guard !photoArr.isEmpty else {
                self.showNetworkError("Photo array empty")
                return
            }
            
            let randomIndex = Int(arc4random_uniform(UInt32(photoArr.count)))
            let randomPhoto = photoArr[randomIndex]
            
            guard let imageUrlString = randomPhoto[Constants.FlickrResponseKeys.MediumURL] as? String,
                title = randomPhoto[Constants.FlickrResponseKeys.Title] as? String else {
                self.showNetworkError("Can't get required data (e.g. image url, title)")
                return
            }
            
            guard let imageUrl = NSURL(string: imageUrlString) else {
                self.showNetworkError("Invalid image url")
                return
            }
            
            guard let imageData = NSData(contentsOfURL: imageUrl) else {
                self.showNetworkError("Can't retrieve image data")
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                self.photoImageView.image = UIImage(data: imageData)
                self.photoTitleLabel.text = title
                self.setUIEnabled(true)
            }
        }
        
        task.resume()
    }
    
    private func escapeParameters(parameters: [String: AnyObject]) -> String {
        guard !parameters.isEmpty else {
            return ""
        }
        
        var keyValuePairs = [String]()
        
        for (key, value) in parameters {
            let stringValue = "\(value)"
            
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            keyValuePairs.append("\(key)=\(escapedValue!)")
        }
        
        return "?\(keyValuePairs.joinWithSeparator("&"))"
    }
}
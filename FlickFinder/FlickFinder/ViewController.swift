//
//  ViewController.swift
//  FlickFinder
//
//  Created by Jarrod Parkes on 11/5/15.
//  Copyright © 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - ViewController: UIViewController

class ViewController: UIViewController {
    
    // MARK: Properties
    
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var phraseTextField: UITextField!
    @IBOutlet weak var phraseSearchButton: UIButton!
    @IBOutlet weak var latitudeTextField: UITextField!
    @IBOutlet weak var longitudeTextField: UITextField!
    @IBOutlet weak var latLonSearchButton: UIButton!
    
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        phraseTextField.delegate = self
        latitudeTextField.delegate = self
        longitudeTextField.delegate = self
        // FIX: As of Swift 2.2, using strings for selectors has been deprecated. Instead, #selector(methodName) should be used.
        subscribeToNotification(UIKeyboardWillShowNotification, selector: #selector(keyboardWillShow))
        subscribeToNotification(UIKeyboardWillHideNotification, selector: #selector(keyboardWillHide))
        subscribeToNotification(UIKeyboardDidShowNotification, selector: #selector(keyboardDidShow))
        subscribeToNotification(UIKeyboardDidHideNotification, selector: #selector(keyboardDidHide))
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Search Actions
    
    @IBAction func searchByPhrase(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if !phraseTextField.text!.isEmpty {
            photoTitleLabel.text = "Searching..."
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.Text: phraseTextField.text!,
                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ]
            displayImageFromFlickrBySearch(methodParameters)
        } else {
            setUIEnabled(true)
            photoTitleLabel.text = "Phrase Empty."
        }
    }
    
    @IBAction func searchByLatLon(sender: AnyObject) {

        userDidTapView(self)
        setUIEnabled(false)
        
        if isTextFieldValid(latitudeTextField, forRange: Constants.Flickr.SearchLatRange) && isTextFieldValid(longitudeTextField, forRange: Constants.Flickr.SearchLonRange) {
            photoTitleLabel.text = "Searching..."
            let methodParameters: [String: String!] = [
                Constants.FlickrParameterKeys.SafeSearch: Constants.FlickrParameterValues.UseSafeSearch,
                Constants.FlickrParameterKeys.BoundingBox: bboxString(),
                Constants.FlickrParameterKeys.Extras: Constants.FlickrParameterValues.MediumURL,
                Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
                Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.SearchMethod,
                Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
                Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
            ]
            displayImageFromFlickrBySearch(methodParameters)
        }
        else {
            setUIEnabled(true)
            photoTitleLabel.text = "Lat should be [-90, 90].\nLon should be [-180, 180]."
        }
    }
    
    private func bboxString() -> String {
        guard let longitude = Double(longitudeTextField.text!), latitude = Double(latitudeTextField.text!) else {
            return "0,0,0,0"
        }
        
        let minLongitude = max((longitude - Constants.Flickr.SearchBBoxHalfWidth), Constants.Flickr.SearchLonRange.0)
        let maxLongitude = min((longitude + Constants.Flickr.SearchBBoxHalfWidth), Constants.Flickr.SearchLonRange.1)
        let minLatitude = max((latitude - Constants.Flickr.SearchBBoxHalfHeight), Constants.Flickr.SearchLatRange.0)
        let maxLatitude = min((latitude + Constants.Flickr.SearchBBoxHalfHeight), Constants.Flickr.SearchLatRange.1)
        
        return "\(minLongitude),\(minLatitude),\(maxLongitude),\(maxLatitude)"
    }
    
    // MARK: Flickr API
    
    private func displayImageFromFlickrBySearch(methodParameters: [String:AnyObject]) {
        // make a request to get random page from result
        let pageRequestUrl = flickrURLFromParameters(methodParameters)
        let pageRequest = NSURLRequest(URL: pageRequestUrl)
        
        let pageRequestTask = NSURLSession.sharedSession().dataTaskWithRequest(pageRequest) {
            data, response, error in
            
            guard let parsedResult = self.getParsedResult(data, response: response, error: error),
                randomResultPageNumber = self.getRandomResultPageNumber(parsedResult) else {
                return
            }
            
            // make a second request to get specified page
            let imageRequestTask = self.makeRequestToGetImage(methodParameters, randomResultPageNumber: randomResultPageNumber)
            imageRequestTask.resume()
        }
        pageRequestTask.resume()
    }
    
    func makeRequestToGetImage(methodParameters: [String: AnyObject], randomResultPageNumber: Int) -> NSURLSessionDataTask {
        var imageRequestParams = methodParameters
        imageRequestParams[Constants.FlickrParameterKeys.Page] = randomResultPageNumber
        
        let imageRequestURL = self.flickrURLFromParameters(imageRequestParams)
        let imageRequest = NSURLRequest(URL: imageRequestURL)
        
        let imageRequestTask = NSURLSession.sharedSession().dataTaskWithRequest(imageRequest) {
            data, response, error in
            
            guard let parsedResult = self.getParsedResult(data, response: response, error: error) else {
                return
            }
            
            guard let randomPhoto = self.getRandomPhoto(parsedResult) else {
                return
            }
            
            guard let (image, photoTitle) = self.parsePhotoDic(randomPhoto) else {
                return
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                self.photoImageView.image = image
                self.photoTitleLabel.text = photoTitle
                self.setUIEnabled(true)
            }
        }
        
        return imageRequestTask
    }
    
    func getRandomResultPageNumber(parsedResult: AnyObject) -> Int? {
        guard let photosDict = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject],
            pagesCount = photosDict[Constants.FlickrResponseKeys.Pages] as? Int else {
                self.displayError("Can't find pages count!")
                return nil
        }

        return Int(arc4random_uniform(UInt32(min(pagesCount, 40)))) + 1
    }
    
    func getRandomPhoto(parsedResult: AnyObject) -> [String: AnyObject]? {
        guard let photosDict = parsedResult[Constants.FlickrResponseKeys.Photos] as? [String: AnyObject],
            photoArr = photosDict[Constants.FlickrResponseKeys.Photo] as? [[String: AnyObject]]
            where !photoArr.isEmpty else {
                self.displayError("Can't get photos array!")
                return nil
        }
        
        let randomIndex = Int(arc4random_uniform(UInt32(photoArr.count)))
        return photoArr[randomIndex]
    }
    
    func parsePhotoDic(randomPhoto: [String: AnyObject]) -> (image: UIImage, title: String)? {
        guard let imageUrlString = randomPhoto[Constants.FlickrResponseKeys.MediumURL] as? String,
            imageURL = NSURL(string: imageUrlString),
            photoTitle = randomPhoto[Constants.FlickrResponseKeys.Title] as? String else {
                self.displayError("Can't get image url or title!")
                return nil
        }
        
        guard let imageData = NSData(contentsOfURL: imageURL), image = UIImage(data: imageData) else {
            self.displayError("Can't retrieve image!")
            return nil
        }
        
        return (image, photoTitle)
    }
    
    func getParsedResult(data: NSData?, response: NSURLResponse?, error: NSError?) -> AnyObject? {
        guard error == nil else {
            self.displayError("Unknown error occured!")
            return nil
        }
        
        guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
            self.displayError("Bad response!")
            return nil
        }
        
        guard let data = data else {
            self.displayError("No data received!")
            return nil
        }
        
        let parsedResult: AnyObject
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
        } catch {
            self.displayError("Can't parse json data!")
            return nil
        }
        
        return parsedResult
    }
    
    func displayError(message: String) {
        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .Alert)
        let okayAction = UIAlertAction(title: "Okay", style: .Default) {
            action in
            self.setUIEnabled(true)
        }
        alertController.addAction(okayAction)
        
        dispatch_async(dispatch_get_main_queue()) {
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    // MARK: Helper for Creating a URL from Parameters
    
    private func flickrURLFromParameters(parameters: [String:AnyObject]) -> NSURL {
        
        let components = NSURLComponents()
        components.scheme = Constants.Flickr.APIScheme
        components.host = Constants.Flickr.APIHost
        components.path = Constants.Flickr.APIPath
        components.queryItems = [NSURLQueryItem]()
        
        for (key, value) in parameters {
            let queryItem = NSURLQueryItem(name: key, value: "\(value)")
            components.queryItems!.append(queryItem)
        }
        
        return components.URL!
    }
}

// MARK: - ViewController: UITextFieldDelegate

extension ViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
        }
    }
    
    func keyboardDidShow(notification: NSNotification) {
        keyboardOnScreen = true
    }
    
    func keyboardDidHide(notification: NSNotification) {
        keyboardOnScreen = false
    }
    
    private func keyboardHeight(notification: NSNotification) -> CGFloat {
        let userInfo = notification.userInfo
        let keyboardSize = userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue
        return keyboardSize.CGRectValue().height
    }
    
    private func resignIfFirstResponder(textField: UITextField) {
        if textField.isFirstResponder() {
            textField.resignFirstResponder()
        }
    }
    
    @IBAction func userDidTapView(sender: AnyObject) {
        resignIfFirstResponder(phraseTextField)
        resignIfFirstResponder(latitudeTextField)
        resignIfFirstResponder(longitudeTextField)
    }
    
    // MARK: TextField Validation
    
    private func isTextFieldValid(textField: UITextField, forRange: (Double, Double)) -> Bool {
        if let value = Double(textField.text!) where !textField.text!.isEmpty {
            return isValueInRange(value, min: forRange.0, max: forRange.1)
        } else {
            return false
        }
    }
    
    private func isValueInRange(value: Double, min: Double, max: Double) -> Bool {
        return !(value < min || value > max)
    }
}

// MARK: - ViewController (Configure UI)

extension ViewController {
    
    private func setUIEnabled(enabled: Bool) {
        photoTitleLabel.enabled = enabled
        phraseTextField.enabled = enabled
        latitudeTextField.enabled = enabled
        longitudeTextField.enabled = enabled
        phraseSearchButton.enabled = enabled
        latLonSearchButton.enabled = enabled
        
        // adjust search button alphas
        if enabled {
            phraseSearchButton.alpha = 1.0
            latLonSearchButton.alpha = 1.0
        } else {
            phraseSearchButton.alpha = 0.5
            latLonSearchButton.alpha = 0.5
        }
    }
}

// MARK: - ViewController (Notifications)

extension ViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
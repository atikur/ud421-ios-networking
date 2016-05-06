//
//  LoginViewController.swift
//  MyFavoriteMovies
//
//  Created by Jarrod Parkes on 1/23/15.
//  Copyright (c) 2015 Udacity. All rights reserved.
//

import UIKit

// MARK: - LoginViewController: UIViewController

class LoginViewController: UIViewController {
    
    // MARK: Properties
    
    var appDelegate: AppDelegate!
    var keyboardOnScreen = false
    
    // MARK: Outlets
    
    @IBOutlet weak var usernameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var loginButton: BorderedButton!
    @IBOutlet weak var debugTextLabel: UILabel!
    @IBOutlet weak var movieImageView: UIImageView!
        
    // MARK: Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // get the app delegate
        appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate                        
        
        configureUI()
        
        subscribeToNotification(UIKeyboardWillShowNotification, selector: Constants.Selectors.KeyboardWillShow)
        subscribeToNotification(UIKeyboardWillHideNotification, selector: Constants.Selectors.KeyboardWillHide)
        subscribeToNotification(UIKeyboardDidShowNotification, selector: Constants.Selectors.KeyboardDidShow)
        subscribeToNotification(UIKeyboardDidHideNotification, selector: Constants.Selectors.KeyboardDidHide)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        unsubscribeFromAllNotifications()
    }
    
    // MARK: Login
    
    @IBAction func loginPressed(sender: AnyObject) {
        
        userDidTapView(self)
        
        if usernameTextField.text!.isEmpty || passwordTextField.text!.isEmpty {
            debugTextLabel.text = "Username or Password Empty."
        } else {
            setUIEnabled(false)
            
            /*
                Steps for Authentication...
                https://www.themoviedb.org/documentation/api/sessions
                
                Step 1: Create a request token
                Step 2: Ask the user for permission via the API ("login")
                Step 3: Create a session ID
                
                Extra Steps...
                Step 4: Get the user id ;)
                Step 5: Go to the next view!            
            */
            getRequestToken()
        }
    }
    
    private func completeLogin() {
        performUIUpdatesOnMain {
            self.debugTextLabel.text = ""
            self.setUIEnabled(true)
            let controller = self.storyboard!.instantiateViewControllerWithIdentifier("MoviesTabBarController") as! UITabBarController
            self.presentViewController(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: TheMovieDB
    
    private func getRequestToken() {
        
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey
        ]
        
        let request = NSURLRequest(URL: appDelegate.tmdbURLFromParameters(methodParameters, withPathExtension: "/authentication/token/new"))
        
        let task = appDelegate.sharedSession.dataTaskWithRequest(request) { (data, response, error) in
            
            guard let parsedResult = self.getParsedResult(data, response: response, error: error) else {
                return
            }
            
            guard let requestToken = parsedResult[Constants.TMDBParameterKeys.RequestToken] as? String else {
                self.displayError("Can't get request token")
                return
            }
            
            self.appDelegate.requestToken = requestToken
            self.loginWithToken(requestToken)
            
            print("Request Token: \(requestToken)")
        }

        task.resume()
    }
    
    func getParsedResult(data: NSData?, response: NSURLResponse?, error: NSError?) -> AnyObject? {
        guard error == nil else {
            self.displayError("Error occurred: \(error)")
            return nil
        }
        
        guard let statusCode = (response as? NSHTTPURLResponse)?.statusCode where statusCode >= 200 && statusCode <= 299 else {
            self.displayError("Status code not 2xx")
            return nil
        }
        
        guard let data = data else {
            self.displayError("No data returned")
            return nil
        }
        
        let parsedResult: AnyObject
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
        } catch {
            self.displayError("Can't parse JSON response")
            return nil
        }
        
        return parsedResult
    }
    
    func displayError(message: String) {
        print(message)
        
        dispatch_async(dispatch_get_main_queue()) {
            self.setUIEnabled(true)
        }
    }
    
    private func loginWithToken(requestToken: String) {
        
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.RequestToken: requestToken,
            Constants.TMDBParameterKeys.Username: usernameTextField.text!,
            Constants.TMDBParameterKeys.Password: passwordTextField.text!
        ]
        
        let url = appDelegate.tmdbURLFromParameters(methodParameters, withPathExtension: "/authentication/token/validate_with_login")
        let request = NSURLRequest(URL: url)
        
        let task = appDelegate.sharedSession.dataTaskWithRequest(request) {
            data, response, error in
            
            guard let parsedResult = self.getParsedResult(data, response: response, error: error) else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.debugTextLabel.text = "Login failed (wrong username/password)"
                }
                return
            }
            
            guard let success = parsedResult[Constants.TMDBResponseKeys.Success] as? Int where success == 1 else {
                self.displayError("Can't login. username: \(self.usernameTextField.text), password: \(self.passwordTextField.text)")
                return
            }
            
            self.getSessionID(requestToken)
            print("Logged in...")
        }
        task.resume()
    }
    
    private func getSessionID(requestToken: String) {
        
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.RequestToken: requestToken,
        ]
        
        let url = appDelegate.tmdbURLFromParameters(methodParameters, withPathExtension: "/authentication/session/new")
        let request = NSURLRequest(URL: url)
        
        let task = appDelegate.sharedSession.dataTaskWithRequest(request) {
            data, response, error in
            
            guard let parsedResult = self.getParsedResult(data, response: response, error: error) else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.debugTextLabel.text = "Can't get session id."
                }
                return
            }
            
            guard let sessionId = parsedResult[Constants.TMDBParameterKeys.SessionID] as? String else {
                print("Can't get session id.")
                return
            }
            
            self.appDelegate.sessionID = sessionId
            self.getUserID(sessionId)
            
            print("Session ID: \(sessionId)")
        }
        task.resume()
    }
    
    private func getUserID(sessionID: String) {
        
        let methodParameters = [
            Constants.TMDBParameterKeys.ApiKey: Constants.TMDBParameterValues.ApiKey,
            Constants.TMDBParameterKeys.SessionID: sessionID
        ]
        
        let url = appDelegate.tmdbURLFromParameters(methodParameters, withPathExtension: "/account")
        let request = NSURLRequest(URL: url)
        
        let task = appDelegate.sharedSession.dataTaskWithRequest(request) {
            data, response, error in
            
            guard let parsedResult = self.getParsedResult(data, response: response, error: error) else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.debugTextLabel.text = "Can't get user id."
                }
                return
            }
            
            guard let userId = parsedResult[Constants.TMDBResponseKeys.UserID] as? Int else {
                self.displayError("Can't get user id.")
                return
            }
            
            self.appDelegate.userID = userId
            
            print("User id: \(userId)")
        }
        
        task.resume()
    }
}

// MARK: - LoginViewController: UITextFieldDelegate

extension LoginViewController: UITextFieldDelegate {
    
    // MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: Show/Hide Keyboard
    
    func keyboardWillShow(notification: NSNotification) {
        if !keyboardOnScreen {
            view.frame.origin.y -= keyboardHeight(notification)
            movieImageView.hidden = true
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if keyboardOnScreen {
            view.frame.origin.y += keyboardHeight(notification)
            movieImageView.hidden = false
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
        resignIfFirstResponder(usernameTextField)
        resignIfFirstResponder(passwordTextField)
    }
}

// MARK: - LoginViewController (Configure UI)

extension LoginViewController {
    
    private func setUIEnabled(enabled: Bool) {
        usernameTextField.enabled = enabled
        passwordTextField.enabled = enabled
        loginButton.enabled = enabled
        debugTextLabel.text = ""
        debugTextLabel.enabled = enabled
        
        // adjust login button alpha
        if enabled {
            loginButton.alpha = 1.0
        } else {
            loginButton.alpha = 0.5
        }
    }
    
    private func configureUI() {
        
        // configure background gradient
        let backgroundGradient = CAGradientLayer()
        backgroundGradient.colors = [Constants.UI.LoginColorTop, Constants.UI.LoginColorBottom]
        backgroundGradient.locations = [0.0, 1.0]
        backgroundGradient.frame = view.frame
        view.layer.insertSublayer(backgroundGradient, atIndex: 0)
        
        configureTextField(usernameTextField)
        configureTextField(passwordTextField)
    }
    
    private func configureTextField(textField: UITextField) {
        let textFieldPaddingViewFrame = CGRectMake(0.0, 0.0, 13.0, 0.0)
        let textFieldPaddingView = UIView(frame: textFieldPaddingViewFrame)
        textField.leftView = textFieldPaddingView
        textField.leftViewMode = .Always
        textField.backgroundColor = Constants.UI.GreyColor
        textField.textColor = Constants.UI.BlueColor
        textField.attributedPlaceholder = NSAttributedString(string: textField.placeholder!, attributes: [NSForegroundColorAttributeName: UIColor.whiteColor()])
        textField.tintColor = Constants.UI.BlueColor
        textField.delegate = self
    }
}

// MARK: - LoginViewController (Notifications)

extension LoginViewController {
    
    private func subscribeToNotification(notification: String, selector: Selector) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: selector, name: notification, object: nil)
    }
    
    private func unsubscribeFromAllNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
}
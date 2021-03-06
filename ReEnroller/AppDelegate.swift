//
//  AppDelegate.swift
//  ReEnroller
//
//  Created by Leslie Helou on 2/19/17.
//  Based on the bash ReEnroller script by Douglas Worley
//  Copyright © 2017 Leslie Helou. All rights reserved.
//
//////////////////////////////////////////////////////////////////////////////////////////
//
//Copyright (c) 2017 Jamf.  All rights reserved.
//
//      Redistribution and use in source and binary forms, with or without
//      modification, are permitted provided that the following conditions are met:
//              * Redistributions of source code must retain the above copyright
//                notice, this list of conditions and the following disclaimer.
//              * Redistributions in binary form must reproduce the above copyright
//                notice, this list of conditions and the following disclaimer in the
//                documentation and/or other materials provided with the distribution.
//              * Neither the name of the Jamf nor the names of its contributors may be
//                used to endorse or promote products derived from this software without
//                specific prior written permission.
//
//      THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
//      EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//      WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//      DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
//      DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//      (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//      LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
//      ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//      (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//      SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//////////////////////////////////////////////////////////////////////////////////////////

// PI-000524: prevents management account password from being reset if password on
//            client doesn't match password on server.

import Cocoa
import Collaboration
import Foundation
import Security
import SystemConfiguration
import WebKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, URLSessionDelegate {
    
    @IBOutlet weak var ReEnroller_window: NSWindow!
    
    @IBOutlet weak var help_Window: NSWindow!
    @IBOutlet weak var help_WebView: WebView!
    @IBOutlet weak var reconMode_TabView: NSTabView!
    
    @IBOutlet weak var reEnroll_button: NSButton!
    @IBOutlet weak var enroll_button: NSButton!
    
    @IBOutlet weak var quickAdd_PathControl: NSPathControl!
    @IBOutlet weak var profile_PathControl: NSPathControl!
    @IBOutlet weak var removeProfile_Button: NSButton!  // removeProfile_Button.state == 1 if checked
    @IBOutlet weak var newEnrollment_Button: NSButton!
    @IBOutlet weak var removeAllProfiles_Button: NSButton!
    
    // non recon fields
    @IBOutlet weak var jssUrl_TextField: NSTextField!
    @IBOutlet weak var jssUsername_TextField: NSTextField!
    @IBOutlet weak var jssPassword_TextField: NSSecureTextField!
    @IBOutlet weak var mgmtAccount_TextField: NSTextField!
    @IBOutlet weak var mgmtAcctPwd_TextField: NSSecureTextField!
    @IBOutlet weak var mgmtAcctPwd2_TextField: NSSecureTextField!
    @IBOutlet weak var rndPwdLen_TextField: NSTextField?
    
    // management account buttons
    @IBOutlet weak var mgmtAcctCreate_button: NSButton!
    @IBOutlet weak var mgmtAcctHide_button: NSButton!
    @IBOutlet weak var randomPassword_button: NSButton!

    @IBOutlet weak var retainSite_Button: NSButton!
    @IBOutlet weak var enableSites_Button: NSButton!
    @IBOutlet weak var site_Button: NSPopUpButton!
    @IBOutlet weak var createPolicy_Button: NSButton!
    @IBOutlet weak var skipMdmCheck_Button: NSButton!
    @IBOutlet weak var runPolicy_Button: NSButton!
    @IBOutlet weak var policyId_Textfield: NSTextField!
    @IBOutlet weak var removeReEnroller_Button: NSButton!
    @IBOutlet weak var maxRetries_Textfield: NSTextField!
    @IBOutlet weak var retry_TextField: NSTextField!
    @IBOutlet weak var separatePackage_button: NSButton!
    
    @IBOutlet weak var processQuickAdd_Button: NSButton!
    @IBOutlet weak var spinner: NSProgressIndicator!
    
    let origBinary = "/usr/local/jamf/bin/jamf"
    let bakBinary = "/Library/Application Support/JAMF/ReEnroller/backup/jamf.bak"
    
    let origProfilesDir = "/var/db/ConfigurationProfiles"
    let bakProfilesDir = "/Library/Application Support/JAMF/ReEnroller/backup/ConfigurationProfiles.bak"

    let origKeychainFile = "/Library/Application Support/JAMF/JAMF.keychain"
    let bakKeychainFile  = "/Library/Application Support/JAMF/ReEnroller/backup/JAMF.keychain.bak"
    
    let jamfPlistPath = "/Library/Preferences/com.jamfsoftware.jamf.plist"
    let bakjamfPlistPath = "/Library/Application Support/JAMF/ReEnroller/backup/com.jamfsoftware.jamf.plist.bak"
    
    let airportPrefs = "/Library/Preferences/SystemConfiguration/com.apple.airport.preferences.plist"
    let bakAirportPrefs = "/Library/Application Support/JAMF/ReEnroller/backup/com.apple.airport.preferences.plist.bak"
    
    let configProfilePath = "/Library/Application Support/JAMF/ReEnroller/profile.mobileconfig"
    let verificationFile = "/Library/Application Support/JAMF/ReEnroller/Complete"
    
    var plistData:[String:AnyObject] = [:]  //our plist data format
    var jamfPlistData:[String:AnyObject] = [:]  //jamf plist data format
    var launchdPlistData:[String:AnyObject] = [:]  //com.jamf.ReEnroller plist data format
    var format = PropertyListSerialization.PropertyListFormat.xml //format of the property list file
    
    let fm = FileManager()
    var attributes = [FileAttributeKey : Any]()
    
    let myBundlePath = Bundle.main.bundlePath
    let blankSettingsPlistPath = Bundle.main.bundlePath+"/Contents/Resources/settings.plist"
    let logFilePath = "/private/var/log/jamf.log"
    var LogFileW: FileHandle?  = FileHandle(forUpdatingAtPath: "")
    
    var alert_answer: Bool  = false
    var oldURL              = ""
    var newURL              = [String]()
    var newJSSURL           = ""
    var newJSSHostname      = ""
    var newJSSPort          = ""
    
    let safeCharSet         = CharacterSet.alphanumerics
    var jssUsername         = ""
    var jssPassword         = ""
    var resourcePath        = ""
    var jssCredentials      = ""
    var jssCredsBase64      = ""
    var siteDict            = Dictionary<String, Any>()
    var siteId              = "-1"
    var mgmtAccount         = ""    // manangement account read from plist
    var mgmtAcctPwdXml      = ""    // static management account password
    var acctMaintPwdXml     = ""    // ensures the managment account password is properly randomized
    var mgmtAcctPwdLen      = 8
    var mgmtAcctCreate      = "true"
    var mgmtAcctHide        = "true"
    var pkgBuildResult:Int8 = 0
    
    var newJssArray         = [String]()
    var shortHostname       = ""
    
    var newEnrollment       = false
    
    // read this from Jamf server
    var createConfSwitches  = ""
    
    var newJssMgmtUrl       = ""
    var theNewInvite        = ""
    var removeReEnroller    = "yes"         // by default delete the ReEnroller folder after enrollment
    var retainSite          = "true"        // by default retain site when re-enrolling
    var skipMdmCheck        = "no"          // by default do not skip mdm check
    var StartInterval       = 1800          // default retry interval is 1800 seconds (30 minutes)
    var includesMsg         = "includes"
    var includesMsg2        = ""
    var policyMsg           = ""
    var postInstallPolicyId  = ""
    
    var profileUuid         = ""
    var removeConfigProfile = ""
    var removeAllProfiles   = ""
    
//    var safePackageURL      = ""
    var safeProfileURL      = ""
    var Pipe_pkg            = Pipe()
    var task_pkg            = Process()
    
    var maxRetries          = -1
    var retryCount          = 0
    
    // variables for client deployment
    @IBOutlet weak var enrollmentPackage: NSPathControl!
    @IBOutlet weak var remoteClient_TextField: NSTextField!
    
    let userDefaults = UserDefaults.standard
    
    // OS version info
    let os = ProcessInfo().operatingSystemVersion
    
    var startMigrationQ = OperationQueue()
    var enrollmentQ     = OperationQueue()
    
    // migration check policy

    @IBAction func myHelp(_ sender: Any) {
        help_Window.titleVisibility = .hidden
        
        self.help_Window.makeKeyAndOrderFront(self)
        self.help_Window.collectionBehavior = NSWindow.CollectionBehavior.moveToActiveSpace
        
        let helpFilePath = Bundle.main.path(forResource: "index", ofType: "html")
        help_WebView.mainFrameURL = helpFilePath
        help_Window.setIsVisible(true)
    }
    
    @IBAction func showReenroll_fn(_ sender: Any) {
        reEnroll_button.isBordered = true
        enroll_button.isBordered = false
        processQuickAdd_Button.isEnabled = true
        reconMode_TabView.selectTabViewItem(at: 0)
    }
    @IBAction func showEnroll_fn(_ sender: NSButton) {
        reEnroll_button.isBordered = false
        enroll_button.isBordered = true
        processQuickAdd_Button.isEnabled = false
        reconMode_TabView.selectTabViewItem(at: 1)
    }
    
    @IBAction func runRemote(_ sender: Any) {
        var packageUrlString    = ""
        var packageArray        = [String]()
        var pushPackageName     = ""
        if let packageUrl = enrollmentPackage.url {
            packageUrlString = "\(packageUrl)".replacingOccurrences(of: "%20", with: " ")
            packageUrlString = packageUrlString.replacingOccurrences(of: "file://", with: "")
            if packageUrlString != "/" {
                print("path to package: \(packageUrlString)")
                packageArray = "\(packageUrlString)".components(separatedBy: "/")
                pushPackageName = packageArray.last!
            } else {
                print("path to package: Missing")
            }
        }   // reEnroller package to deploy - end
        
        print("remote client: \(remoteClient_TextField.stringValue)")
        
        let remotePush = myExitCode(cmd: "/bin/bash", args: "-c", "expect -c \";spawn scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \"\(packageUrlString)\" \(mgmtAccount_TextField.stringValue)@\(remoteClient_TextField.stringValue):/tmp/.\(pushPackageName);;expect \\\"*Password*\\\";send \(mgmtAcctPwd_TextField.stringValue);send \\\r;;expect eof;\" > /dev/null")
        print("result of remote push: \(remotePush)")
        
        let remoteInstall = myExitCode(cmd: "/bin/bash", args: "-c", "expect -c \";spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t \(mgmtAccount_TextField.stringValue)@\(remoteClient_TextField.stringValue) \\\"sudo /usr/sbin/installer -pkg /tmp/.\(pushPackageName) -target /\\\";expect \\\"*Password*\\\";send \\\"\(mgmtAcctPwd_TextField.stringValue)\\\";send \\r;;expect \\\"*Password*\\\";send \\\"\(mgmtAcctPwd_TextField.stringValue)\\\";send \\r;;expect eof;\" > /dev/null")
        print("result of remote install: \(remoteInstall)")
        
        let remoteRemove = myExitCode(cmd: "/bin/bash", args: "-c", "expect -c \";spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -t \(mgmtAccount_TextField.stringValue)@\(remoteClient_TextField.stringValue) \\\"sudo /bin/rm /tmp/.\(pushPackageName)\\\";expect \\\"*Password*\\\";send \\\"\(mgmtAcctPwd_TextField.stringValue)\\\";send \\r;;expect \\\"*Password*\\\";send \\\"\(mgmtAcctPwd_TextField.stringValue)\\\";send \\r;;expect eof;\" > /dev/null")
        print("result of remote remove: \(remoteRemove)")
        
    }
    
    @IBAction func randomPassword(_ sender: Any) {
        if randomPassword_button.state.rawValue == 1 {
            mgmtAcctPwd_TextField.isEnabled = false
            mgmtAcctPwd2_TextField.isEnabled = false
            createPolicy_Button.state = convertToNSControlStateValue(1)
            createPolicy_Button.isEnabled = false
            rndPwdLen_TextField?.isEnabled = true
            mgmtAcctPwd_TextField.stringValue = ""
            mgmtAcctPwd2_TextField.stringValue = ""
            alert_dialog(header: "Attention:", message: "A new account must be used when utilizing a random password.  Using an existing account will result in a mismatch between the client and server.\n\nThe new account will be created automatically during enrollment.")
        } else {
            mgmtAcctPwd_TextField.isEnabled = true
            mgmtAcctPwd2_TextField.isEnabled = true
            createPolicy_Button.isEnabled = true
            rndPwdLen_TextField?.isEnabled = false
        }
    }
    
    @IBAction func runPolicy_Function(_ sender: Any) {
        if runPolicy_Button.state.rawValue == 1 {
            policyId_Textfield.isEnabled = true
        } else {
            policyId_Textfield.isEnabled = false
        }
    }
    
    
//    @IBAction func fetchSites_Button(_ sender: Any) {
    func fetchSites() {
        if enableSites_Button.state.rawValue == 1 {
            // get site info - start
            var siteArray = [String]()
            let jssUrl = jssUrl_TextField.stringValue
            jssUsername = jssUsername_TextField.stringValue
            jssPassword = jssPassword_TextField.stringValue
            
            if "\(jssUrl)" == "" {
                alert_dialog(header: "Attention:", message: "Jamf server is required.")
                enableSites_Button.state = convertToNSControlStateValue(0)
                return
            }
            
            if "\(jssUsername)" == "" || "\(jssPassword)" == "" {
                alert_dialog(header: "Attention:", message: "Jamf server username and password are required in order to use Sites.")
                enableSites_Button.state = convertToNSControlStateValue(0)
                return
            }
            jssCredentials = "\(jssUsername):\(jssPassword)"
            let jssCredentialsUtf8 = jssCredentials.data(using: String.Encoding.utf8)
            jssCredsBase64 = (jssCredentialsUtf8?.base64EncodedString())!
            
            resourcePath = "\(jssUrl)/JSSResource/sites"
            resourcePath = resourcePath.replacingOccurrences(of: "//JSSResource", with: "/JSSResource")
            // get all the sites - start
            getSites() {
                (result: Dictionary) in
                self.siteDict = result
                for (key, _) in self.siteDict {
                    siteArray.append(key)
                    siteArray = siteArray.sorted()
                }
//                print("sorted sites: \(siteArray)")

                return [:]
            }
            // get all the sites - end
            
        } else {
            site_Button.isEnabled = false
        }
    }
    
    @IBAction func selectSite_Button(_ sender: Any) {
//        print("selected site: \(site_Button.titleOfSelectedItem ?? "None")")
        let siteKey = "\(site_Button.titleOfSelectedItem ?? "None")"
        "\(site_Button.titleOfSelectedItem ?? "None")" == "None" ? (siteId = "-1") : (siteId = "\(siteDict[siteKey] ?? "-1")")
//        print("selected site id: \(siteId)")
    }
    
    @IBAction func siteToggle_button(_ sender: NSButton) {
//        print("\(String(describing: sender.identifier!))")
        if (convertFromOptionalNSUserInterfaceItemIdentifier(sender.identifier)! == "selectSite") && (enableSites_Button.state.rawValue == 1) {
            retainSite_Button.state = convertToNSControlStateValue(0)
            fetchSites()
        } else if (convertFromOptionalNSUserInterfaceItemIdentifier(sender.identifier)! == "existingSite") && (retainSite_Button.state.rawValue == 1) {
            enableSites_Button.state = convertToNSControlStateValue(0)
            self.site_Button.isEnabled = false
        } else if (enableSites_Button.state.rawValue == 0) {
            self.site_Button.isEnabled = false
        }
    }
    
    // process function - start
    @IBAction func process(_ sender: Any) {
        // get invitation code - start
        var jssUrl = jssUrl_TextField.stringValue
        if "\(jssUrl)" == "" {
            alert_dialog(header: "Alert", message: "Please provide the URL for the new server.")
            return
        }
        jssUrl = dropTrailingSlash(theSentString: jssUrl)
        
        let mgmtAcct = mgmtAccount_TextField.stringValue
        if "\(mgmtAcct)" == "" {
            self.alert_dialog(header: "Attention", message: "You must supply a management account username.")
            mgmtAccount_TextField.becomeFirstResponder()
            return
        }
        // fix special characters in management account name
        let mgmtAcctNameXml = xmlEncode(rawString: mgmtAcct)
        
        if randomPassword_button.state.rawValue == 0 {
            let mgmtAcctPwd = mgmtAcctPwd_TextField.stringValue
            let mgmtAcctPwd2 = mgmtAcctPwd2_TextField.stringValue
            if "\(mgmtAcctPwd)" == "" {
                self.alert_dialog(header: "Attention", message: "Password cannot be left blank.")
                mgmtAccount_TextField.becomeFirstResponder()
                return
            }
            if "\(mgmtAcctPwd)" != "\(mgmtAcctPwd2)" {
                self.alert_dialog(header: "Attention", message: "Management account passwords do not match.")
                mgmtAcctPwd_TextField.becomeFirstResponder()
                return
            }
            
            // fix special characters in management account password
            let mgmtAcctPwdEncode = xmlEncode(rawString: mgmtAcctPwd)
            mgmtAcctPwdXml = "<ssh_password>\(mgmtAcctPwdEncode)</ssh_password>"
//            mgmtAcctPwdXml = "<ssh_password>\(mgmtAcctPwd)</ssh_password>"
            
            // can't use this to (re)set management account password, receive the following
//            Executing Policy Change Password
//            Error: The Managed Account Password could not be changed.
            // acctMaintPwdXml = "<account_maintenance><management_account><action>specified</action><managed_password>\(mgmtAcctPwd)</managed_password></management_account></account_maintenance>"
        } else {
            // like to get rid of this - find way to change password when client and JPS differ
//          check the local system for the existance of the management account
            if ( userOperation(mgmtUser: mgmtAcct, operation: "find") != "" ) {
                alert_dialog(header: "Attention:", message: "Account \(mgmtAcct) cannot be used with a random password as it exists on this system.")
                return
            }
            // verify random password lenght is an integer - start
            let pattern = "(^[0-9]*$)"
            let regex1 = try! NSRegularExpression(pattern: pattern, options: [])
            let matches = regex1.matches(in: (rndPwdLen_TextField?.stringValue)!, options: [], range: NSRange(location: 0, length: (rndPwdLen_TextField?.stringValue.count)!))
            if matches.count != 0 {
                //                print("valid")
                mgmtAcctPwdLen = Int((rndPwdLen_TextField?.stringValue)!)!
//                print("pwd len: \(mgmtAcctPwdLen)")
                if (mgmtAcctPwdLen) > 255 || (mgmtAcctPwdLen) < 8 {
                    alert_dialog(header: "Attention:", message: "Verify an random password length is between 8 and 255.")
                    return
                }
            } else {
                alert_dialog(header: "Attention:", message: "Verify an interger value was entered for the random password length.")
                return
            }
            // verify random password lenght is an integer - end
            // create a random password
            mgmtAcctPwdXml = myExitValue(cmd: "/bin/bash", args: "-c", "/usr/bin/uuidgen")[0]
            acctMaintPwdXml = "<account_maintenance><management_account><action>random</action><managed_password_length>\(mgmtAcctPwdLen)</managed_password_length></management_account></account_maintenance>"
        }
        
        // server is reachable - start
//        if !(checkURL(theUrl: jssUrl) == 0) {
//            self.alert_dialog(header: "Attention", message: "The new server, \(jssUrl), could not be contacted.")
//            return
//        }

        self.spinner.startAnimation(self)
        
        healthCheck(server: jssUrl) {
            (result: [String]) in
            print("health check result: \(result)")
            if ( result[1] != "[]" ) {
                let lightFormat = self.removeTag(xmlString: result[1].replacingOccurrences(of: "><", with: ">\n<"))
                self.alert_dialog(header: "Attention", message: "The new server, \(jssUrl), does not appear ready for enrollments.\nResult of healthCheck: \(lightFormat)\nResponse code: \(result[0])")
                self.spinner.stopAnimation(self)
                return
            } else {
                // server is reachable
                self.jssUsername = self.jssUsername_TextField.stringValue //.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
                self.jssPassword = self.jssPassword_TextField.stringValue //.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
                
                if "\(self.jssUsername)" == "" || "\(self.jssPassword))" == "" {
                    self.alert_dialog(header: "Alert", message: "Please provide both a username and password for the server.")
                    self.spinner.stopAnimation(self)
                    return
                }
                
                let jpsCredentials = "\(self.jssUsername):\(self.jssPassword)"
                let jpsBase64Creds = jpsCredentials.data(using: .utf8)?.base64EncodedString() ?? ""
                
                // get SSL verification settings from new server - start
//                self.plistData["createConfSwitches"] =
                self.getSslVerify(action: "POST", endpoint: "\(jssUrl)/casper.jxml", name: self.jssUsername, password: self.jssPassword) {
                    (result: [Any]) in
//                    var verifySslSetting = ""
//                    let responseCode = result[0] as! Int
                    let verifySslSetting = result[1] as! String
                    
                    if "\(verifySslSetting)" == "" {
                        self.alert_dialog(header: "Alert", message: "Unable to determine verifySSLCert setting on server, setting to always_except_during_enrollment")
                        self.plistData["createConfSwitches"] = "always_except_during_enrollment" as AnyObject
                    } else {
                        self.plistData["createConfSwitches"] = verifySslSetting as AnyObject
                        print("verifySSLCert setting from server: \(verifySslSetting)")
                    }
                    // get SSL verification settings from new server - end
                    
                    self.retainSite_Button.state.rawValue == 1 ? (self.retainSite = "true") : (self.retainSite = "false")
                    self.mgmtAcctCreate_button.state.rawValue == 1 ? (self.mgmtAcctCreate = "true") : (self.mgmtAcctCreate = "false")
                    self.mgmtAcctHide_button.state.rawValue == 1 ? (self.mgmtAcctHide = "true") : (self.mgmtAcctHide = "false")
                
                    self.theNewInvite = ""
                
                    let invite_request = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><computer_invitation><lifetime>2147483647</lifetime><multiple_uses_allowed>true</multiple_uses_allowed><ssh_username>" + mgmtAcctNameXml + "</ssh_username><ssh_password_method>\(convertFromNSControlStateValue(self.randomPassword_button.state))</ssh_password_method>\(self.mgmtAcctPwdXml)<enroll_into_site><id>" + self.siteId + "</id></enroll_into_site><keep_existing_site_membership>" + self.retainSite + "</keep_existing_site_membership><create_account_if_does_not_exist>\(self.mgmtAcctCreate)</create_account_if_does_not_exist><hide_account>\(self.mgmtAcctHide)</hide_account><lock_down_ssh>false</lock_down_ssh></computer_invitation>"
    //                print("invite request: " + invite_request)
                
                    // get invitation code
                    self.apiAction(action: "POST", credentials: jpsBase64Creds, xml: invite_request, endpoint: "\(jssUrl)/JSSResource/computerinvitations/id/0") {
                        (result: [Any]) in
                        let responseCode = result[0] as! Int
                        let responseMesage = result[1] as! String
                        if !(responseCode > 199 && responseCode < 300) {
                            let lightFormat = self.removeTag(xmlString: responseMesage.replacingOccurrences(of: "><", with: ">\n<"))
                            self.alert_dialog(header: "Attention", message: "Failed to create invitation code.\nMessage: \(lightFormat)\nResponse code: \(responseCode)")
                            self.spinner.stopAnimation(self)
                            return
                        } else {
                            print("full reply for invitiation code request:\n\t\(responseMesage)\n")
                            if let start = responseMesage.range(of: "<invitation>"),
                                let end  = responseMesage.range(of: "</invitation>", range: start.upperBound..<(responseMesage.endIndex)) {
                                self.theNewInvite.append((String(responseMesage[start.upperBound..<end.lowerBound])))
                                if "\(self.theNewInvite)" == "" {
                                    self.alert_dialog(header: "Alert", message: "Unable to create invitation.  Verify the account, \(self.jssUsername), has been assigned permissions to do so.")
                                    self.spinner.stopAnimation(self)
                                    return
                                } else {
                                    print("Found invitation code: \(self.theNewInvite)")
                                    
                                    if self.createPolicy_Button.state.rawValue == 1 {
                                        
                                        let migrationCheckPolicy = "<?xml version='1.0' encoding='UTF-8' standalone='no'?><policy><general><name>Migration Complete v4</name><enabled>true</enabled><trigger>EVENT</trigger><trigger_checkin>false</trigger_checkin><trigger_enrollment_complete>false</trigger_enrollment_complete><trigger_login>false</trigger_login><trigger_logout>false</trigger_logout><trigger_network_state_changed>false</trigger_network_state_changed><trigger_startup>false</trigger_startup><trigger_other>jpsmigrationcheck</trigger_other><frequency>Ongoing</frequency><location_user_only>false</location_user_only><target_drive>/</target_drive><offline>false</offline><network_requirements>Any</network_requirements><site><name>None</name></site></general><scope><all_computers>true</all_computers></scope><files_processes><run_command>touch /Library/Application\\ Support/JAMF/ReEnroller/Complete</run_command></files_processes></policy>"
                                        
                                        self.apiAction(action: "POST", credentials: jpsBase64Creds, xml: migrationCheckPolicy, endpoint: "\(jssUrl)/JSSResource/policies/id/0") {
                                            (result: [Any]) in
                                            let responseCode = result[0] as! Int
                                            let responseMesage = result[1] as! String
                                            if !(responseCode > 199 && responseCode < 300) {
                                                if responseCode == 409 {
                                                    print("Migration complete policy already exists")
                                                } else {
                                                    self.alert_dialog(header: "Attention", message: "Failed to create the migration complete policy.\nSee Help to create it manually.\nResponse code: \(responseCode)")
                                                }
                                            } else {
                                                print("Created new enrollment complete policy")
                                                print("\(responseMesage)")
                                            }
                                            
                                        }
                                    }   // if self.createPolicy_Button.state == 1 - end
                                    
                                    self.plistData["theNewInvite"] = self.theNewInvite as AnyObject
                                    
                                    jssUrl = jssUrl.lowercased().replacingOccurrences(of: "https://", with: "")
                                    jssUrl = jssUrl.lowercased().replacingOccurrences(of: "http://", with: "")
                                    (self.newJSSHostname, self.newJSSPort) = self.getHost_getPort(theURL: jssUrl)
                                    //        print("newJSSHostname: \(newJSSHostname)")
                                    
                                    // get server hostname for use in the package name
                                    self.newJssArray = self.newJSSHostname.components(separatedBy: ".")
                                    self.newJssArray[0] == "" ? (self.shortHostname = "new") : (self.shortHostname = self.newJssArray[0])
                                    
                                    //        print("newJSSPort: \(newJSSPort)")
                                    self.newJssMgmtUrl = "https://\(self.newJSSHostname):\(self.newJSSPort)"
                                    //        print("newJssMgmtUrl: \(newJssMgmtUrl)")
                                    
                                    self.plistData["newJSSHostname"] = self.newJSSHostname as AnyObject
                                    self.plistData["newJSSPort"] = self.newJSSPort as AnyObject
                                    //plistData["createConfSwitches"] = newURL_array[1] as AnyObject
                                    
                                    self.plistData["mgmtAccount"] = self.mgmtAccount_TextField.stringValue as AnyObject
                                    
                                    // put app in place
                                    let buildFolder = "/private/tmp/reEnroller-"+self.getDateTime(x: 1)
                                    
                                    let _ = self.myExitCode(cmd: "/bin/rm", args: "/private/tmp/reEnroller*")
                                    
                                    var buildFolderd = "" // build folder for launchd items, may be outside build folder if separating app from launchd
                                    let settingsPlistPath = buildFolder+"/Library/Application Support/JAMF/ReEnroller/settings.plist"
                                    
                                    // create build location and place items
                                    do {
                                        try self.fm.createDirectory(atPath: buildFolder+"/Library/Application Support/JAMF/ReEnroller", withIntermediateDirectories: true, attributes: nil)
                                        
                                        // Need to be able to run the app with elevated privileges for this to work
                                        //            // set permissions and ownership
                                        //            attributes[.posixPermissions] = 0o750
                                        //            attributes[.ownerAccountID] = 0
                                        //            attributes[.groupOwnerAccountID] = 0
                                        //            do {
                                        //                try fm.setAttributes(attributes, ofItemAtPath: buildFolder+"/Library/Application Support/JAMF/ReEnroller")
                                        //            }
                                        
                                        // copy the app into the pkg building location
                                        do {
                                            try self.fm.copyItem(atPath: self.myBundlePath, toPath: buildFolder+"/Library/Application Support/JAMF/ReEnroller/ReEnroller.app")
                                        } catch {
                                            self.alert_dialog(header: "-Attention-", message: "Could not copy app to build folder - exiting.")
                                            exit(1)
                                        }
                                        // put settings.plist into place
                                        do {
                                            try self.fm.copyItem(atPath: self.blankSettingsPlistPath, toPath: settingsPlistPath)
                                        } catch {
                                            self.alert_dialog(header: "-Attention-", message: "Could not copy settings.plist to build folder - exiting.")
                                            exit(1)
                                        }
                                        
                                    } catch {
                                        self.alert_dialog(header: "-Attention-", message: "Could not create build folder - exiting.")
                                        exit(1)
                                    }
                                    
                                    // create folder to hold backups of exitsing files/folders - start
                                    do {
                                        try self.fm.createDirectory(atPath: buildFolder+"/Library/Application Support/JAMF/ReEnroller/backup", withIntermediateDirectories: true, attributes: nil)
                                    } catch {
                                        self.alert_dialog(header: "-Attention-", message: "Could not create backup folder - exiting.")
                                        exit(1)
                                    }
                                    // create folder to hold backups of exitsing files/folders - end
                                    
                                    // if a config profile is present copy it to the pkg building location
                                    if let profileURL = self.profile_PathControl.url {
                                        self.safeProfileURL = "\(profileURL)".replacingOccurrences(of: "%20", with: " ")
                                        self.safeProfileURL = self.safeProfileURL.replacingOccurrences(of: "file://", with: "")
                                        //            print("safeProfileURL: \(safeProfileURL)")
                                        
                                        if self.safeProfileURL != "/" {
                                            do {
                                                try self.fm.copyItem(atPath: self.safeProfileURL, toPath: buildFolder+"/Library/Application Support/JAMF/ReEnroller/profile.mobileconfig")
                                            } catch {
                                                self.alert_dialog(header: "-Attention-", message: "Could not copy config profile.  If there are spaces in the profile name try removing them. Unable to create pkg - exiting.")
                                                self.writeToLog(theMessage: "Could not copy config profile.  If there are spaces in the profile name try removing them. Unable to create pkg - exiting.")
                                                exit(1)
                                            }
                                            // add config profile values to settings - start
                                            do {
                                                let one = try String(contentsOf: self.profile_PathControl.url! as URL, encoding: String.Encoding.ascii).components(separatedBy: "</string><key>PayloadType</key>")
                                                let PayloadUUID = one[0].components(separatedBy: "<key>PayloadUUID</key><string>")
                                                //                    print ("\(PayloadUUID[1])")
                                                self.plistData["profileUUID"] = "\(PayloadUUID[1])" as AnyObject
                                                if self.removeProfile_Button.state.rawValue == 0 {
                                                    self.plistData["removeProfile"] = "false" as AnyObject
                                                } else {
                                                    self.plistData["removeProfile"] = "true" as AnyObject
                                                }
                                            } catch {
                                                print("unable to read file")
                                            }
                                        }
                                    }   // add config profile values to settings - end
                                    
                                    // configure all profile removal - start
                                    if self.removeAllProfiles_Button.state.rawValue == 0 {
                                        self.plistData["removeAllProfiles"] = "false" as AnyObject
                                    } else {
                                        self.plistData["removeAllProfiles"] = "true" as AnyObject
                                    }
                                    // configure all profile removal - end
                                    
                                    // configure ReEnroller folder removal - start
                                    if self.removeReEnroller_Button.state.rawValue == 0 {
                                        self.plistData["removeReEnroller"] = "no" as AnyObject
                                    } else {
                                        self.plistData["removeReEnroller"] = "yes" as AnyObject
                                    }
                                    // configure ReEnroller folder removal - end
                                    
                                    // configure new enrollment check - start
                                    if self.newEnrollment_Button.state.rawValue == 0 {
                                        self.plistData["newEnrollment"] = 0 as AnyObject
                                    } else {
                                        self.plistData["newEnrollment"] = 1 as AnyObject
                                    }
                                    // configure new enrollment check - end
                                    
                                    // configure mdm check - start
                                    if self.skipMdmCheck_Button.state.rawValue == 0 {
                                        self.plistData["skipMdmCheck"] = "no" as AnyObject
                                    } else {
                                        self.plistData["skipMdmCheck"] = "yes" as AnyObject
                                    }
                                    // configure mdm - end
                                    
                                    // postInstallPolicyId - start
                                    if self.runPolicy_Button.state.rawValue == 0 {
                                        self.plistData["postInstallPolicyId"] = "" as AnyObject
                                    } else {
                                        let policyId = self.policyId_Textfield.stringValue
                                        // verify we have a valid number
                                        if policyId.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
                                            self.plistData["postInstallPolicyId"] = "" as AnyObject
                                        } else {
                                            self.plistData["postInstallPolicyId"] = self.policyId_Textfield.stringValue as AnyObject
                                        }
                                    }
                                    // postInstallPolicyId - end
                                    
                                    // max retries -  start
                                    let maxRetriesString = self.maxRetries_Textfield.stringValue
                                    // verify we have a valid number or it was left blank
                                    if maxRetriesString != "" {
                                        if maxRetriesString.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
                                            self.spinner.stopAnimation(self)
                                            self.alert_dialog(header: "-Attention-", message: "Invalid value entered for the maximum number of retries.")
                                            return
                                        } else {
                                            self.plistData["maxRetries"] = self.maxRetries_Textfield.stringValue as AnyObject
                                        }
                                    } else {
                                        self.plistData["maxRetries"] = "-1" as AnyObject
                                    }
                                    // max retries - end
                                    
                                    // set retry interval in launchd - start
                                    if let retryInterval = Int(self.retry_TextField.stringValue) {
                                        if retryInterval >= 5 {
                                            self.StartInterval = retryInterval*60    // convert minutes to seconds
                                            //                print("Setting custon retry interval: \(StartInterval)")
                                        }
                                    } else {
                                        self.spinner.stopAnimation(self)
                                        self.alert_dialog(header: "-Attention-", message: "Invalid value entered for the retry interval.")
                                        return
                                    }
                                    // set retry interval in launchd - end
                                    
                                    // prepare postinstall script if option is checked - start
                                    if self.separatePackage_button.state.rawValue == 0 {
                                        buildFolderd = buildFolder
                                    } else {
                                        buildFolderd = "/private/tmp/reEnrollerd-"+self.getDateTime(x: 1)
                                        self.includesMsg = "does not include"
                                        self.includesMsg2 = "  The launch daemons are packaged in: ReEnrollerDaemon-\(self.shortHostname).pkg."
                                    }
                                    
                                    do {
                                        try self.fm.createDirectory(atPath: buildFolderd+"/Library/LaunchDaemons", withIntermediateDirectories: true, attributes: nil)
                                        do {
                                            try self.fm.copyItem(atPath: self.myBundlePath+"/Contents/Resources/com.jamf.ReEnroller.plist", toPath: buildFolderd+"/Library/LaunchDaemons/com.jamf.ReEnroller.plist")
                                        } catch {
                                            self.writeToLog(theMessage: "Could not copy launchd, unable to create pkg")
                                            self.alert_dialog(header: "-Attention-", message: "Could not copy launchd to build folder - exiting.")
                                            exit(1)
                                        }
                                        
                                    } catch {
                                        self.writeToLog(theMessage: "Unable to place launch daemon.")
                                        self.alert_dialog(header: "-Attention-", message: "Could not LaunchDeamons folder in build folder - exiting.")
                                        exit(1)
                                    }
                                    // put launch daemon in place - end
                                    
                                    let launchdFile = buildFolderd+"/Library/LaunchDaemons/com.jamf.ReEnroller.plist"
                                    if self.fm.fileExists(atPath: launchdFile) {
                                        let launchdPlistXML = self.fm.contents(atPath: launchdFile)!
                                        do{
                                            self.writeToLog(theMessage: "Reading settings from: \(launchdFile)")
                                            self.launchdPlistData = try PropertyListSerialization.propertyList(from: launchdPlistXML,
                                                                                                               options: .mutableContainersAndLeaves,
                                                                                                               format: &self.format)
                                                as! [String : AnyObject]
                                        }
                                        catch{
                                            self.writeToLog(theMessage: "Error launchd plist: \(error), format: \(self.format)")
                                        }
                                    }
                                    
                                    self.launchdPlistData["StartInterval"] = self.StartInterval as AnyObject
                                    
                                    // Write values to launchd plist - start
                                    (self.launchdPlistData as NSDictionary).write(toFile: launchdFile, atomically: false)
                                    // Write values to launchd plist - end
                                    
                                    // Write settings from GUI to settings.plist
                                    (self.plistData as NSDictionary).write(toFile: settingsPlistPath, atomically: false)
                                    
                                    let packageName = (self.newEnrollment_Button.state.rawValue == 1) ? "Enroller":"ReEnroller"
                                    
                                    // rename existing ReEnroller.pkg if it exists - start
                                    if self.fm.fileExists(atPath: NSHomeDirectory()+"/Desktop/\(packageName)-\(self.shortHostname).pkg") {
                                        do {
                                            try self.fm.moveItem(atPath: NSHomeDirectory()+"/Desktop/\(packageName)-\(self.shortHostname).pkg", toPath: NSHomeDirectory()+"/Desktop/\(packageName)-\(self.shortHostname)-"+self.getDateTime(x: 1)+".pkg")
                                        } catch {
                                            self.alert_dialog(header: "Alert", message: "Unable to rename an existing \(packageName)-\(self.shortHostname).pkg file on the Desktop.  Try renaming/removing it manually: sudo mv ~/Desktop/\(packageName)-\(self.shortHostname).pkg ~/Desktop/\(packageName)-\(self.shortHostname)-old.pkg.")
                                            exit(1)
                                        }
                                    }
                                    // rename existing ReEnroller.pkg if it exists - end
                                    
                                    // Create pkg of app and launchd - start
                                    if self.separatePackage_button.state.rawValue == 0 {
                                        self.pkgBuildResult = self.myExitCode(cmd: "/usr/bin/pkgbuild", args: "--identifier", "com.jamf.ReEnroller", "--root", buildFolder, "--scripts", self.myBundlePath+"/Contents/Resources/1", "--component-plist", self.myBundlePath+"/Contents/Resources/ReEnroller-component.plist", NSHomeDirectory()+"/Desktop/\(packageName)-\(self.shortHostname).pkg")
                                        
                                    } else {
                                        self.pkgBuildResult = self.myExitCode(cmd: "/usr/bin/pkgbuild", args: "--identifier", "com.jamf.ReEnroller", "--root", buildFolder, "--scripts", self.myBundlePath+"/Contents/Resources/2", "--component-plist", self.myBundlePath+"/Contents/Resources/ReEnroller-component.plist", NSHomeDirectory()+"/Desktop/\(packageName)-\(self.shortHostname).pkg")
                                        self.pkgBuildResult = self.myExitCode(cmd: "/usr/bin/pkgbuild", args: "--identifier", "com.jamf.ReEnrollerd", "--root", buildFolderd, "--scripts", self.myBundlePath+"/Contents/Resources/1", NSHomeDirectory()+"/Desktop/\(packageName)Daemon-\(self.shortHostname).pkg")
                                    }
                                    if self.pkgBuildResult != 0 {
                                        self.alert_dialog(header: "-Attention-", message: "Could not create the \(packageName)(Daemon) package - exiting.")
                                        exit(1)
                                    }
                                    // Create pkg of app and launchd - end
                                    
                                    self.spinner.stopAnimation(self)
                                    
                                    if self.createPolicy_Button.state.rawValue == 1 {
                                        self.policyMsg = "\n\nVerify the Migration Complete policy was created on the new server.  "
                                        if self.randomPassword_button.state.rawValue == 0 {
                                            self.policyMsg.append("The policy should contain a 'Files and Processes' payload.  Modify if needed.")
                                        } else {
                                            self.policyMsg.append("The policy should contain a 'Files and Processes' payload along with a 'Management Account' payload.  Modify if needed.")
                                        }
                                    } else {
                                        self.policyMsg = "\n\nBe sure to create a migration complete policy before starting to migrate, see help or more information."
                                    }
                                    
                                    // alert the user, we're done
                                    self.alert_dialog(header: "Attention:", message: "A package (\(packageName)-\(self.shortHostname).pkg) has been created on your desktop which is ready to be deployed with your current Jamf server.\n\nThe package \(self.includesMsg) a postinstall script to load the launch daemon and start the \(packageName) app.\(self.includesMsg2)\(self.policyMsg)")
                                    // Create pkg of app and launchd - end
                                    
                                    let _ = self.myExitCode(cmd: "/bin/bash", args: "-c", "/bin/rm -fr /private/tmp/reEnroller-*")

                                }
                            } else {
                                print("invalid reply from the Jamf server when requesting an invitation code.")
                                self.spinner.stopAnimation(self)
                                return
                            }
                        }
                    }
                }
                
            }   // healthcheck - server is reachable - end
        }   // healthCheck(server: jssUrl) - end
       
    }
    // process function - end
    
//---------------------------------------------------------------------------//
//--------------------------  Start the migration  --------------------------//
//---------------------------------------------------------------------------//

    func beginMigration() {
        
        var binaryExists     = false
        var binaryDownloaded = false
        
        if retryCount > maxRetries && maxRetries > -1 {
            // retry count has been met, stop retrying and remove the app
            writeToLog(theMessage: "Retry count: (\(retryCount))\nMaximum retries: \(maxRetries)\nRetry count has been met, stop retrying and remove the app and related files.")
            self.verifiedCleanup(type: "partial")
            NSApplication.shared.terminate(self)
        }
        retryCount += 1
        userDefaults.set(retryCount, forKey: "retryCount")
        
        writeToLog(theMessage: "Starting the enrollment process for the new Jamf Pro server.  Attempt: \(retryCount)")
        startMigrationQ.maxConcurrentOperationCount = 1
        startMigrationQ.addOperation {
            // ensure we still have network connectivity - start
            var connectivityCounter = 0
            while !self.connectedToNetwork() {
                sleep(2)
                if connectivityCounter > 30 {
                   self.writeToLog(theMessage: "There was a problem after removing old MDM configuration, network connectivity was lost. Will attempt to fall back to old settings and exiting!")
                    self.unverifiedFallback()
                    exit(1)
                }
                connectivityCounter += 1
                self.writeToLog(theMessage: "Waiting for network connectivity.")
            }
            // ensure we still have network connectivity - end
            
            // connectivity to new Jamf Pro server - start
            self.writeToLog(theMessage: "Attempting to connect to new Jamf Server (\(self.newJSSHostname)) and download the jamf binary.")
            
            self.healthCheck(server: self.newJssMgmtUrl) {
                (result: [String]) in
                if ( result[1] != "[]" ) {
                    let lightFormat = self.removeTag(xmlString: result[1].replacingOccurrences(of: "><", with: ">\n<"))
                    self.writeToLog(theMessage: "The new server, \(self.newJssMgmtUrl), does not appear ready for enrollments.\n\t\tResult of healthCheck: \(lightFormat)\n\t\tResponse code: \(result[0])")
                    //              remove config profile if one was installed
                    if self.profileUuid != "" {
                        if !self.profileRemove() {
                            self.writeToLog(theMessage: "Unable to remove included configuration profile")
                        }
                    }
                    if self.myExitCode(cmd: "/usr/local/jamf/bin/jamf", args: "mdm") == 0 {
                        self.writeToLog(theMessage: "Re-enabled MDM.")
                    }
                    exit(1)
                } else {
                    // passed health check, let's migrate
                    self.writeToLog(theMessage: "health check result: \(result[1]), looks good.")
                    
                    if !self.fm.fileExists(atPath: "/usr/local/jamf/bin/jamf") {
                        self.writeToLog(theMessage: "Existing jamf binary found: /usr/local/jamf/bin/jamf")
                        binaryExists = true
                    }
                    
                    // get jamf binary from new server and replace current binary - start
                    self.download(source: "\(self.newJssMgmtUrl)/bin/jamf.gz", destination: "/Library/Application%20Support/JAMF/ReEnroller/jamf.gz") {
                        (result: String) in
                        self.writeToLog(theMessage: "download result: \(result)")
                        
                        if ( "\(result)" == "binary downloaded" ) {
                            if self.fm.fileExists(atPath: "/Library/Application Support/JAMF/ReEnroller/jamf.gz") {
                                self.writeToLog(theMessage: "Downloaded jamf binary from new server (\(self.newJssMgmtUrl)).")
                                binaryDownloaded = true
                                if self.backup(operation: "move", source: self.origBinary, destination: self.bakBinary) {
                                    if self.myExitCode(cmd: "/bin/bash", args: "-c", "gunzip -f '/Library/Application Support/JAMF/ReEnroller/jamf.gz'") == 0 {
                                        do {
                                            try self.fm.moveItem(atPath: "/Library/Application Support/JAMF/ReEnroller/jamf", toPath: self.origBinary)
                                            self.writeToLog(theMessage: "Using jamf binary from the new server.")
                                            // set permissions to read and execute
                                            self.attributes[.posixPermissions] = 0o555
                                            // remove existing symlink to jamf binary if present
                                            if self.fm.fileExists(atPath: "/usr/local/bin/jamf") {
                                                try self.fm.removeItem(atPath: "/usr/local/bin/jamf")
                                            }
                                            // create new sym link to jamf binary
                                            if self.myExitCode(cmd: "/bin/bash", args: "-c", "ln -s /usr/local/jamf/bin/jamf /usr/local/bin/jamf") == 0 {
                                                self.writeToLog(theMessage: "Re-created alias for jamf binary in /usr/local/bin.")
                                            } else {
                                                self.writeToLog(theMessage: "Failed to re-created alias for jamf binary in /usr/local/bin.")
                                            }
                                            do {
                                                try self.fm.setAttributes(self.attributes, ofItemAtPath: self.origBinary)
                                            }
                                            if self.fm.fileExists(atPath: "/usr/local/jamf/bin/jamfAgent") {
                                                try self.fm.removeItem(atPath: "/usr/local/jamf/bin/jamfAgent")
                                            }
                                            binaryExists = true
                                        } catch {
                                            self.writeToLog(theMessage: "Unable to remove existing jamf binary, will rely on existing one.")
                                        }
                                    } else {
                                        self.writeToLog(theMessage: "Unable to unzip new jamf binary.")
                                    }
                                } else {
                                    self.writeToLog(theMessage: "Unable to backup existing jamf binary.")
                                }
                            }
                        }
                        
                        if binaryExists {
                            if !binaryDownloaded {
                                self.writeToLog(theMessage: "Failed to download new jamf binary.  Attempting migration with existing binary.")
                            }
                            self.writeToLog(theMessage: "Start backing up items.")
                            self.backupAndEnroll()
                        } else {
                            self.unverifiedFallback()
                            exit(1)
                        }
                    }  //self.download(source: - end
//                    } else {
//                        // jamf binary already exists - start backup and re-enrollment process
//                        self.backupAndEnroll()
//                    }
                    
                }   // passed health check, let's migrate - end
            }   // healthCheck(server: newJssMgmtUrl) - end
        }   // startMigrationQ.addOperation - end
    }   // func beginMigration() - end
    
    // backupAndEnroll - start
    func backupAndEnroll() {
        // backup existing jamf keychain - start
        if self.backup(operation: "copy", source: self.origKeychainFile, destination: self.bakKeychainFile) {
            self.writeToLog(theMessage: "Successfully backed up jamf keychain")
        } else {
            self.writeToLog(theMessage: "Failed to backup jamf keychain")
            self.unverifiedFallback()
            exit(1)
        }
        // backup existing jamf keychain - end
        
        // backup existing jamf plist, if it exists - start
        if self.backup(operation: "copy", source: self.jamfPlistPath, destination: self.bakjamfPlistPath) {
            self.writeToLog(theMessage: "Successfully backed up jamf plist")
        } else {
            self.writeToLog(theMessage: "Failed to backup jamf plist, rollback is not possible")
            //            unverifiedFallback()
            //            exit(1)
        }
        // backup existing jamf plist, if it exists - end
        
        // backup existing ConfigurationProfiles dir, if present - start
        if self.os.minorVersion < 13 {
            if self.backup(operation: "copy", source: self.origProfilesDir, destination: self.bakProfilesDir) {
                self.writeToLog(theMessage: "Successfully backed up current ConfigurationProfiles")
            } else {
                self.writeToLog(theMessage: "Failed to backup current ConfigurationProfiles")
                self.unverifiedFallback()
                exit(1)
            }
        } else {
            self.writeToLog(theMessage: "ConfigurationProfiles is not backed up on machines with High Sierra or later due to SIP.")
        }
        // backup existing ConfigurationProfiles dir, if present - end
        
        // rename management account if present - start
        
        // rename management account if present - end
        
        // Let's enroll
        self.enrollNewJps(newServer: self.newJssMgmtUrl, newInvite: self.theNewInvite) {
            (enrolled: String) in
            if ( enrolled == "failed" ) {
                self.unverifiedFallback()
                exit(1)
            } else {
                // Verify the enrollment
                self.verifyNewEnrollment()
            }
        }
        
        
        // verify cleanup
        self.verifiedCleanup(type: "full")
        exit(0)
    }
    // backupAndEnroll - end
    
    // backup up item - start
    func backup(operation: String, source: String, destination: String) -> Bool {
        var success = true
        let backupDate = getDateTime(x: 1)
        if fm.fileExists(atPath: source) {
            if !newEnrollment {
                if fm.fileExists(atPath: destination) {
                    do {
                        try fm.moveItem(atPath: destination, toPath: destination+"-"+backupDate)
                        writeToLog(theMessage: "Backed up existing, \(destination), to "+destination+"-"+backupDate)
                    } catch {
                        alert_dialog(header: "Alert", message: "Unable to rename existing item, \(destination).")
                        writeToLog(theMessage: "Failed to rename \(destination).")
                        success = false
                    }
                } else {
                    do {
                        switch operation {
                            case "move":
                                try fm.moveItem(atPath: source, toPath: destination)
                            case "copy":
                                try fm.copyItem(atPath: source, toPath: destination)
                            default: break
                        }
                        writeToLog(theMessage: "\(source) backed up to \(destination).")
                    } catch {
                        writeToLog(theMessage: "Unable to backup current item, \(source).")
                        success = false
                    }
                }
            } else {
                // delete existing item
                do {
                    try fm.removeItem(atPath: source)
                } catch {
                    writeToLog(theMessage: "Unable to backup current item, \(source).  Will continue to try and enroll.")
                }
            }
        } else {
            writeToLog(theMessage: "\(source), was not found - no backup created.")
        }
        return success
    }
    // backup item - end
    
    func connectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return (isReachable && !needsConnection)
    }
    
    @IBAction func downloadMdmRemoval(_ sender: Any) {
        if fm.fileExists(atPath: NSHomeDirectory()+"/Desktop/apiMDM_remove.txt") {
            do {
                try fm.moveItem(atPath: NSHomeDirectory()+"/Desktop/apiMDM_remove.txt", toPath: NSHomeDirectory()+"/Desktop/apiMDM_remove-"+getDateTime(x: 1)+".txt")
            } catch {
                alert_dialog(header: "Alert", message: "The script (apiMDM_remove.txt) already exists on your Desktop and we couldn't rename it.  Either delete/rename the file and download again or copy the script from Help.")
                return
            }
        }
        do {
            try fm.copyItem(atPath: myBundlePath+"/Contents/Resources/apiMDM_remove.txt", toPath: NSHomeDirectory()+"/Desktop/apiMDM_remove.txt")
            alert_dialog(header: "-Attention-", message: "The script (apiMDM_remove.txt) has been copied to your Desktop.")
        } catch {
            alert_dialog(header: "-Attention-", message: "Could not copy scipt to the Desktop.  Copy manually from Help.")
        }
    }
    
    
    func userOperation(mgmtUser: String, operation: String) -> String {
        var returnVal           = ""
        var userUuid            = ""
        let defaultAuthority    = CSGetLocalIdentityAuthority().takeUnretainedValue()
        let identityClass       = kCSIdentityClassUser
        
        let query = CSIdentityQueryCreate(nil, identityClass, defaultAuthority).takeRetainedValue()
        
        var error : Unmanaged<CFError>? = nil
        
        CSIdentityQueryExecute(query, 2, &error)
        
        let results = CSIdentityQueryCopyResults(query).takeRetainedValue()
        
        let resultsCount = CFArrayGetCount(results)
        
//        var allUsersArray = [String]()
        var allGeneratedUID = [String]()
        
        for idx in 0..<resultsCount {
            let identity    = unsafeBitCast(CFArrayGetValueAtIndex(results,idx),to: CSIdentity.self)
            let uuidString  = CFUUIDCreateString(nil, CSIdentityGetUUID(identity).takeUnretainedValue())
            allGeneratedUID.append(uuidString! as String)
            
            if let uuidNS = NSUUID(uuidString: uuidString! as String), let identityObject = CBIdentity(uniqueIdentifier: uuidNS as UUID, authority: CBIdentityAuthority.default()) {
                
                let regex = try! NSRegularExpression(pattern: "<CSIdentity(.|\n)*?>", options:.caseInsensitive)
                var trimmedIdentityObject = regex.stringByReplacingMatches(in: "\(identityObject)", options: [], range: NSRange(0..<"\(identityObject)".utf16.count), withTemplate: "")
                trimmedIdentityObject = trimmedIdentityObject.replacingOccurrences(of: " = ", with: " : ")
                trimmedIdentityObject = String(trimmedIdentityObject.dropFirst())
                trimmedIdentityObject = String(trimmedIdentityObject.dropLast())
                //        print("trimmed: \(trimmedIdentityObject)")
                let userAttribArray   = trimmedIdentityObject.split(separator: ",")
                
                let posixIdArray = userAttribArray.last!.split(separator: " ")
                let posixId = "\(String(describing: posixIdArray.last))"
                let username = identityObject.posixName
                userUuid = "\(identityObject.uniqueIdentifier)"
                
//                allUsersArray.append(username)
                if ( mgmtUser.lowercased() == username.lowercased() ) {
                    switch operation {
                    case "find":
                        returnVal = userUuid
                    case "id":
                        returnVal = posixId
                    default:
                        break
                    }   // switch operation - end
                }   // if ( mgmtUser.lowercased() == username.lowercased() ) - end
            }
        }
//        return allUsersArray
        return returnVal
    }
    
    func getDateTime(x: Int8) -> String {
        let date = Date()
        let date_formatter = DateFormatter()
        if x == 1 {
            date_formatter.dateFormat = "YYYYMMdd_HHmmss"
        } else {
            date_formatter.dateFormat = "E d MMM yyyy HH:mm:ss"
        }
        let stringDate = date_formatter.string(from: date)
        
        return stringDate
    }
    
    func getHost_getPort(theURL: String) -> (String, String) {
        var local_theHost = ""
        var local_thePort = ""

        var local_URL_array = theURL.components(separatedBy: ":")
        local_theHost = local_URL_array[0]

        if local_URL_array.count > 1 {
            local_thePort = local_URL_array[1]
        } else {
            local_thePort = "443"
        }
        // remove trailing / in url and port if present
        if local_theHost.substring(from: local_theHost.index(before: local_theHost.endIndex)) == "/" {
            local_theHost = local_theHost.substring(to: local_theHost.index(before: local_theHost.endIndex))
        }
        if local_thePort.substring(from: local_thePort.index(before: local_thePort.endIndex)) == "/" {
            local_thePort = local_thePort.substring(to: local_thePort.index(before: local_thePort.endIndex))
        }

        return(local_theHost, local_thePort)
    }
    
    // get verify SSL settings from new server - start
    func getSslVerify(action: String, endpoint: String, name: String, password: String, completion: @escaping (_ result: [Any]) -> Void) {
        URLCache.shared.removeAllCachedResponses()
        let safeCharSet  = CharacterSet.alphanumerics
        var responseData = ""
        var sslSetting   = ""
        
        let encodedUsername = name.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: safeCharSet)!
        
        let serverUrl = NSURL(string: "\(endpoint)")
        let serverRequest = NSMutableURLRequest(url: serverUrl! as URL)
        let body = "source=ReEnroller&username=\(encodedUsername)&password=\(encodedPassword)"
        
        serverRequest.httpMethod = "\(action)"
        serverRequest.httpBody = Data(body.utf8)
        let serverConf = URLSessionConfiguration.default
        serverConf.httpAdditionalHeaders = ["Content-Type" : "application/x-www-form-urlencoded"]
        
        let session = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: serverRequest as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if let _ = String(data: data!, encoding: .utf8) {
                    responseData = String(data: data!, encoding: .utf8)!
                    responseData = responseData.replacingOccurrences(of: "\n", with: "")
                    
                    if let start = responseData.range(of: "<verifySSLCert>"),
                        let end  = responseData.range(of: "</verifySSLCert>", range: start.upperBound..<(responseData.endIndex)) {
                        sslSetting.append((String(responseData[start.upperBound..<end.lowerBound])))
                    }   // let end  = responseMesage.range - end

                    print("response code: \(httpResponse.statusCode)")
//                    print("response: \(responseData)")
                    completion([httpResponse.statusCode,"\(sslSetting)"])
                } else {
                    print("No data was returned from health check.")
                    completion([httpResponse.statusCode,""])
                }
                
            } else {
                completion([404,""])
            }
        })
        task.resume()
        
    }
    // get verify SSL settings from new server - end

    // function to return exit code of bash command - start
    func myExitCode(cmd: String, args: String...) -> Int8 {
        //var pipe_pkg = Pipe()
        let task_pkg = Process()
        
        task_pkg.launchPath = cmd
        task_pkg.arguments = args
        //task_pkg.standardOutput = pipe_pkg
        //var test = task_pkg.standardOutput
        
        task_pkg.launch()
        task_pkg.waitUntilExit()
        let result = task_pkg.terminationStatus
        
        return(Int8(result))
    }
    // function to return exit code of bash command - end
    
    // function to return value of bash command - start
    func myExitValue(cmd: String, args: String...) -> [String] {
        var status  = [String]()
        let pipe    = Pipe()
        let task    = Process()
        
        task.launchPath     = cmd
        task.arguments      = args
        task.standardOutput = pipe
//        let outputHandle    = pipe.fileHandleForReading
        
        task.launch()
        
        let outdata = pipe.fileHandleForReading.readDataToEndOfFile()
        if var string = String(data: outdata, encoding: .utf8) {
            string = string.trimmingCharacters(in: .newlines)
            status = string.components(separatedBy: "\n")
        }
        
        task.waitUntilExit()
        
//        print("status: \(status)")
        return(status)
    }
    // function to return value of bash command - end
    
    // function to return mdm status - start
    func mdmInstalled(cmd: String, args: String...) -> Bool {
        var mdm = true
        var profileList = ""
        let mdmPipe    = Pipe()
        let mdmTask    = Process()
        
        mdmTask.launchPath     = cmd
        mdmTask.arguments      = args
        mdmTask.standardOutput = mdmPipe
        
        mdmTask.launch()
        mdmTask.waitUntilExit()
        
        let data = mdmPipe.fileHandleForReading.readDataToEndOfFile()
        profileList = String(data: data, encoding: String.Encoding.utf8)!
        
        writeToLog(theMessage: "profile list: \n\(String(describing: profileList))")
        
        let mdmCount = Int(profileList.trimmingCharacters(in: .whitespacesAndNewlines))!
        
        if mdmCount == 0 {
            mdm = false
        }
        return mdm
    }
        // function to mdm status - end
    
    func enrollNewJps(newServer: String, newInvite: String, completion: @escaping (_ enrolled: String) -> Void) {
        writeToLog(theMessage: "Starting the new enrollment.")
        
        if !newEnrollment {
            // remove mdm profile - start
            if os.minorVersion < 13 {
                if removeAllProfiles == "false" {
                    writeToLog(theMessage: "Attempting to remove mdm")
                    if myExitCode(cmd: "/usr/local/jamf/bin/jamf", args: "removemdmprofile") == 0 {
                        writeToLog(theMessage: "Removed old MDM profile")
                    } else {
                        writeToLog(theMessage: "There was a problem removing old MDM info. Falling back to old settings and Falling back to old settings and exiting!")
    //                    unverifiedFallback()
    //                    exit(1)
                        completion("failed")
                    }
                } else {
                    // os.minorVersion < 13 - remove all profiles
                    if myExitCode(cmd: "/bin/rm", args: "-fr", "/private/var/db/ConfigurationProfiles") == 0 {
                        writeToLog(theMessage: "Removed all configuration profiles")
                    } else {
                        writeToLog(theMessage: "There was a problem removing all configuration profiles. Falling back to old settings and Falling back to old settings and exiting!")
                        completion("failed")

                    }
                }
            } else {
                writeToLog(theMessage: "High Sierra (10.13) or later.  Checking MDM status.")
                var counter = 0
                // try to remove mdm with jamf command
                _ = myExitCode(cmd: "/usr/local/bin/jamf", args: "removemdmprofile")
                if !mdmInstalled(cmd: "/bin/bash", args: "-c", "/usr/bin/profiles -C | grep 00000000-0000-0000-A000-4A414D460003 | wc -l") {
                    writeToLog(theMessage: "Removed old MDM profile")
                } else {
                    writeToLog(theMessage: "Unable to remove MDM using the jamf binary, attempting remote command.")
                    while mdmInstalled(cmd: "/bin/bash", args: "-c", "/usr/bin/profiles -C | grep 00000000-0000-0000-A000-4A414D460003 | wc -l") {
                        counter+=1
                        _ = myExitCode(cmd: "/bin/bash", args: "-c", "killall jamf;/usr/local/bin/jamf policy -trigger apiMDM_remove")
                        sleep(10)
                        if counter > 6 {
                            writeToLog(theMessage: "Failed to remove MDM through remote command - exiting")
                            //                    unverifiedFallback()
                            //                    exit(1)
                            completion("failed")
                        } else {
                            writeToLog(theMessage: "Attempt \(counter) to remove MDM through remote command.")
                        }
                    }   // while mdmInstalled - end
                }

                if counter == 0 {
                    writeToLog(theMessage: "High Sierra (10.13) or later.  Checking MDM status shows no MDM.")
                } else {
                    writeToLog(theMessage: "High Sierra (10.13) or later.  MDM has been removed.")
                }
            }
            // remove mdm profile - end
        }
        
        // Install profile if present - start
        if !profileInstall() {
            completion("failed")
        }
        // Install profile if present - end
        
        // ensure we still have network connectivity - start
        var connectivityCounter = 0
        while !connectedToNetwork() {
            sleep(2)
            if connectivityCounter > 30 {
                writeToLog(theMessage: "There was a problem after removing old MDM configuration, network connectivity was lost. Will attempt to fall back to old settings and exiting!")
                //                    unverifiedFallback()
                //                    exit(1)
                completion("failed")
            }
            connectivityCounter += 1
            writeToLog(theMessage: "Waiting for network connectivity.")
        }
        // ensure we still have network connectivity - end
        
        // create a conf file for the new server
        writeToLog(theMessage: "Running: /usr/local/bin/jamf createConf -verifySSLCert \(createConfSwitches) -url \(newServer)")

        if myExitCode(cmd: "/usr/local/bin/jamf", args: "createConf", "-verifySSLCert", "\(createConfSwitches)", "-url", "\(newServer)") == 0 {
            writeToLog(theMessage: "Created JAMF config file for \(newServer)")
        } else {
            writeToLog(theMessage: "There was a problem creating JAMF config file for \(newServer). Falling back to old settings and exiting.")
            //                    unverifiedFallback()
            //                    exit(1)
            completion("failed")
        }

        // enroll with the new server using an invitation
        if myExitCode(cmd: "/usr/local/bin/jamf", args: "enroll", "-invitation", "\(newInvite)", "-noRecon", "-noPolicy", "-noManage") == 0 {
            writeToLog(theMessage: "/usr/local/bin/jamf enroll -invitation xxxxxxxx -noRecon -noPolicy -noManage")
            writeToLog(theMessage: "Enrolled to new Jamf Server: \(newServer)")
        } else {
            writeToLog(theMessage: "There was a problem enrolling to new Jamf Server: \(newServer). Falling back to old settings and exiting!")
//            writeToLog(theMessage: "/usr/local/bin/jamf enroll -invitation \(newInvite) -noRecon -noPolicy -noManage")
            //                    unverifiedFallback()
            //                    exit(1)
            completion("failed")
        }
        
        // verity connectivity to the new Jamf Pro server
        if myExitCode(cmd: "/usr/local/bin/jamf", args: "checkjssconnection") == 0 {
            writeToLog(theMessage: "checkjssconnection for \(newServer) was successful")
        } else {
            writeToLog(theMessage: "There was a problem checking the Jamf Server Connection to \(newServer). Falling back to old settings and exiting!")
            //                    unverifiedFallback()
            //                    exit(1)
            completion("failed")
        }
        
        // enable mdm
        if skipMdmCheck == "no" {
            if myExitCode(cmd: "/usr/local/bin/jamf", args: "mdm") == 0 {
                writeToLog(theMessage: "MDM Enrolled - getting MDM profiles from new JPS.")
            } else {
                writeToLog(theMessage: "There was a problem getting MDM profiles from new JPS.")
            }
            sleep(2)
        } else {
            writeToLog(theMessage: "Skipping MDM check.")
        }
        writeToLog(theMessage: "Calling jamf manage to update framework.")
        if myExitCode(cmd: "/usr/local/bin/jamf", args: "manage") == 0 {
            writeToLog(theMessage: "Enrolled - received management framework from new JPS.")
            completion("succeeded")
        } else {
            writeToLog(theMessage: "There was a problem getting management framework from new JPS. Falling back to old settings and exiting!")
            //                    unverifiedFallback()
            //                    exit(1)
            completion("failed")
        }
        
    }
    
    func profileInstall() -> Bool {
        if profileUuid != "" {
            if myExitCode(cmd: "/usr/bin/profiles", args: "-I", "-F", configProfilePath) == 0 {
                writeToLog(theMessage: "Installed config profile")
//                toggleWiFi()
                return true
            } else {
                writeToLog(theMessage: "There was a problem installing the config profile. Falling back to old settings and exiting!")
                return false
                //unverifiedFallback()
                //exit(1)
            }
        }
        return true
    }
    
    func profileRemove() -> Bool {
        if profileUuid != "" {
            // backup existing airport preferences plist - start
            if backup(operation: "copy", source: airportPrefs, destination: bakAirportPrefs) {
                writeToLog(theMessage: "Successfully backed up airport preferences plist")
            } else {
                writeToLog(theMessage: "Failed to backup airport preferences plist.")
                //            unverifiedFallback()
                //            exit(1)
            }
            // backup existing airport preferences plist - end
            
            // remove the manually added profile
            if myExitCode(cmd: "/usr/bin/profiles", args: "-R", "-p", profileUuid) == 0 {
                writeToLog(theMessage: "Configuration Profile was removed.")
                toggleWiFi()
                sleep(2)
                // verify we have connectivity - if not, try to add manual profile back
                var connectivityCounter = 1
                while !connectedToNetwork() && connectivityCounter < 56 {
                    if connectivityCounter == 2 {
                        do {
                            let plistURL = URL(string: "file:///Library/Application%20Support/JAMF/ReEnroller/profile.mobileconfig")
                            let ssid = stringFromPlist(plistURL: plistURL!, startString: "<key>SSID_STR</key><string>", endString: "</string><key>Interface</key><string>")
                            let ssidPwd = stringFromPlist(plistURL: plistURL!, startString: "<key>Password</key><string>", endString: "</string><key>EncryptionType</key>")
                            let encrypt = stringFromPlist(plistURL: plistURL!, startString: "<key>EncryptionType</key><string>", endString: "</string><key>AutoJoin</key>")
                            let en = myExitValue(cmd: "/bin/bash", args: "-c", "/usr/sbin/networksetup -listallhardwareports | grep -A1 Wi-Fi | grep Device | awk '{ print $2 }'")[0]

                            let _ = myExitCode(cmd: "/bin/bash", args: "-c", "/usr/sbin/networksetup -addpreferredwirelessnetworkatindex \(en) \"\(ssid)\" 0 \(encrypt) \"\(ssidPwd)\"")
                        } catch {
                            writeToLog(theMessage: "Problem extracting data from profile.")
                        }
                        // Add to keychain
                    }
                    
                    if (connectivityCounter % 15) == 0 {
                        writeToLog(theMessage: "No connectivity for 30 seconds, power cycling WiFi.")
                        toggleWiFi()
                    }
                    sleep(2)
                    connectivityCounter += 1
                    writeToLog(theMessage: "Waiting for network connectivity.")
                }
                if !connectedToNetwork() && connectivityCounter > 55 {
                    writeToLog(theMessage: "There was a problem after removing manually added MDM configuration, network connectivity could not be established without it. Will attempt to re-add and continue.")
                    if profileInstall() {
                        writeToLog(theMessage: "Manual profile has been re-installed.")
                    }
                    return false
                }   // if connectivityCounter - end
                return true
            } else {
                writeToLog(theMessage: "There was a problem removing the Configuration Profile.")
                return false
                //exit(1)
            }
        }
        return false
    }
    
    func toggleWiFi() {
        var interface = ""
        var power = ""
        
        // get Wi-Fi interface
        let interfaceArray = myExitValue(cmd: "/bin/bash", args: "-c", "/usr/sbin/networksetup -listallhardwareports | egrep -A 1 \"(Airport|Wi-Fi)\" | awk '/Device:/ { print $2 }'")
        if interfaceArray.count > 0 {
            interface = interfaceArray[0]
            
            // check airport power
            let powerArray = myExitValue(cmd: "/bin/bash", args: "-c", "/usr/sbin/networksetup -getairportpower \(interface) | awk -F': ' '{ print $2 }'")
            if powerArray.count > 0 {
                power = powerArray[0]
                
                if power == "On" {
                    if myExitCode(cmd: "/bin/bash", args: "-c", "/usr/sbin/networksetup -setairportpower \(interface) off") == 0 {
                        writeToLog(theMessage: "WiFi (\(interface)) has been turned off.")
                        usleep(100000)  // 0.1 seconds
                        if myExitCode(cmd: "/bin/bash", args: "-c", "/usr/sbin/networksetup -setairportpower \(interface) on") == 0 {
                            writeToLog(theMessage: "WiFi (\(interface)) has been turned on.")
                        }
                    }
                } else {
                    writeToLog(theMessage: "Note: Wi-Fi is currently disabled, not changing the setting.")
                }   // power == "On" - end
            }   // if powerArray.count - end
        }
    }
    
    func unverifiedFallback() {
        // only roll back if there is something to roll back to
        // add back in when ready to to use app on machines not currrently enrolled
        writeToLog(theMessage: "Alert - There was a problem with enrolling your Mac to the new Jamf Server URL at \(newJSSHostname):\(newJSSPort). We are rolling you back to the old Jamf Server URL at \(oldURL)")

        // restore backup jamf binary - start
        do {
            // check for existing jamf plist, remove if it exists
            if fm.fileExists(atPath: origBinary) && fm.fileExists(atPath: bakBinary) {
                do {
                    try fm.removeItem(atPath: origBinary)
                } catch {
                    writeToLog(theMessage: "Unable to remove jamf binary.")
                    //exit(1)
                }
            }
            if fm.fileExists(atPath: bakBinary) {
                try fm.moveItem(atPath: bakBinary, toPath: origBinary)
                writeToLog(theMessage: "Moved the backup jamf binary back into place.")
            }
        }
        catch let error as NSError {
            writeToLog(theMessage: "There was a problem moving the backup jamf binary back into place. Error: \(error)")
            //exit(1)
        }
        // restore backup jamf binary - end
        
        // restore original ConfigurationProfiles directory - start
        if os.minorVersion < 13 {
            if fm.fileExists(atPath: origProfilesDir) {
                do {
                    try fm.removeItem(atPath: origProfilesDir)
                    do {
                        try fm.moveItem(atPath: bakProfilesDir, toPath: origProfilesDir)
                    } catch {
                        writeToLog(theMessage: "There was a problem restoring original ConfigurationProfiles")
                    }
                } catch {
                    writeToLog(theMessage: "There was a problem removing original ConfigurationProfiles")
                }
            } else {
                if myExitCode(cmd: "/usr/local/bin/jamf", args: "manage") == 0 {
                    writeToLog(theMessage: "Restored the management framework/mdm from old JSS.")
                } else {
                    writeToLog(theMessage: "There was a problem restoring the management framework/mdm from old JSS.")
                }
            }
            if fm.fileExists(atPath: bakProfilesDir) {
                do {
                    try fm.moveItem(atPath: bakProfilesDir, toPath: origProfilesDir)
                    } catch {
                        writeToLog(theMessage: "There was a problem restoring original ConfigurationProfiles")
                    }
            }
        }
        // restore original ConfigurationProfiles directory - end
        
        // restore backup jamf keychain - start
        do {
            // check for existing jamf.keychain, remove if it exists
            if fm.fileExists(atPath: origKeychainFile)  && fm.fileExists(atPath: bakKeychainFile) {
                do {
                    try fm.removeItem(atPath: origKeychainFile)
                } catch {
                    writeToLog(theMessage: "Unable to remove jamf.keychain for new Jamf server")
                    //exit(1)
                }
            }
            if fm.fileExists(atPath: bakKeychainFile) {
                try fm.moveItem(atPath: bakKeychainFile, toPath: origKeychainFile)
                writeToLog(theMessage: "Moved the backup keychain back into place.")
            }
        }
        catch let error as NSError {
            writeToLog(theMessage: "There was a problem moving the backup keychain back into place. Error: \(error)")
            //exit(1)
        }
        // restore backup jamf keychain - end
        
        // restore backup jamf plist - start
        do {
            // check for existing jamf plist, remove if it exists
            if fm.fileExists(atPath: jamfPlistPath) && fm.fileExists(atPath: bakjamfPlistPath) {
                do {
                    try fm.removeItem(atPath: jamfPlistPath)
                } catch {
                    writeToLog(theMessage: "Unable to remove jamf plist.")
                    //exit(1)
                }
            }
            if fm.fileExists(atPath: bakjamfPlistPath) {
                try fm.moveItem(atPath: bakjamfPlistPath, toPath: jamfPlistPath)
                writeToLog(theMessage: "Moved the backup jamf plist back into place.")
            }
        }
        catch let error as NSError {
            writeToLog(theMessage: "There was a problem moving the backup jamf plist back into place. Error: \(error)")
            //exit(1)
        }
        // restore backup jamf plist - end
        
        // re-enable mdm management from old server on the system - start
        if myExitCode(cmd: "/usr/local/bin/jamf", args: "mdm") == 0 {
            writeToLog(theMessage: "MDM Enrolled - getting MDM profiles from old JSS.")
        } else {
            writeToLog(theMessage: "There was a problem getting MDM profiles from old JSS.")
        }
        // re-enable mdm management from old server on the system - end
        writeToLog(theMessage: "Exiting failback.")
        exit(1)
    }
    
    func verifyNewEnrollment() {
        for i in 1...5 {
            // test for a policy on the new Jamf Pro server and that it ran successfully
            let policyExitCode = myExitCode(cmd: "/usr/local/bin/jamf", args: "policy", "-trigger", "jpsmigrationcheck")
            sleep(20)
            if policyExitCode == 0 && fm.fileExists(atPath: verificationFile) {
                writeToLog(theMessage: "Verified migration with sample policy using jpsmigrationcheck trigger.")
                writeToLog(theMessage: "Policy created the check file.")
                return
            } else {
                writeToLog(theMessage: "Attempt \(i): There was a problem verifying migration with sample policy using jpsmigrationcheck trigger.")
                writeToLog(theMessage: "/usr/local/bin/jamf policy -trigger jpsmigrationcheck")
                writeToLog(theMessage: "Exit code: \(policyExitCode)")
                if i == 5 {
                    writeToLog(theMessage: "Falling back to old settings and exiting!")
                    unverifiedFallback()
                    exit(1)
                }
            }
        }   // for i in 1...10 - end
    }
    
    func verifiedCleanup(type: String) {
        if type == "full" {
            do {
                try fm.removeItem(atPath: bakBinary)
                writeToLog(theMessage: "Removed backup jamf binary.")
            }
            catch let error as NSError {
                writeToLog(theMessage: "There was a problem removing backup jamf binary.  Error: \(error)")
                //exit(1)
            }
            do {
                try fm.removeItem(atPath: bakKeychainFile)
                writeToLog(theMessage: "Removed backup jamf keychain.")
            }
            catch let error as NSError {
                writeToLog(theMessage: "There was a problem removing backup jamf keychain.  Error: \(error)")
                //exit(1)
            }
            do {
                try fm.removeItem(atPath: bakjamfPlistPath)
                writeToLog(theMessage: "Removed backup jamf plist.")
            }
            catch let error as NSError {
                writeToLog(theMessage: "There was a problem removing backup jamf plist.  Error: \(error)")
                //exit(1)
            }
            if os.minorVersion < 13 {
                do {
                    try fm.removeItem(atPath: bakProfilesDir)
                    writeToLog(theMessage: "Removed backup ConfigurationProfiles dir.")
                }
                catch let error as NSError {
                    writeToLog(theMessage: "There was a problem removing backup ConfigurationProfiles dir.  Error: \(error)")
                    //exit(1)
                }
            }
        
            // update inventory - start
            writeToLog(theMessage: "Launching Recon...")
            if myExitCode(cmd: "/usr/local/bin/jamf", args: "recon") == 0 {
                writeToLog(theMessage: "Submitting full recon to \(newJSSHostname):\(newJSSPort).")
                _ = myExitCode(cmd: "/usr/local/bin/jamf", args: "manage")
                sleep(10)
            } else {
                writeToLog(theMessage: "There was a problem submitting full recon to \(newJSSHostname):\(newJSSPort).")
                //exit(1)
            }
            do {
                if self.fm.fileExists(atPath: "/usr/local/bin/jamfAgent") {
                    try self.fm.removeItem(atPath: "/usr/local/bin/jamfAgent")
                }
                if self.myExitCode(cmd: "/bin/bash", args: "-c", "ln -s /usr/local/jamf/bin/jamfAgent /usr/local/bin/jamfAgent") == 0 {
                    self.writeToLog(theMessage: "Re-created alias for jamfAgent binary in /usr/local/bin.")
                } else {
                    self.writeToLog(theMessage: "Failed to re-created alias for jamfAgent binary in /usr/local/bin.")
                }
            } catch {
                if self.fm.fileExists(atPath: "/usr/local/bin/jamfAgent") {
                    self.writeToLog(theMessage: "Alias for jamfAgent binary in /usr/local/bin is ok.")
                } else {
                    self.writeToLog(theMessage: "Alias for jamfAgent binary in /usr/local/bin could not be created.")
                }
            }
            // update inventory - end
        
            // remove config profile if marked as such - start
            writeToLog(theMessage: "Checking if config profile removal is required...")
            if removeConfigProfile == "true" {
                if !profileRemove() {
                    writeToLog(theMessage: "Unable to remove configuration profile")
                }
            } else {
                writeToLog(theMessage: "Configuration profile is not marked for removal.")
            }
            // remove config profile if marked as such - end
        
            // run policy if marked to do so - start
            if postInstallPolicyId.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) != nil {
                writeToLog(theMessage: "There was a problem with the value for the policy id: \(postInstallPolicyId)")
            } else {
                if  postInstallPolicyId != "" {
                    writeToLog(theMessage: "Running policy id \(postInstallPolicyId)")
                    if myExitCode(cmd: "/usr/local/bin/jamf", args: "policy", "-id", "\(postInstallPolicyId)") == 0 {
                        writeToLog(theMessage: "Successfully called policy id \(postInstallPolicyId)")
                    } else {
                        writeToLog(theMessage: "There was an error calling policy id \(postInstallPolicyId)")
                        //exit(1)
                    }
                } else {
                    writeToLog(theMessage: "No post migration policy is set to be called.")
                }
            }
            // run policy if marked to do so - end
        
            // Remove ..JAMF/ReEnroller folder - start
            if removeReEnroller == "yes" {
                do {
                    try fm.removeItem(atPath: "/Library/Application Support/JAMF/ReEnroller")
                    writeToLog(theMessage: "Removed ReEnroller folder.")
                }
                catch let error as NSError {
                    writeToLog(theMessage: "There was a problem removing ReEnroller folder.  Error: \(error)")
                }
            } else {
                writeToLog(theMessage: "ReEnroller folder is left intact.")
            }
            // Remove ..JAMF/ReEnroller folder - end
        }   // if type == "full" - end
        
        // remove plist containing userDefaults, like the retryCount
        if fm.fileExists(atPath: "/private/var/root/Library/Preferences/com.jamf.pse.ReEnroller.plist") {
            do {
                try fm.removeItem(atPath: "/private/var/root/Library/Preferences/com.jamf.pse.ReEnroller.plist")
            } catch {
                writeToLog(theMessage: "Unable to remove /private/var/root/Library/Preferences/com.jamf.pse.ReEnroller.plist")
            }
        }
        userDefaults.set(1, forKey: "retryCount")
        
        
        // remove a previous launchd, if it exists, from /private/tmp
        if fm.fileExists(atPath: "/private/tmp/com.jamf.ReEnroller.plist") {
            do {
                try fm.removeItem(atPath: "/private/tmp/com.jamf.ReEnroller.plist")
            } catch {
                writeToLog(theMessage: "Unable to remove existing plist in /private/tmp")
            }
        }
        
        //  move and unload launchd to finish up.
        if fm.fileExists(atPath: "/Library/LaunchDaemons/com.jamf.ReEnroller.plist") {
            do {
                try fm.moveItem(atPath: "/Library/LaunchDaemons/com.jamf.ReEnroller.plist", toPath: "/private/tmp/com.jamf.ReEnroller.plist")
                writeToLog(theMessage: "Moved launchd to /private/tmp.")
                
                // unload the launchd
                if myExitCode(cmd: "/bin/launchctl", args: "unload", "/tmp/com.jamf.ReEnroller.plist") != 0 {
                    writeToLog(theMessage: "There was a problem unloading the launchd.")
                } else {
                    writeToLog(theMessage: "Launchd unloaded.")
                }
                
            } catch {
                writeToLog(theMessage: "Could not move launchd")
            }
        }
    }
    
    func alert_dialog(header: String, message: String) {
        let dialog: NSAlert = NSAlert()
        dialog.messageText = header
        dialog.informativeText = message
        dialog.alertStyle = NSAlert.Style.warning
        dialog.addButton(withTitle: "OK")
        dialog.runModal()
        //return true
    }   // func alert_dialog - end
    
    func apiAction(action: String, credentials: String, xml: String, endpoint: String, completion: @escaping (_ result: [Any]) -> Void) {
        URLCache.shared.removeAllCachedResponses()
        var responseData = ""
        
        let serverUrl = NSURL(string: "\(endpoint)")
        let serverRequest = NSMutableURLRequest(url: serverUrl! as URL)
        
        serverRequest.httpMethod = "\(action)"
        serverRequest.httpBody = Data(xml.utf8)
        let serverConf = URLSessionConfiguration.default
        serverConf.httpAdditionalHeaders = ["Authorization" : "Basic \(credentials)", "Content-Type" : "application/xml", "Accept" : "application/xml"]
        
        let session = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: serverRequest as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if let _ = String(data: data!, encoding: .utf8) {
                    responseData = String(data: data!, encoding: .utf8)!
                    responseData = responseData.replacingOccurrences(of: "\n", with: "")
                    print("response code: \(httpResponse.statusCode)")
                    print("response: \(responseData)")
                    completion([httpResponse.statusCode,"\(responseData)"])
                } else {
                    print("No data was returned from health check.")
                    completion([httpResponse.statusCode,""])
                }
                
            } else {
                completion([404,""])
            }
        })
        task.resume()
    }   // func apiAction - end
    
    func healthCheck(server: String, completion: @escaping (_ result: [String]) -> Void) {
        URLCache.shared.removeAllCachedResponses()
        var responseData = ""
        var healthCheckUrl = "\(server)/healthCheck.html"
        healthCheckUrl     = healthCheckUrl.replacingOccurrences(of: "//healthCheck.html", with: "/healthCheck.html")
        
        let serverUrl = NSURL(string: "\(healthCheckUrl)")
        let serverRequest = NSMutableURLRequest(url: serverUrl! as URL)
        
        serverRequest.httpMethod = "GET"
        let serverConf = URLSessionConfiguration.default
        
        self.writeToLog(theMessage: "Performing a health check against: \(healthCheckUrl)")
        let session = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
        let task = session.dataTask(with: serverRequest as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if let _ = String(data: data!, encoding: .utf8) {
                    responseData = String(data: data!, encoding: .utf8)!
                    responseData = responseData.replacingOccurrences(of: "\n", with: "")
                    responseData = responseData.replacingOccurrences(of: "\r", with: "")
                    self.writeToLog(theMessage: "healthCheck response code: \(httpResponse.statusCode)")
                    self.writeToLog(theMessage: "healthCheck response: \(responseData)")
                    completion(["\(httpResponse.statusCode)","\(responseData)"])
                } else {
                    self.writeToLog(theMessage: "No data was returned from health check.")
                    completion(["\(httpResponse.statusCode)",""])
                }
                
            } else {
                completion(["Unable to reach server.",""])
            }
        })
        task.resume()
    }
    
    // func download - start
    func download(source: String, destination: String, completion: @escaping (_ result: String) -> Void) {
        
        writeToLog(theMessage: "download URL: \(source)")

        // Location to store the file
        let destinationFileUrl:URL = URL(string: "file://\(destination)")!
        
        var filePath = "\(destinationFileUrl)"
        filePath = String(filePath.dropFirst(7))
        filePath = filePath.replacingOccurrences(of: "%20", with: " ")
        
        let exists = FileManager.default.fileExists(atPath: filePath)
        if exists {
            do {
                try FileManager.default.removeItem(atPath: filePath)
                writeToLog(theMessage: "removed existing file")
            } catch {
                writeToLog(theMessage: "failed to remove existing file")
                exit(0)
            }
        }
        
        //Create URL to the source file you want to download
        //        let fileURL = URL(string: "https://lhelou.jamfcloud.com/bin/SelfService.tar.gz")
        let fileURL = URL(string: "\(source)")
        
        let sessionConfig = URLSessionConfiguration.default
        let session = Foundation.URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        let request = URLRequest(url:fileURL!)
        
        URLCache.shared.removeAllCachedResponses()
        let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
            if let tempLocalUrl = tempLocalUrl, error == nil {
                // Success
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    self.writeToLog(theMessage: "Response from server - Status code: \(statusCode)")
                } else {
                    self.writeToLog(theMessage: "No response from the server.")
                    completion("No response from the server.")
                }
                
                switch (response as? HTTPURLResponse)?.statusCode {
                case 200:
                    self.writeToLog(theMessage: "File successfully downloaded.")
                case 401:
                    self.writeToLog(theMessage: "Authentication failed.")
                    completion("Authentication failed.")
                case 404:
                    self.writeToLog(theMessage: "server / file not found.")
                    completion("not found")
                default:
                    self.writeToLog(theMessage: "An error took place while downloading a file. Error description: \(String(describing: error!.localizedDescription))")
                    completion("unknown error")
                }
                
                do {
                    try FileManager.default.copyItem(at: tempLocalUrl, to: destinationFileUrl)
                } catch (let writeError) {
                    self.writeToLog(theMessage: "Error creating a file \(destinationFileUrl) : \(writeError)")
                    completion("Error creating file.")
                }

                completion("binary downloaded")
            } else {
                self.writeToLog(theMessage: "An error took place while downloading a file. Error description: \(String(describing: error!.localizedDescription))")
                completion("Error took place while downloading a file.")
            }
        }
        task.resume()
    }
    // func download - end
    
    func dropTrailingSlash(theSentString: String) -> String {
        var theString = theSentString
        if theString.substring(from: theString.index(before: theString.endIndex)) == "/" {
            theString = theString.substring(to: theString.index(before: theString.endIndex))
        }
        return theString
    }
    
    func stringFromPlist(plistURL: URL, startString: String, endString: String) -> String {
        writeToLog(theMessage: "reading from \(plistURL)")
        var xmlValue = ""
        do {
            let one = try String(contentsOf: plistURL, encoding: String.Encoding.ascii).components(separatedBy: endString)
            let _string = one[0].components(separatedBy: startString)
            xmlValue = _string[1]
        } catch {
            writeToLog(theMessage: "unable to read file")
        }
        return xmlValue
    }
    
    func writeToLog(theMessage: String) {
        LogFileW?.seekToEndOfFile()
        let fullMessage = getDateTime(x: 2) + " [ReEnroller]:    " + theMessage + "\n"
        let LogText = (fullMessage as NSString).data(using: String.Encoding.utf8.rawValue)
        LogFileW?.write(LogText!)
    }
    
    // quit the app if the window is closed - start
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        return true
    }
    // quit the app if the window is closed - end
    
    func applicationWillFinishLaunching(_ notification: Notification) {

        let appInfo = Bundle.main.infoDictionary!
        let version = appInfo["CFBundleShortVersionString"] as! String
        
        LogFileW = FileHandle(forUpdatingAtPath: (logFilePath))
        
        retryCount = userDefaults.integer(forKey: "retryCount")
        
        var isDir: ObjCBool = true
        if !fm.fileExists(atPath: "/usr/local/jamf/bin", isDirectory: &isDir) {
            do {
                try fm.createDirectory(atPath: "/usr/local/jamf/bin", withIntermediateDirectories: true, attributes: nil)
                NSLog("Created jamf binary directory: /usr/local/jamf/bin")
            } catch {
                NSLog("failed to create jamf binary directory")
            }
        }
        if !fm.fileExists(atPath: "/usr/local/bin", isDirectory: &isDir) {
            do {
                try fm.createDirectory(atPath: "/usr/local/bin", withIntermediateDirectories: true, attributes: nil)
                NSLog("Created binary directory: /usr/local/bin")
            } catch {
                NSLog("failed to create /usr/local/bin directory")
            }
        }
        
        // create jamf log file if not present
        if !fm.fileExists(atPath: logFilePath) {
            print("create /private/var/log/jamf.log")
            let _ = fm.createFile(atPath: logFilePath, contents: nil, attributes: [FileAttributeKey(rawValue: "ownerAccountID"):0, FileAttributeKey(rawValue: "groupOwnerAccountID"):80, FileAttributeKey(rawValue: "posixPermissions"):0o755])
        }
        
        var basePlistPath = myBundlePath
        // remove /ReEnroller.app from the basePlistPath to get path to folder
        basePlistPath = basePlistPath.substring(to: basePlistPath.index(basePlistPath.startIndex, offsetBy: (basePlistPath.count-15)))

        let settingsFile = basePlistPath+"/settings.plist"
        
        //print("path to configured settings file: \(settingsFile)")
        if fm.fileExists(atPath: settingsFile) {
            // hide the icon from the Dock when running
            //NSApplication.shared().setActivationPolicy(NSApplicationActivationPolicy.prohibited)
            print("read settings from: \(settingsFile)")
            
            let settingsPlistXML = fm.contents(atPath: settingsFile)!
            do{
                writeToLog(theMessage: "Reading settings from: \(settingsFile)")
                plistData = try PropertyListSerialization.propertyList(from: settingsPlistXML,
                                                                       options: .mutableContainersAndLeaves,
                                                                       format: &format)
                    as! [String : AnyObject]
            }
            catch{
                writeToLog(theMessage: "Error reading plist: \(error), format: \(format)")
            }
            
            // read new enrollment setting
            if plistData["newEnrollment"] != nil {
                newEnrollment = plistData["newEnrollment"] as! Bool
            } else {
                newEnrollment = false
            }
            writeToLog(theMessage: "================================")
            writeToLog(theMessage: "ReEnroller Version: \(version)")
            writeToLog(theMessage: "================================")
            writeToLog(theMessage: "New enrollment: \(newEnrollment)")
            
            
            // read max retries setting
            // maxRetries was written as a string so it's value could be nil
            if plistData["maxRetries"] != nil {
                maxRetries = Int(plistData["maxRetries"] as! String)!
            } else {
                maxRetries = -1
            }
            writeToLog(theMessage: "Maximum number of retries: \(maxRetries)")
            
            if plistData["newJSSHostname"] != nil && plistData["newJSSPort"] != nil && plistData["theNewInvite"] != nil {
                writeToLog(theMessage: "Found configuration for new Jamf Pro server: \(String(describing: plistData["newJSSHostname"]!)), begin migration")
                
                // Parameters for the new emvironment
                newJSSHostname = plistData["newJSSHostname"]! as! String
                newJSSPort = plistData["newJSSPort"]! as! String

                theNewInvite = plistData["theNewInvite"]! as! String
                newJssMgmtUrl = "https://\(newJSSHostname):\(newJSSPort)"
                writeToLog(theMessage: "newServer: \(newJSSHostname)\nnewPort: \(newJSSPort)")
                
                // read management account
                if plistData["mgmtAccount"] != nil {
                    mgmtAccount = plistData["mgmtAccount"]! as! String
                }
                
                // read config profile vars
                if plistData["profileUUID"] != nil {
                    profileUuid = plistData["profileUUID"]! as! String
                    writeToLog(theMessage: "UDID of included profile is: \(profileUuid)")
                } else {
                    writeToLog(theMessage: "No configuration profiles included for install.")
                }
                if plistData["removeProfile"] != nil {
                    removeConfigProfile = plistData["removeProfile"]! as! String
                }
                if plistData["removeAllProfiles"] != nil {
                    removeAllProfiles = plistData["removeAllProfiles"]! as! String
                }
                if plistData["removeReEnroller"] != nil {
                    removeReEnroller = plistData["removeReEnroller"]! as! String
                }
                if plistData["createConfSwitches"] != nil {
                    createConfSwitches = plistData["createConfSwitches"]! as! String
                }
                if plistData["skipMdmCheck"] != nil {
                    skipMdmCheck = plistData["skipMdmCheck"]! as! String
                }
                if plistData["postInstallPolicyId"] != nil {
                    postInstallPolicyId = plistData["postInstallPolicyId"]! as! String
                }
                
                
                // look for an existing jamf plist file
                if fm.fileExists(atPath: jamfPlistPath) {
                    // need to convert jamf plist to xml (plutil -convert xml1 some.plist)
                    if myExitCode(cmd: "/usr/bin/plutil", args: "-convert", "xml1", jamfPlistPath) != 0 {
                        writeToLog(theMessage: "Unable to read current jamf configuration.  It is either corrupt or client is not enrolled.")
                        //exit(1)
                    } else {
                    
                        let plistXML = FileManager.default.contents(atPath: jamfPlistPath)!
                        do{
                            jamfPlistData = try PropertyListSerialization.propertyList(from: plistXML,
                                                                                       options: .mutableContainersAndLeaves,
                                                                                       format: &format)
                                as! [String:AnyObject]
                        } catch {
                            writeToLog(theMessage: "Error reading plist: \(error), format: \(format)")
                        }
                        if jamfPlistData["jss_url"] != nil {
                            oldURL = jamfPlistData["jss_url"]! as! String
                        }
                        writeToLog(theMessage: "Found old Jamf Pro server: \(oldURL)")
                        // convert the jamf plist back to binary (plutil -convert binary1 some.plist)
                        if myExitCode(cmd: "/usr/bin/plutil", args: "-convert", "binary1", jamfPlistPath) != 0 {
                            writeToLog(theMessage: "There was an error converting the jamf.plist back to binary")
                        }
                    }
                } else {
                    oldURL = ""
                    if !newEnrollment {
                        writeToLog(theMessage: "Machine is not currently enrolled, exitting.")
                        exit(0)
                    } else {
                        writeToLog(theMessage: "Machine is not currently enrolled, starting new enrollment.")
                    }
                }
                
                beginMigration()
            } else {
                writeToLog(theMessage: "Configuration not found, launching GUI.")
                
                showReenroll_fn(self)
                retry_TextField.stringValue = "30"
                newEnrollment_Button.state = convertToNSControlStateValue(0)
                removeReEnroller_Button.state = convertToNSControlStateValue(1)
                rndPwdLen_TextField?.isEnabled = false
                rndPwdLen_TextField?.stringValue = "8"
                
                ReEnroller_window.backgroundColor = NSColor(red: 0x9F/255.0, green:0xB9/255.0, blue:0xCC/255.0, alpha: 1.0)
                NSApplication.shared.setActivationPolicy(NSApplication.ActivationPolicy.regular)
                ReEnroller_window.setIsVisible(true)
            }
            
        } else {
            writeToLog(theMessage: "Configuration not found, launching GUI.")
            
            showReenroll_fn(self)
            retry_TextField.stringValue = "30"
            newEnrollment_Button.state = convertToNSControlStateValue(0)
            removeReEnroller_Button.state = convertToNSControlStateValue(1)
            rndPwdLen_TextField?.isEnabled = false
            rndPwdLen_TextField?.stringValue = "8"

            // [NSColor colorWithCalibratedRed:0x6C/255.0 green:0x82/255.0 blue:0x94/255.0 alpha:0xFF/255.0]/* 6C8294FF */
//            ReEnroller_window.backgroundColor = NSColor(red: 0x9F/255.0, green:0xB9/255.0, blue:0xCC/255.0, alpha: 1.0)
            ReEnroller_window.backgroundColor = NSColor(red: 0x6c/255.0, green:0x82/255.0, blue:0x94/255.0, alpha: 1.0)
            NSApplication.shared.setActivationPolicy(NSApplication.ActivationPolicy.regular)
            ReEnroller_window.setIsVisible(true)
        }
        
    }
    
//    --------------------------------------- grab sites - start ---------------------------------------
        func getSites(completion: @escaping (Dictionary<String, Int>) -> Dictionary<String, Int>) {
        var local_allSites = Dictionary<String, Int>()
        
        let serverEncodedURL = NSURL(string: resourcePath)
        let serverRequest = NSMutableURLRequest(url: serverEncodedURL! as URL)
        //        print("serverRequest: \(serverRequest)")
        serverRequest.httpMethod = "GET"
        let serverConf = URLSessionConfiguration.default
        serverConf.httpAdditionalHeaders = ["Authorization" : "Basic \(jssCredsBase64)", "Content-Type" : "application/json", "Accept" : "application/json"]
        let serverSession = Foundation.URLSession(configuration: serverConf, delegate: self, delegateQueue: OperationQueue.main)
        let task = serverSession.dataTask(with: serverRequest as URLRequest, completionHandler: {
            (data, response, error) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                // print("httpResponse: \(String(describing: response))")
                do {
                    let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                    //                    print("\(json)")
                    if let endpointJSON = json as? [String: Any] {
                        if let siteEndpoints = endpointJSON["sites"] as? [Any] {
                            let siteCount = siteEndpoints.count
                            if siteCount > 0 {
                                for i in (0..<siteCount) {
                                    // print("site \(i): \(siteEndpoints[i])")
                                    let theSite = siteEndpoints[i] as! [String:Any]
                                    // print("theSite: \(theSite))")
                                    // print("site \(i) name: \(String(describing: theSite["name"]))")
                                    let theSiteName = theSite["name"] as! String
                                    local_allSites[theSiteName] = theSite["id"] as? Int
                                }
                            }
                        }
                    }   // if let serverEndpointJSON - end
                    
                } catch {
                    print("[- debug -] Existing endpoints: error serializing JSON: \(error)\n")
                }   // end do/catch
                
                if httpResponse.statusCode >= 199 && httpResponse.statusCode <= 299 {
                    //print(httpResponse.statusCode)
                    
                    self.site_Button.isEnabled = true
                    completion(local_allSites)
                } else {
                    // something went wrong
                    print("status code: \(httpResponse.statusCode)")
                        self.alert_dialog(header: "Alert", message: "Unable to look up Sites.  Verify the account being used is able to login and view Sites.\nStatus Code: \(httpResponse.statusCode)")
                    
                    self.enableSites_Button.state = convertToNSControlStateValue(0)
                    self.site_Button.isEnabled = false
                    completion([:])
                    
                }   // if httpResponse/else - end
            }   // if let httpResponse - end
            //            semaphore.signal()
        })  // let task = - end
        task.resume()
    }
//    --------------------------------------- grab sites - end ---------------------------------------
    
    func removeTag(xmlString: String) -> String {
        let newString = xmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
        return newString
    }
    
    func xmlEncode(rawString: String) -> String {
        var encodedString = rawString
        encodedString     = encodedString.replacingOccurrences(of: "&", with: "&amp;")
        encodedString     = encodedString.replacingOccurrences(of: "\"", with: "&quot;")
        encodedString     = encodedString.replacingOccurrences(of: "'", with: "&apos;")
        encodedString     = encodedString.replacingOccurrences(of: ">", with: "&gt;")
        encodedString     = encodedString.replacingOccurrences(of: "<", with: "&lt;")
        return encodedString
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        // bring app to the foreground
        jssUrl_TextField.becomeFirstResponder()
        
        // set tab order for text fields
        jssUrl_TextField.nextKeyView      = jssUsername_TextField
        jssUsername_TextField.nextKeyView = jssPassword_TextField
        jssPassword_TextField.nextKeyView = mgmtAccount_TextField
        mgmtAccount_TextField.nextKeyView = mgmtAcctPwd_TextField
        mgmtAcctPwd_TextField.nextKeyView = mgmtAcctPwd2_TextField

        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToNSControlStateValue(_ input: Int) -> NSControl.StateValue {
	return NSControl.StateValue(rawValue: input)
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromOptionalNSUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier?) -> String? {
	guard let input = input else { return nil }
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSControlStateValue(_ input: NSControl.StateValue) -> Int {
	return input.rawValue
}

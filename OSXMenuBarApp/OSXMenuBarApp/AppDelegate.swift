//
//  AppDelegate.swift
//  OSXMenuBarApp
//
//  Created by Keli C. Fancher (kcfancher.com, keisi.co) on 3/23/16.
//  Copyright © 2016 Authority Labs. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    @IBOutlet weak var apiKeyTextField: NSTextField!
    
    let statusItem = NSStatusBar.systemStatusBar().statusItemWithLength(NSSquareStatusItemLength)

    let runNow = NSMenuItem(title: "Run Now", action: #selector(AppDelegate.runNowHandler), keyEquivalent: "")
    let toggleSchedule = NSMenuItem(title: "Start Running", action: #selector(AppDelegate.startScheduledScript), keyEquivalent: "")
    let nextRunTime = NSMenuItem(title: "Will Run In 59m", action: nil, keyEquivalent: "")
    let separator = NSMenuItem.separatorItem()
    let configureAPIKey = NSMenuItem(title: "Configure API Key", action: #selector(AppDelegate.openConfigureAPIKeyWindow), keyEquivalent: "")
    let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
    
    
    let repeatIntervalInSeconds = 3600.0
    var scheduleTimer: NSTimer?
    var lastRanTime: NSDate?
    var apiKeyConfigured: Bool { get { return currentAPIKey != nil } }
    
    var scheduled: Bool = false {
        didSet {
            if scheduled {
                toggleSchedule.title = "Stop Running Every Hour"
                toggleSchedule.action = #selector(AppDelegate.stopScheduledScript)
            } else {
                toggleSchedule.title = "Run Every Hour"
                toggleSchedule.action = #selector(AppDelegate.startScheduledScript)
            }
        }
    }

    var running: Bool = false {
        didSet {
            refreshNextRunTime()
            if running {
                statusItem.image = NSImage(named: "StatusBarIcon_Running")
                runNow.action = nil
            } else {
                statusItem.image = NSImage(named: "StatusBarIcon")
                runNow.action = #selector(AppDelegate.runNowHandler)
            }
        }
    }
    
    var currentAPIKey: String? {
        get {
            return NSUserDefaults.standardUserDefaults().stringForKey("API_KEY")
        }
        set {
            NSUserDefaults.standardUserDefaults().setValue(newValue, forKey: "API_KEY")
        }
    }
    
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        statusItem.image = NSImage(named: "StatusBarIcon")
        statusItem.target = self
        statusItem.action = #selector(AppDelegate.statusMenuDidOpen)
        
        if apiKeyConfigured {
            startScheduledScript()
        }
    }
    
    func refreshNextRunTime() {
        if running {
            nextRunTime.title = "Running..."
        } else if let timer = scheduleTimer where scheduled {
            let secondsRemaining = Int(timer.fireDate.timeIntervalSinceNow)
            nextRunTime.title = "Will Run in \(secondsRemaining/60)m"
        }
    }
    
    func statusMenuDidOpen() {
        let menu = NSMenu()
        
        if apiKeyConfigured {
            if running || scheduled {
                refreshNextRunTime()
                menu.addItem(nextRunTime)
            }
            menu.addItem(toggleSchedule)
            menu.addItem(runNow)
            menu.addItem(configureAPIKey)
            menu.addItem(separator)
            menu.addItem(quit)
        } else {
            menu.addItem(configureAPIKey)
            menu.addItem(separator)
            menu.addItem(quit)
        }
        
        statusItem.popUpStatusItemMenu(menu)
    }
    
    func stopScheduledScript() {
        scheduleTimer?.invalidate()
        scheduleTimer = nil
        
        scheduled = false
    }
    
    func startScheduledScript() {
        guard !scheduled else { return }

        runScriptOnBackgroundThread()
        scheduleTimer = NSTimer()
        scheduleTimer = NSTimer.scheduledTimerWithTimeInterval(repeatIntervalInSeconds, target: self, selector: #selector(AppDelegate.runScriptOnBackgroundThread), userInfo: nil, repeats: true)
        
        scheduled = true
    }
    
    func openConfigureAPIKeyWindow() {
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
        apiKeyTextField.stringValue = currentAPIKey ?? ""
        window.makeKeyAndOrderFront(self)
    }
    
    @IBAction func saveAPIKey(sender: AnyObject) {
        currentAPIKey = apiKeyTextField.stringValue
        window.orderOut(self)
    }
    
    func runNowHandler() {
        if scheduled {
            stopScheduledScript()
        }
        
        runScriptOnBackgroundThread()
    }
    
    func runScriptOnBackgroundThread() {
        guard let scriptPath = NSBundle.mainBundle().pathForResource("speedtest_cli3", ofType: "py") else { return }
        guard let apiKey = currentAPIKey else { return }
            
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
            [unowned self] in
            
            self.running = true
            let task = NSTask()
            task.launchPath = "/usr/bin/python"
            task.arguments = [scriptPath, "--apikey", apiKey]
            task.launch()
            task.waitUntilExit()
            
            self.lastRanTime = NSDate()
            self.running = false
        }
    }
}


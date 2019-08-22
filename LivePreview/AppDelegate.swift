//
//  AppDelegate.swift
//  LivePreview
//
//  Created by David Rothschild on 1/1/17.
//  Copyright © 2017 Dave Rothschild. All rights reserved.
//

import UIKit

import SwiftyStoreKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
static let SIDF = "com.imageapp.live_1.99"
    static let SS = "6d6aa2e6911543de9ccc764a5747d40c"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                switch purchase.transaction.transactionState {
                case .purchased, .restored:
                    if purchase.needsFinishTransaction {
                        // Deliver content from server, then:
                        SwiftyStoreKit.finishTransaction(purchase.transaction)
                    }
                // Unlock content
                case .failed, .purchasing, .deferred:
                    break // do nothing
                }
            }
        }
        if let value = UserDefaults.standard.value(forKey: "subscription_id") {
            if let sub = value as? String {
                self.varifyPurchase(Product: sub)
            }
        }
        return true
    }
    
    func varifyPurchase(Product productId:String){
        
        let appleValidator = AppleReceiptValidator(service: .production, sharedSecret: AppDelegate.SS)
        
        SwiftyStoreKit.verifyReceipt(using: appleValidator) { result in
            switch result {
            case .success(let receipt):
                
                // Verify the purchase of Consumable or NonConsumable
                let purchaseResult = SwiftyStoreKit.verifyPurchase(
                    productId: productId,
                    inReceipt: receipt)
                
                switch purchaseResult {
                case .purchased(let receiptItem):
                    //Show Dilog message from here\
                    
                    print("\(productId) is purchased: \(receiptItem)")
                    
                    if productId.elementsEqual(AppDelegate.SIDF)   {
                        
                        if let expData = receiptItem.subscriptionExpirationDate {
                            guard let nextDate = Calendar.current.date(byAdding: .month, value: 1, to: expData) else {
                                return
                            }
                            if nextDate < Date() {
                                UserDefaults.standard.set(false, forKey: "subscribed")
                                UserDefaults.standard.synchronize()
                            } else {
                                UserDefaults.standard.set(true, forKey: "subscribed")
                                UserDefaults.standard.synchronize()
                                NotificationCenter.default.post(Notification.init(name: Notification.Name(rawValue: "remove_ad_notification")))
                            }
                            
                        }
                    }
                case .notPurchased:
                    print("The user has never purchased \(productId)")
                }
            case .error(let error):
                print("Receipt verification failed: \(error)")
            }
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}


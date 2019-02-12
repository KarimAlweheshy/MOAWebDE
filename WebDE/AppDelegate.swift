//
//  AppDelegate.swift
//  WebDE
//
//  Created by Karim Alweheshy on 2/8/19.
//  Copyright © 2019 Karim Alweheshy. All rights reserved.
//

import UIKit
import Payment
import UserManagement
import Email
import Networking

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    fileprivate lazy var networking: Networking = {
        let networking = Networking()
        networking.presentationBlock = presentationBlock
        networking.dismissBlock = { $0.dismiss(animated: true, completion: $1) }
        
        networking.register(module: EmailModule.self)
        networking.register(module: UserManagementModule.self)
        networking.register(module: PaymentModule.self)
        
        return networking
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow()
        window?.makeKeyAndVisible()
        
        let tabController = UITabBarController()
        window?.rootViewController = tabController
        
        let payRequest = PaymentPayRequest(data: PaymentPayRequestBody(amount: nil))
        
        networking.execute(request: payRequest,
                           presentationBlock: addToTabBar,
                           dismissBlock: nil,
                           completionHandler: { (result: Result<PaymentResponse>) in
            self.window?.rootViewController = UINavigationController()
        })
        
        let emailRequest = EmailListRequest(data: EmailListRequestBody(filters: [String : String]()))
        
        networking.execute(request: emailRequest,
                           presentationBlock: addToTabBar,
                           dismissBlock: nil,
           completionHandler: { (result: Result<EmailResponse>) in
            self.window?.rootViewController = UINavigationController()
        })

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
    }

    func applicationWillTerminate(_ application: UIApplication) {
    }


}

extension AppDelegate {
    fileprivate func presentationBlock(viewController: UIViewController,
                                       completionHandler: (() -> Void)?) {
        let presentedViewController = viewController is UINavigationController ? viewController : UINavigationController(rootViewController: viewController)
        
        if let rootViewController = self.window?.rootViewController {
            func topViewController(viewController: UIViewController) -> UIViewController {
                if let viewController = viewController as? UINavigationController, let topMostViewController = viewController.topViewController {
                    return topViewController(viewController: topMostViewController)
                } else if let viewController = viewController as? UITabBarController,
                    let topMostViewController = viewController.viewControllers?[viewController.selectedIndex] {
                    return topViewController(viewController: topMostViewController)
                }
                return viewController.presentedViewController ?? viewController
            }
            
            topViewController(viewController: rootViewController).present(presentedViewController, animated: true, completion: completionHandler)
        } else {
            self.window?.rootViewController = presentedViewController
            completionHandler?()
        }
    }
    
    fileprivate func addToTabBar(_ viewController: UIViewController,
                                 completionHandler: (() -> Void)?) {
        guard let tabController = window?.rootViewController as? UITabBarController else {
            completionHandler?()
            return
        }
        
        let navigationController = UINavigationController(rootViewController: viewController)
        
        var viewControllers = tabController.viewControllers ?? [UIViewController]()
        viewControllers.append(navigationController)
        tabController.viewControllers = viewControllers
        
        completionHandler?()
    }

}


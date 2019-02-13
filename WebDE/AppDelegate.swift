//
//  AppDelegate.swift
//  WebDE
//
//  Created by Karim Alweheshy on 2/8/19.
//  Copyright © 2019 Karim Alweheshy. All rights reserved.
//

import UIKit
import class Payment.Module
import class UserManagement.Module
import class Email.Module
import Networking

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    fileprivate lazy var networking: Networking = Networking(modules: [Email.Module.self,
                                                           Payment.Module.self,
                                                           UserManagement.Module.self],
                                                 presentationBlock: presentationBlock,
                                                 dismissBlock: {
                                                    $0.dismiss(animated: true, completion: nil)
    })

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow()
        window?.makeKeyAndVisible()
        
        let tabController = UITabBarController()
        window?.rootViewController = tabController
        
        let payRequest = PaymentPayRequest(data: PaymentPayRequestBody(amount: nil))
        
        networking.execute(request: payRequest,
                           presentationBlock: addToTabBar,
                           dismissBlock: { _ in },
                           completionHandler: { (result: Result<PaymentResponse>) in
            self.window?.rootViewController = UINavigationController()
        })
        
        let emailRequest = EmailListRequest(data: EmailListRequestBody(filters: [String : String]()))
        
        networking.execute(request: emailRequest,
                           presentationBlock: addToTabBar,
                           dismissBlock: { _ in },
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
    fileprivate func presentationBlock(viewController: UIViewController) {
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
            
            let presentingViewController = topViewController(viewController: rootViewController)
            presentingViewController.present(presentedViewController,
                                             animated: true,
                                             completion: nil)
        } else {
            self.window?.rootViewController = presentedViewController
        }
    }
    
    fileprivate func addToTabBar(_ viewController: UIViewController) {
        guard let tabController = window?.rootViewController as? UITabBarController else {
            return
        }
        
        let navigationController = UINavigationController(rootViewController: viewController)
        
        var viewControllers = tabController.viewControllers ?? [UIViewController]()
        viewControllers.append(navigationController)
        tabController.viewControllers = viewControllers
    }

}


//
//  Networking.swift
//  WebDE
//
//  Created by Karim Alweheshy on 2/11/19.
//  Copyright © 2019 Karim Alweheshy. All rights reserved.
//

import UIKit
import Networking

final class Networking: NetworkingType {
    
    var presentationBlock: ((UIViewController, (() -> Void)?) -> Void)? = nil
    var dismissBlock: ((UIViewController, (() -> Void)?) -> Void)? = nil
    
    fileprivate var modules = [Module.Type]()
    fileprivate let remoteHost = "google"
    fileprivate var urlSession: URLSession
    fileprivate var isAuthorized = false
    
    public init(configuration: URLSessionConfiguration = .default) {
        urlSession = URLSession(configuration: configuration)
    }
    
    public func register(module: Module.Type) {
        modules.append(module)
    }
    
    func execute<T>(request: InternalRequest, completionHandler: @escaping (Result<T>) -> Void) where T : Decodable, T : Encodable {
        execute(request: request, presentationBlock: presentationBlock, dismissBlock: dismissBlock, completionHandler: completionHandler)
    }
    
    public func execute<T>(request: InternalRequest,
                           presentationBlock: ((UIViewController, (() -> Void)?) -> Void)?,
                           dismissBlock: ((UIViewController, (() -> Void)?) -> Void)?,
                           completionHandler: @escaping (Result<T>) -> Void) where T : Decodable, T : Encodable {
        
        // Safe guard the expected response type of a request
        guard T.self == type(of: request).responseType else {
            completionHandler(.error(ResponseError.badRequest400(error: nil)))
            return
        }
        
        let executableModules = modules.filter { $0.Facade.contains(request: request) }
        
        guard !executableModules.isEmpty else {
            completionHandler(.error(ResponseError.other400(error: nil)))
            return
        }
        
        executableModules.forEach {
            $0.execute(networking: self, presentationBlock: presentationBlock ?? self.presentationBlock,
                       dismissBlock: dismissBlock ?? self.dismissBlock,
                       request: request) { (result: Result<T>) in
                        switch result {
                        case .success: completionHandler(result)
                        case .error(let error):
                            if let error = error as? ResponseError, error.errorCode == 401 {
                                // Authorize and re-login
                                let requestBody = ExplicitLoginRequestBody(email: nil, password: nil)
                                let authRequest = ExplicitLoginRequest(data: requestBody)
                                self.execute(request: authRequest,
                                             presentationBlock: self.presentationBlock,
                                             dismissBlock: self.dismissBlock) { (result: Result<AuthenticationResponse>) in
                                                switch result {
                                                case .success(let authentication):
                                                    self.updateSession(authToken: authentication.authToken)
                                                    self.execute(request: request, completionHandler: completionHandler)
                                                case .error(let error): completionHandler(.error(error))
                                                }
                                }
                            } else {
                                completionHandler(result)
                            }
                        }
            }
        }
    }
    
    public func execute<T>(request: RemoteRequest,
                           completionHandler: @escaping (Result<T>) -> Void) where T : Decodable, T : Encodable {
        if !isAuthorized {
            self.handleUnauthorized { success in
                if success {
                    self.isAuthorized = true
                    self.execute(request: request, completionHandler: completionHandler)
                } else {
                    completionHandler(.error(ResponseError.unauthorized401(error: nil)))
                }
            }
            return
        }
        urlSession.dataTask(with: request.urlRequest(from: remoteHost)) { (data, urlResponse, error) in
            var apiError: Error?
            var apiResult: T?

            //Authorize and re-login
            if let urlResponse = urlResponse as? HTTPURLResponse {
                if (200...300).contains(urlResponse.statusCode) {
                    guard let data = data,
                        let contentType = urlResponse.allHeaderFields["Content-Type"] as? String,
                        contentType == "application/json" else {
                            return
                    }
                    do {
                        apiResult = try JSONDecoder().decode(T.self, from: data)
                    } catch let parsingError {
                        apiError = parsingError
                    }
                } else if 401 == urlResponse.statusCode {
                    self.handleUnauthorized { success in
                        if success {
                            self.execute(request: request, completionHandler: completionHandler)
                        } else {
                            completionHandler(.error(ResponseError.unauthorized401(error: nil)))
                        }
                    }
                    return
                } else if 403 == urlResponse.statusCode {
                    self.handleForbidden { success in
                        if success {
                            self.execute(request: request, completionHandler: completionHandler)
                        } else {
                            completionHandler(.error(ResponseError.forbidden403(error: nil)))
                        }
                    }
                } else if let parsedError = ResponseError(error: error, response: urlResponse) {
                    apiError = parsedError
                } else {
                    apiError = ResponseError.serverError500(error: nil)
                }
            }
        
            DispatchQueue.main.async {
                if let apiResult = apiResult {
                    completionHandler(.success(apiResult))
                    return
                }
                completionHandler(.error(apiError ?? ResponseError.other))
            }
        }.resume()
    }
}

extension Networking {
    fileprivate func handleUnauthorized(completionHandler: @escaping (Bool) -> Void) {
        // Authorize and re-login
        let requestBody = ExplicitLoginRequestBody(email: nil, password: nil)
        let authRequest = ExplicitLoginRequest(data: requestBody)
        self.execute(request: authRequest,
                     presentationBlock: self.presentationBlock,
                     dismissBlock: self.dismissBlock) { (result: Result<AuthenticationResponse>) in
            switch result {
            case .success(let authentication):
                self.updateSession(authToken: authentication.authToken)
                completionHandler(true)
            case .error: completionHandler(false)
            }
        }
    }
    
    fileprivate func handleForbidden(completionHandler: @escaping (Bool) -> Void) {
    }
    
    fileprivate func updateSession(authToken: String) {
        let configuration = self.urlSession.configuration
        var headers = configuration.httpAdditionalHeaders ?? [AnyHashable: Any]()
        headers["Authorization"] = "Bearer \(authToken)"
        configuration.httpAdditionalHeaders = headers
        self.urlSession = URLSession(configuration: configuration)
    }
}

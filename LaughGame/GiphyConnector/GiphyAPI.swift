//
//  GiphyAPI.swift
//  LaughGame
//
//  Created by Rafael d'Escoffier on 04/07/17.
//  Copyright © 2017 Rafael Escoffier. All rights reserved.
//

import Moya
import Moya_Argo
import ReactiveCocoa

enum GiphyAPITarget: TargetType {
    static let key = "" // GIPHY API KEY
    
    case search(query: String)
    
    var baseURL: URL { return URL(string: "https://api.giphy.com/v1/gifs")! }
    
    var path: String {
        switch self {
        case .search:
            return "/search"
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .search:
            return .get
        }
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .search(let query):
            return [
                "api_key" : GiphyAPITarget.key,
                "q" : query,
                "limit" : "50"
            ]
        }
    }
    
    var parameterEncoding: ParameterEncoding {
        return URLEncoding.default
    }
    
    var sampleData: Data {
        return Data()
    }
    
    var task: Task {
        switch self {
        case .search:
            return .request
        }
    }
}

struct GiphyAPI {
    
    static func search(query: String, completion: @escaping ((([Giphy]?) -> ()))) {
        let provider = MoyaProvider<GiphyAPITarget>()
        provider.request(.search(query: query)) { result in
            guard let value = result.value else {
                completion(nil)
                
                return
            }
            
            do {
                let collection: [Giphy] = try value.mapArray(rootKey: "data")
                completion(collection)
            } catch let error {
                completion(nil)
            }
        }
    }
}


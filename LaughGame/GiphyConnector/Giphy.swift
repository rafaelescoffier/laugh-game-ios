//
//  Giphy.swift
//  LaughGame
//
//  Created by Rafael d'Escoffier on 04/07/17.
//  Copyright © 2017 Rafael Escoffier. All rights reserved.
//

import Argo
import Runes
import Curry


struct Giphy {
    let id: String
    let url: String
}

extension Giphy: Decodable {
    static func decode(_ json: JSON) -> Decoded<Giphy> {
        return curry(Giphy.init)
            <^> json <| "id"
            <*> json <| ["images", "original", "url"] // Parse nested objects
        }
}

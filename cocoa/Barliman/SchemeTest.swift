//
// Created by Ben J on 7/29/18.
// Copyright (c) 2018 William E. Byrd. All rights reserved.
//

import Foundation

struct SchemeTest {
    let input: String
    let output: String
    let id: Int
    var name: String {
        return "test\(id)"
    }
}

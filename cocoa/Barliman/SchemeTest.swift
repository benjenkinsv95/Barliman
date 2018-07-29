//
// Created by Ben J on 7/29/18.
// Copyright (c) 2018 William E. Byrd. All rights reserved.
//

import Cocoa

struct SchemeTest {
    var shouldProcess: Bool {
        return !input.isEmpty && !output.isEmpty
    }

    let input: String
    let output: String
    let id: Int
    var name: String {
        return "test\(id)"
    }
    let view: SchemeTestView?

    init(input: String, output: String, id: Int, view: SchemeTestView? = nil) {
        self.input = input
        self.output = output
        self.id = id
        self.view = view
    }

    init(inputField: NSTextField, expectedOutputField: NSTextField,
         statusLabel: NSTextField,
         spinner: NSProgressIndicator, id: Int) {
        self.view = SchemeTestView(inputField: inputField,
                expectedOutputField: expectedOutputField,
                statusLabel: statusLabel, spinner: spinner)

        let processTest = !inputField.stringValue.isEmpty && !expectedOutputField.stringValue.isEmpty
        self.input = (processTest ? inputField.stringValue : "")
        self.output = (processTest ? expectedOutputField.stringValue : "")
        self.id = id
    }
}

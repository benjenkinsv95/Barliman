//
//  RunSchemeOperation.swift
//  Barliman
//
//  Created by William Byrd on 5/24/16.
//  Copyright © 2016 William E. Byrd.
//  Released under MIT License (see LICENSE file)

import Foundation
import Cocoa

class RunSchemeOperation: Operation {

    var editorWindowController: EditorWindowController
    var schemeScriptPathString: String
    var task: Process
    var taskType: String

    let kDefaultColor = EditorWindowController.defaultColor()
    let kSyntaxErrorColor = NSColor.orange
    let kParseErrorColor = NSColor.magenta
    let kFailedErrorColor = NSColor.red
    let kThinkingColor = NSColor.purple

    let kIllegalSexprString = "Illegal sexpression"
    let kParseErrorString = "Syntax error"
    let kEvaluationFailedString = "Evaluation failed"
    let kThinkingString = "???"
    let test: SchemeTest?


    init(editorWindowController: EditorWindowController, schemeScriptPathString: String, taskType: String, test: SchemeTest? = nil) {
        self.editorWindowController = editorWindowController
        self.schemeScriptPathString = schemeScriptPathString
        self.task = Process()
        self.taskType = taskType
        self.test = test
    }

    override func cancel() {
        print("!!! cancel called!")

        super.cancel()

        // print("&&& killing process \( task.processIdentifier )")
        task.terminate()
        // print("&&& killed process")

    }

    func startSpinner() {

        // update the user interface, which *must* be done through the main thread
        OperationQueue.main.addOperation {

            let ewc = self.editorWindowController

            switch self.taskType {
            case "simple":   ewc.schemeDefinitionSpinner.startAnimation(self)
            case "allTests": ewc.bestGuessSpinner.startAnimation(self)
            default:
                if let testView = self.test?.view {
                    testView.spinner.startAnimation(self)
                } else {
                    print("!!!!!!!!!! SWITCHERROR in startSpinner: unknown taskType: \( self.taskType )\n")
                }
            }
        }
    }

    func stopSpinner() {

        // update the user interface, which *must* be done through the main thread
        OperationQueue.main.addOperation {

            let ewc = self.editorWindowController

            switch self.taskType {
                case "simple":   ewc.schemeDefinitionSpinner.stopAnimation(self)
                case "allTests": ewc.bestGuessSpinner.stopAnimation(self)
                default:
                    if let testView = self.test?.view {
                        testView.spinner.stopAnimation(self)
                    } else {
                        print("!!!!!!!!!! SWITCHERROR in stopSpinner: unknown taskType: \(self.taskType)\n")
                    }
            }
        }
    }

    func illegalSexpInDefn() {

        // update the user interface, which *must* be done through the main thread
        OperationQueue.main.addOperation {

            let ewc = self.editorWindowController

            ewc.schemeDefinitionView.textColor = self.kSyntaxErrorColor
            ewc.definitionStatusLabel.textColor = self.kSyntaxErrorColor
            ewc.definitionStatusLabel.stringValue = self.kIllegalSexprString
        }
    }

    func parseErrorInDefn() {

        // update the user interface, which *must* be done through the main thread
        OperationQueue.main.addOperation {

            let ewc = self.editorWindowController

            ewc.schemeDefinitionView.textColor = self.kParseErrorColor
            ewc.definitionStatusLabel.textColor = self.kParseErrorColor
            ewc.definitionStatusLabel.stringValue = self.kParseErrorString

            // Be polite and cancel the allTests operation as well, since it cannot possibly succeed
            self.editorWindowController.schemeOperationAllTests?.cancel()
        }
    }


    func thinkingColorAndLabel() {

        // update the user interface, which *must* be done through the main thread
        OperationQueue.main.addOperation {

            let ewc = self.editorWindowController

            switch self.taskType {
            case "simple":
                ewc.definitionStatusLabel.textColor = self.kThinkingColor
                ewc.definitionStatusLabel.stringValue = self.kThinkingString
            case "allTests":
                ewc.bestGuessStatusLabel.textColor = self.kThinkingColor
                ewc.bestGuessStatusLabel.stringValue = self.kThinkingString
                ewc.bestGuessView.textColor = self.kThinkingColor
            default:
                if let testView = self.test?.view {
                    testView.statusLabel.textColor = self.kThinkingColor
                    testView.statusLabel.stringValue = self.kThinkingString
                    testView.inputField.textColor = self.kThinkingColor
                    testView.expectedOutputField.textColor = self.kThinkingColor
                } else {
                    print("!!!!!!!!!! SWITCHERROR in thinkingColorAndLabel: unknown taskType: \( self.taskType )\n")
                }
            }
        }
    }


    override func main() {

        if self.isCancelled {
            // print("*** cancelled immediately! ***\n")
            return
        }

        runSchemeCode()
    }


    func runSchemeCode() {

        startSpinner()
        thinkingColorAndLabel()

        // If we move to only support macOS 10.12, can use the improved time difference code adapted from JeremyP's answer to http://stackoverflow.com/questions/24755558/measure-elapsed-time-in-swift.  Instead we'll use JeremyP's NSDate version instead.
        let startTime = Date();


        // Path to Chez Scheme
        // Perhaps this should be settable in a preferences panel.
        task.launchPath = "/usr/local/bin/scheme"

        // Arguments to Chez Scheme
        task.arguments = ["--script", self.schemeScriptPathString]

        let outputPipe = Pipe()
        let errorPipe = Pipe()

        task.standardOutput = outputPipe
        task.standardError = errorPipe

        // Launch the Chez Scheme process, with the miniKanren query
        task.launch()
        // print("*** launched process \( task.processIdentifier )")


        let outputFileHandle = outputPipe.fileHandleForReading
        let errorFileHandle = errorPipe.fileHandleForReading

        let data = outputFileHandle.readDataToEndOfFile()
        let errorData = errorFileHandle.readDataToEndOfFile()

        // wait until the miniKanren query completes
        // (or until the task is killed because the operation is cancelled)
        task.waitUntilExit()

        // we need the exit status of the Scheme process to know if Chez choked because of a syntax error (for a malformed query), or whether Chez exited cleanly
        let exitStatus = task.terminationStatus

        stopSpinner()

        // update the user interface, which *must* be done through the main thread
        OperationQueue.main.addOperation {

            func setFontAndSize(_ bestGuessView: NSTextView) {
                bestGuessView.textStorage?.addAttribute(NSFontAttributeName,
                    value: NSFont(name: EditorWindowController.fontName(), size: EditorWindowController.fontSize())!,
                    range: NSMakeRange(0, bestGuessView.string!.characters.count))
            }
            
            func onTestCompletion(_ inputField: NSTextField, outputField: NSTextField, spinner: NSProgressIndicator, label: NSTextField, datastring: String) {

                if datastring == "illegal-sexp-in-test/answer" {
                    inputField.textColor = self.kSyntaxErrorColor
                    outputField.textColor = self.kSyntaxErrorColor
                    label.textColor = self.kSyntaxErrorColor
                    label.stringValue = self.kIllegalSexprString

                    // Be polite and cancel the allTests operation as well, since it cannot possibly succeed
                    self.editorWindowController.schemeOperationAllTests?.cancel()
                } else if datastring == "parse-error-in-test/answer" {
                    inputField.textColor = self.kParseErrorColor
                    outputField.textColor = self.kParseErrorColor
                    label.textColor = self.kParseErrorColor
                    label.stringValue = self.kParseErrorString

                    // Be polite and cancel the allTests operation as well, since it cannot possibly succeed
                    self.editorWindowController.schemeOperationAllTests?.cancel()
                } else if (datastring == "illegal-sexp-in-defn" || datastring == "parse-error-in-defn") {
                    // The definition is messed up.  We don't really know the state of the test.
                    // We represent this in the UI as the ??? "thinking" string without the spinner

                    inputField.textColor = self.kThinkingColor
                    outputField.textColor = self.kThinkingColor
                    label.textColor = self.kThinkingColor
                    label.stringValue = self.kThinkingString
                } else if datastring == "()" { // parsed, but evaluator query failed!
                    onTestFailure(inputField, outputField: outputField, label: label)
                } else { // parsed, and evaluator query succeeded!
                    onTestSuccess(inputField, outputField: outputField, label: label)
                }
            }

            func onTestSuccess(_ inputField: NSTextField, outputField: NSTextField, label: NSTextField) {
                let endTime = Date();
                let timeInterval: Double = endTime.timeIntervalSince(startTime);

                inputField.textColor = self.kDefaultColor
                outputField.textColor = self.kDefaultColor
                // formatting from realityone's answer to http://stackoverflow.com/questions/24051314/precision-string-format-specifier-in-swift
                label.textColor = self.kDefaultColor
                label.stringValue = String(format: "Succeeded (%.2f s)",  timeInterval)
            }

            func onTestFailure(_ inputField: NSTextField, outputField: NSTextField, label: NSTextField) {
                let endTime = Date();
                let timeInterval: Double = endTime.timeIntervalSince(startTime);

                inputField.textColor = self.kFailedErrorColor
                outputField.textColor = self.kFailedErrorColor
                // formatting from realityone's answer to http://stackoverflow.com/questions/24051314/precision-string-format-specifier-in-swift
                label.textColor = self.kFailedErrorColor
                label.stringValue = String(format: "Failed (%.2f s)",  timeInterval)

                // Be polite and cancel the allTests operation as well, since it cannot possibly succeed
                self.editorWindowController.schemeOperationAllTests?.cancel()
            }

            func onTestSyntaxError(_ inputField: NSTextField, outputField: NSTextField, spinner: NSProgressIndicator, label: NSTextField) {
                inputField.textColor = self.kSyntaxErrorColor
                outputField.textColor = self.kSyntaxErrorColor
                label.textColor = self.kSyntaxErrorColor
                label.stringValue = self.kIllegalSexprString
            }

            func onBestGuessSuccess(_ bestGuessView: NSTextView, label: NSTextField, guess: String) {
                let endTime = Date();
                let timeInterval: Double = endTime.timeIntervalSince(startTime);

                if (guess == "illegal-sexp-in-defn" ||
                    guess == "parse-error-in-defn" ||
                    guess == "illegal-sexp-in-test/answer" ||
                    guess == "parse-error-in-test/answer") {
                    // someone goofed!
                    // we just don't know what to do!

                    bestGuessView.textStorage?.setAttributedString(NSAttributedString(string: "" as String))
                    setFontAndSize(bestGuessView)
                    
                    label.textColor = self.kThinkingColor
                    label.stringValue = self.kThinkingString

                } else { // success!

                    bestGuessView.textStorage?.setAttributedString(NSAttributedString(string: guess))
                    setFontAndSize(bestGuessView)

                    label.textColor = self.kDefaultColor
                    label.stringValue = String(format: "Succeeded (%.2f s)",  timeInterval)

                    // Be polite and cancel all the other tests, since they must succeed!
                    self.editorWindowController.runSchemeOperationQueue.cancelAllOperations()
                }
            }

            func onBestGuessFailure(_ bestGuessView: NSTextView, label: NSTextField) {
                let endTime = Date();
                let timeInterval: Double = endTime.timeIntervalSince(startTime);

                bestGuessView.textStorage?.setAttributedString(NSAttributedString(string: "" as String))
                setFontAndSize(bestGuessView)
                
                label.textColor = self.kFailedErrorColor
                label.stringValue = String(format: "Failed (%.2f s)",  timeInterval)

                // Be polite and cancel all the other tests, since they must succeed!
                self.editorWindowController.runSchemeOperationQueue.cancelAllOperations()
            }

            func onBestGuessKilled(_ bestGuessView: NSTextView, label: NSTextField) {
                bestGuessView.textStorage?.setAttributedString(NSAttributedString(string: "" as String))
                setFontAndSize(bestGuessView)

                label.textColor = self.kDefaultColor
                label.stringValue = ""
            }

            // syntax error was caused by the main code or a test, not by the best guess!
            func onSyntaxErrorBestGuess(_ bestGuessView: NSTextView, label: NSTextField) {

                // is this line still needed?  seems like old code
                bestGuessView.setTextColor(self.kDefaultColor, range: NSMakeRange(0, (bestGuessView.textStorage?.length)!))

                bestGuessView.textStorage?.setAttributedString(NSAttributedString(string: "" as String))
                setFontAndSize(bestGuessView)

                label.textColor = self.kDefaultColor
                label.stringValue = ""
            }




            let datastring = NSString(data: data, encoding: String.Encoding.utf8.rawValue)! as String
            let errorDatastring = NSString(data: errorData, encoding: String.Encoding.utf8.rawValue)! as String
            let taskType = self.taskType

            let ewc = self.editorWindowController

            if exitStatus == 0 {
                // at least Chez ran to completion!  The query could still have failed, of course
                if self.taskType == "simple" {
                    if datastring == "parse-error-in-defn" {
                        self.parseErrorInDefn()
                    } else if datastring == "illegal-sexp-in-defn" {
                        self.illegalSexpInDefn()
                    } else if datastring == "()" {
                        ewc.schemeDefinitionView.textColor = self.kFailedErrorColor
                        ewc.definitionStatusLabel.textColor = self.kFailedErrorColor
                        ewc.definitionStatusLabel.stringValue = self.kEvaluationFailedString

                        // Be polite and cancel the allTests operation as well, since it cannot possibly succeed
                        self.editorWindowController.schemeOperationAllTests?.cancel()
                    } else {
                        ewc.schemeDefinitionView.textColor = self.kDefaultColor
                        ewc.definitionStatusLabel.textColor = self.kDefaultColor
                        ewc.definitionStatusLabel.stringValue = ""
                    }
                }

                if let testView = self.test?.view {
                    onTestCompletion(testView.inputField,
                            outputField: testView.expectedOutputField,
                            spinner: testView.spinner,
                            label: testView.statusLabel, datastring: datastring)

                }

                if self.taskType == "allTests" {
                    if datastring == "fail" {
                        onBestGuessFailure(ewc.bestGuessView, label: ewc.bestGuessStatusLabel)
                    } else {
                        onBestGuessSuccess(ewc.bestGuessView, label: ewc.bestGuessStatusLabel, guess: datastring)
                    }
                }
            } else if exitStatus == 15 {
                // SIGTERM exitStatus
                print("SIGTERM !!!  taskType = \( self.taskType )")

                // allTests must have been cancelled by a failing test, meaning there is no way for allTests to succeed
                if self.taskType == "allTests" {
                    onBestGuessKilled(ewc.bestGuessView, label: ewc.bestGuessStatusLabel)
                }

                // individual tests must have been cancelled by allTests succeeding, meaning that all the individual tests should succeed
                if let testView = self.test?.view {
                    onTestSuccess(testView.inputField,
                            outputField: testView.expectedOutputField,
                            label: testView.statusLabel)
                }

            } else {
                // the query wasn't even a legal s-expression, according to Chez!
                if self.taskType == "simple" {
                    // print("exitStatus = \( exitStatus )")
                    self.illegalSexpInDefn()
                }

                if let testView = self.test?.view {
                    onTestSyntaxError(testView.inputField,
                            outputField: testView.expectedOutputField,
                            spinner: testView.spinner,
                            label: testView.statusLabel)
                }

                if taskType == "allTests" {
                    onSyntaxErrorBestGuess(ewc.bestGuessView, label: ewc.bestGuessStatusLabel)
                }
            }

            print("datastring for process \( self.task.processIdentifier ): \(datastring)")
            print("error datastring for process \( self.task.processIdentifier ): \(errorDatastring)")
        }
    }
}

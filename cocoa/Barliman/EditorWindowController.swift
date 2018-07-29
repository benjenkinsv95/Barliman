//
//  EditorWindowController.swift
//  Barliman
//
//  Created by William Byrd on 5/14/16.
//  Copyright © 2016 William E. Byrd.
//  Released under MIT License (see LICENSE file)

import Cocoa

class EditorWindowController: NSWindowController, NSSplitViewDelegate {

    @IBOutlet weak var definitionAndBestGuessSplitView: NSSplitView!

    @IBOutlet var schemeDefinitionView: NSTextView!
    @IBOutlet weak var schemeDefinitionSpinner: NSProgressIndicator!
    @IBOutlet weak var definitionStatusLabel: NSTextField!

    @IBOutlet var bestGuessView: NSTextView!
    @IBOutlet weak var bestGuessSpinner: NSProgressIndicator!
    @IBOutlet weak var bestGuessStatusLabel: NSTextField!

    @IBOutlet weak var test1Spinner: NSProgressIndicator!
    @IBOutlet weak var test1InputField: NSTextField!
    @IBOutlet weak var test1ExpectedOutputField: NSTextField!
    @IBOutlet weak var test1StatusLabel: NSTextField!

    var runCodeFromEditPaneTimer: Timer?

    var semanticsWindowController: SemanticsWindowController?

    // keep track of the operation that runs all the tests together, in case we need to cancel it
    var schemeOperationAllTests: RunSchemeOperation?

    let runSchemeOperationQueue: OperationQueue = OperationQueue()

    static func fontName() -> String {
        return "Monaco"
    }

    static func fontSize() -> CGFloat {
        return 14
    }

    static func defaultColor() -> NSColor {
        return NSColor.black
    }


    override var windowNibName: String? {
        return "EditorWindowController"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.

        // from http://stackoverflow.com/questions/19801601/nstextview-with-smart-quotes-disabled-still-replaces-quotes
        schemeDefinitionView.isAutomaticQuoteSubstitutionEnabled = false
        bestGuessView.isAutomaticQuoteSubstitutionEnabled = false

        let defaultFontName = EditorWindowController.fontName()
        let defaultFontSize = EditorWindowController.fontSize()
        let font = NSFont(name: defaultFontName, size: defaultFontSize)

        schemeDefinitionView.font = NSFont(name: defaultFontName, size: defaultFontSize)
        bestGuessView.font = NSFont(name: defaultFontName, size: defaultFontSize)

        test1InputField.font = font
        test1ExpectedOutputField.font = font

        // from http://stackoverflow.com/questions/28001996/setting-minimum-width-of-nssplitviews
        self.definitionAndBestGuessSplitView.delegate = self
    }

    // from http://stackoverflow.com/questions/28001996/setting-minimum-width-of-nssplitviews
    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMinimumPosition + 30
    }

    // from http://stackoverflow.com/questions/28001996/setting-minimum-width-of-nssplitviews
    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return proposedMaximumPosition - 50
    }


    func cleanup() {
        // application is about to quit -- clean up!

        print("cleaning up!")

        runCodeFromEditPaneTimer?.invalidate()

        // tell every operation to kill its Scheme task
        print("prior operation count: \(runSchemeOperationQueue.operationCount)")
        runSchemeOperationQueue.cancelAllOperations()

        //

        // wait until all the operations have finished
        runSchemeOperationQueue.waitUntilAllOperationsAreFinished()
        print("subsequent operation count: \(runSchemeOperationQueue.operationCount)")

        if runSchemeOperationQueue.operationCount > 0 {
            // handle this better!  :)
            print("$$$$  Oh noes!  Looks like there is a Scheme process still running!")
        }
    }

    func textDidChange(_ notification: Notification) {
        // NSTextView text changed
        print("@@@@@@@@@@@@@@@@@@@ textDidChange")

        setupRunCodeFromEditPaneTimer()
    }

    override func controlTextDidChange(_ aNotification: Notification) {
        // NSTextField text changed
        print("@@@@@@@@@@@@@@@@@@@ controlTextDidChange")

        setupRunCodeFromEditPaneTimer()
    }

    func setupRunCodeFromEditPaneTimer() {
        runCodeFromEditPaneTimer?.invalidate()

        runCodeFromEditPaneTimer = .scheduledTimer(timeInterval: 1, target: self, selector: #selector(runCodeFromEditPane), userInfo: nil, repeats: false)
    }

    func makeQuerySimpleForMondoSchemeFileString(_ interp_string: String,
                                                 definitionText: String,
                                                 mk_vicare_path_string: String,
                                                 mk_path_string: String) -> String {

        let load_mk_vicare_string: String = "(load \"\(mk_vicare_path_string)\")"
        let load_mk_string: String = "(load \"\(mk_path_string)\")"

        let querySimple: String = makeQueryString(definitionText,
                body: ",_",
                expectedOut: "q",
                simple: true,
                name: "-simple")


        let full_string: String = load_mk_vicare_string + "\n" +
                load_mk_string + "\n" +
                interp_string + "\n" +
                querySimple

        return full_string
    }

    private func makeAllTestsQueryString(definitionText: String, testInputs: [String], testOutputs: [String]) -> String {
        let allTestInputs = testInputs.joined(separator: " ")
        let allTestOutputs = testOutputs.joined(separator: " ")


        // get the path to the application's bundle, so we can load the query string files
        let bundle = Bundle.main

        // adapted from http://stackoverflow.com/questions/26573332/reading-a-short-text-file-to-a-string-in-swift
        let interp_alltests_query_string_part_1: String? = bundle.path(forResource: "interp-alltests-query-string-part-1", ofType: "swift", inDirectory: "mk-and-rel-interp")
        let interp_alltests_query_string_part_2: String? = bundle.path(forResource: "interp-alltests-query-string-part-2", ofType: "swift", inDirectory: "mk-and-rel-interp")

        let alltests_string_part_1: String
        do {
            alltests_string_part_1 = try String(contentsOfFile: interp_alltests_query_string_part_1!)
        } catch {
            print("!!!!!  LOAD_ERROR -- can't load alltests_string_part_1\n")
            alltests_string_part_1 = ""
        }

        let alltests_string_part_2: String
        do {
            alltests_string_part_2 = try String(contentsOfFile: interp_alltests_query_string_part_2!)
        } catch {
            print("!!!!!  LOAD_ERROR -- can't load alltests_string_part_2\n")
            alltests_string_part_2 = ""
        }

        let eval_flags_fast = "(set! allow-incomplete-search? #t)"
        let eval_flags_complete = "(set! allow-incomplete-search? #f)"
        let eval_string_fast = "(begin \(eval_flags_fast) (results))"
        let eval_string_complete = "(begin \(eval_flags_complete) (results))"

        let allTestWriteString = "(define (ans-allTests)\n" +
                "  (define (results)\n" +
                alltests_string_part_1 + "\n" +
                "        (== `( \(definitionText) ) defn-list)" + "\n" + "\n" +
                alltests_string_part_2 + "\n" +
                "(== `(" +
                definitionText +
                ") defns) (appendo defns `(((lambda x x) " +
                allTestInputs +
                ")) begin-body) (evalo `(begin . ,begin-body) (list " +
                allTestOutputs +
                ")" +
                ")))))\n" +
                "(let ((results-fast \(eval_string_fast)))\n" +
                "  (if (null? results-fast)\n" +
                "    \(eval_string_complete)\n" +
                "    results-fast)))"

        let fullString: String = ";; allTests" + "\n" + allTestWriteString

        print("queryAllTests string:\n \(fullString)\n")
        return fullString
    }

    func makeQueryString(_ defns: String,
                         body: String,
                         expectedOut: String,
                         simple: Bool,
                         name: String) -> String {

        let parse_ans_string: String = "(define (parse-ans\(name)) (run 1 (q)" + "\n" +
                " (let ((g1 (gensym \"g1\")) (g2 (gensym \"g2\")) (g3 (gensym \"g3\")) (g4 (gensym \"g4\")) (g5 (gensym \"g5\")) (g6 (gensym \"g6\")) (g7 (gensym \"g7\")) (g8 (gensym \"g8\")) (g9 (gensym \"g9\")) (g10 (gensym \"g10\")) (g11 (gensym \"g11\")) (g12 (gensym \"g12\")) (g13 (gensym \"g13\")) (g14 (gensym \"g14\")) (g15 (gensym \"g15\")) (g16 (gensym \"g16\")) (g17 (gensym \"g17\")) (g18 (gensym \"g18\")) (g19 (gensym \"g19\")) (g20 (gensym \"g20\")))" + "\n" +
                "(fresh (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z _) (parseo `(begin \(defns) \(body)))))))"

        let parse_with_fake_defns_ans_string: String = "(define (parse-ans\(name)) (run 1 (q)" + "\n" +
                " (let ((g1 (gensym \"g1\")) (g2 (gensym \"g2\")) (g3 (gensym \"g3\")) (g4 (gensym \"g4\")) (g5 (gensym \"g5\")) (g6 (gensym \"g6\")) (g7 (gensym \"g7\")) (g8 (gensym \"g8\")) (g9 (gensym \"g9\")) (g10 (gensym \"g10\")) (g11 (gensym \"g11\")) (g12 (gensym \"g12\")) (g13 (gensym \"g13\")) (g14 (gensym \"g14\")) (g15 (gensym \"g15\")) (g16 (gensym \"g16\")) (g17 (gensym \"g17\")) (g18 (gensym \"g18\")) (g19 (gensym \"g19\")) (g20 (gensym \"g20\")))" + "\n" +
                " (fresh (A B C D E F G H I J K L M N O P Q R S T U V W X Y Z _) (fresh (names dummy-expr) (extract-nameso `( \(defns) ) names) (parseo `((lambda ,names \(body)) ,dummy-expr)))))))"


        // get the path to the application's bundle, so we can load the query string files
        let bundle = Bundle.main

        // adapted from http://stackoverflow.com/questions/26573332/reading-a-short-text-file-to-a-string-in-swift
        let interp_eval_query_string_part_1: String? = bundle.path(forResource: "interp-eval-query-string-part-1", ofType: "swift", inDirectory: "mk-and-rel-interp")
        let interp_eval_query_string_part_2: String? = bundle.path(forResource: "interp-eval-query-string-part-2", ofType: "swift", inDirectory: "mk-and-rel-interp")

        let eval_string_part_1: String
        do {
            eval_string_part_1 = try String(contentsOfFile: interp_eval_query_string_part_1!)
        } catch {
            print("!!!!!  LOAD_ERROR -- can't load eval_string_part_1\n")
            eval_string_part_1 = ""
        }

        let eval_string_part_2: String
        do {
            eval_string_part_2 = try String(contentsOfFile: interp_eval_query_string_part_2!)
        } catch {
            print("!!!!!  LOAD_ERROR -- can't load eval_string_part_2\n")
            eval_string_part_2 = ""
        }

        let eval_string = eval_string_part_1 + "\n" +
                "        (== `( \(defns) ) defn-list)" + "\n" +
                eval_string_part_2 + "\n" +
                " (evalo `(begin \(defns) \(body)) \(expectedOut)))))"

        let eval_flags_fast = "(set! allow-incomplete-search? #t)"
        let eval_flags_complete = "(set! allow-incomplete-search? #f)"

        let eval_string_fast = "(begin \(eval_flags_fast) \(eval_string))"
        let eval_string_complete = "(begin \(eval_flags_complete) \(eval_string))"
        let eval_string_both = "(let ((results-fast \(eval_string_fast)))\n" +
                "  (if (null? results-fast)\n" +
                "    \(eval_string_complete)\n" +
                "     results-fast))"

        let define_ans_string: String = "(define (query-val\(name))" + "\n" +
                "  (if (null? (parse-ans\(name)))" + "\n" +
                "      'parse-error" + "\n" +
                "      \(eval_string_both)))"

        let full_string: String = (simple ? ";; simple query" : ";; individual test query") + "\n\n" +
                (simple ? parse_ans_string : parse_with_fake_defns_ans_string) + "\n\n" +
                define_ans_string + "\n\n"

        print("query string:\n \(full_string)\n")

        return full_string
    }

    func shouldProcessTest(input: String, output: String) -> Bool {
        return !input.isEmpty && !output.isEmpty
    }

    // The text in the code pane changed!  Launch a new Scheme task to evaluate the new expression...
    func runCodeFromEditPane() {
        // Extract data from UI
        let processTest1 = !test1InputField.stringValue.isEmpty && !test1ExpectedOutputField.stringValue.isEmpty
        let in1 = (processTest1 ? test1InputField.stringValue : "")
        let out1 = (processTest1 ? test1ExpectedOutputField.stringValue : "")

        let definitionText = (schemeDefinitionView.textStorage as NSAttributedString!).string
        let interpreterSemantics: String = semanticsWindowController!.getInterpreterCode()

        runCode(definitionText: definitionText, interpreterSemantics:interpreterSemantics, in1: in1, out1: out1)

        resetTestUIs(in1: in1, out1: out1)
    }

    func resetTestUIs(in1: String, out1: String) {
        func resetTestUI(_ statusLabel: NSTextField, inputField: NSTextField, outputField: NSTextField) {
            statusLabel.stringValue = ""
            inputField.textColor = EditorWindowController.defaultColor()
            outputField.textColor = EditorWindowController.defaultColor()
        }

        if !shouldProcessTest(input: in1, output: out1) {
            resetTestUI(test1StatusLabel, inputField: test1InputField, outputField: test1ExpectedOutputField)
        }
    }

    func runCode(definitionText: String, interpreterSemantics: String, in1: String, out1: String) {
        // see how many operations are currently in the queue
        print("operation count: \(runSchemeOperationQueue.operationCount)")
        runSchemeOperationQueue.cancelAllOperations()


        let bundle = Bundle.main
        let mk_vicare_path: NSString? = bundle.path(forResource: "mk-vicare", ofType: "scm", inDirectory: "mk-and-rel-interp/mk") as NSString?
        let mk_path: NSString? = bundle.path(forResource: "mk", ofType: "scm", inDirectory: "mk-and-rel-interp/mk") as NSString?


        // write the Scheme code containing the miniKanren query to a temp file
        let query_simple_for_mondo_scheme_file = "barliman-query-simple-for-mondo-scheme-file.scm"

        // files that load query code
        let new_query_file_simple = "barliman-new-query-simple.scm"
        let new_query_file_test1 = "barliman-new-query-test1.scm"
        let new_query_file_alltests = "barliman-new-query-alltests.scm"

        // files containing the actual query code
        let new_query_file_actual_test1 = "barliman-new-query-actual-test1.scm"
        let new_query_file_actual_alltests = "barliman-new-query-actual-alltests.scm"

        let mk_vicare_path_string = mk_vicare_path! as String
        let mk_path_string = mk_path! as String

        let load_mk_vicare_string: String = "(load \"\(mk_vicare_path_string)\")"
        let load_mk_string: String = "(load \"\(mk_path_string)\")"


        let querySimpleForMondoSchemeContents: String = makeQuerySimpleForMondoSchemeFileString(interpreterSemantics,
                definitionText: definitionText,
                mk_vicare_path_string: mk_vicare_path_string,
                mk_path_string: mk_path_string)


        let newTest1ActualQueryString: String = makeQueryString(definitionText,
                body: in1,
                expectedOut: out1,
                simple: false,
                name: "-test1")


        let newAlltestsActualQueryString = makeAllTestsQueryString(definitionText: definitionText,
                testInputs: [in1], testOutputs: [out1])


        // adapted from http://stackoverflow.com/questions/26573332/reading-a-short-text-file-to-a-string-in-swift
        let new_simple_query_template: String? = bundle.path(forResource: "barliman-new-simple-query-template", ofType: "swift", inDirectory: "mk-and-rel-interp")

        let new_simple_query_template_string: String
        do {
            new_simple_query_template_string = try String(contentsOfFile: new_simple_query_template!)
        } catch {
            print("!!!!!  LOAD_ERROR -- can't load new_simple_query_template\n")
            new_simple_query_template_string = ""
        }


        // adapted from http://stackoverflow.com/questions/26573332/reading-a-short-text-file-to-a-string-in-swift
        let new_test_query_template: String? = bundle.path(forResource: "barliman-new-test-query-template", ofType: "swift", inDirectory: "mk-and-rel-interp")

        let new_test_query_template_string: String
        do {
            new_test_query_template_string = try String(contentsOfFile: new_test_query_template!)
        } catch {
            print("!!!!!  LOAD_ERROR -- can't load new_test_query_template\n")
            new_test_query_template_string = ""
        }


        // adapted from http://stackoverflow.com/questions/26573332/reading-a-short-text-file-to-a-string-in-swift
        let new_alltests_query_template: String? = bundle.path(forResource: "barliman-new-alltests-query-template", ofType: "swift", inDirectory: "mk-and-rel-interp")

        let new_alltests_query_template_string: String
        do {
            new_alltests_query_template_string = try String(contentsOfFile: new_alltests_query_template!)
        } catch {
            print("!!!!!  LOAD_ERROR -- can't load new_test_query_template\n")
            new_alltests_query_template_string = ""
        }


        let newSimpleQueryString: String
        let newTest1QueryString: String
        let newAlltestsQueryString: String


        if let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).first {

            let fullSimpleQueryForMondoSchemeFilePath = URL(fileURLWithPath: dir).appendingPathComponent("barliman-query-simple-for-mondo-scheme-file.scm")
            let localSimpleQueryForMondoSchemeFilePath = fullSimpleQueryForMondoSchemeFilePath.path

            let fullNewQueryActualTest1FilePath = URL(fileURLWithPath: dir).appendingPathComponent("barliman-new-query-actual-test1.scm")
            let localNewQueryActualTest1FilePath = fullNewQueryActualTest1FilePath.path

            let fullNewQueryActualAlltestsFilePath = URL(fileURLWithPath: dir).appendingPathComponent("barliman-new-query-actual-alltests.scm")
            let localNewQueryActualAlltestsFilePath = fullNewQueryActualAlltestsFilePath.path


            let loadFileString =
                    "(define simple-query-for-mondo-file-path \"\(localSimpleQueryForMondoSchemeFilePath)\")"

            newSimpleQueryString = loadFileString + "\n\n" + new_simple_query_template_string

            newAlltestsQueryString =
                    loadFileString + "\n\n" +
                            "(define actual-query-file-path \"\(localNewQueryActualAlltestsFilePath)\")" + "\n\n" +
                            new_alltests_query_template_string


            func makeNewTestNQueryString(_ n: Int, actualQueryFilePath: String) -> String {
                return loadFileString + "\n\n" +
                        "(define actual-query-file-path \"\(actualQueryFilePath)\")" + "\n\n" +
                        "(define (test-query-fn) (query-val-test\(n)))" + "\n\n\n" +
                        new_test_query_template_string
            }

            newTest1QueryString = makeNewTestNQueryString(1, actualQueryFilePath: localNewQueryActualTest1FilePath)
        } else {
            print("!!!!!  LOAD_ERROR -- can't find Document directory\n")

            newSimpleQueryString = ""
            newTest1QueryString = ""
            newAlltestsQueryString = ""
        }


        var pathQuerySimpleForMondoSchemeFile: URL!
        var pathNewSimple: URL!

        var pathNewTest1: URL!
        var pathNewAlltests: URL!

        var pathNewActualTest1: URL!
        var pathNewActualAlltests: URL!


        // write the temporary file containing the query to the user's Document directory.  This seems a bit naughty.  Where is the right place to put this?  In ~/.barliman, perhaps?
        if let dir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true).first {

            pathQuerySimpleForMondoSchemeFile = URL(fileURLWithPath: dir).appendingPathComponent(query_simple_for_mondo_scheme_file)


            pathNewSimple = URL(fileURLWithPath: dir).appendingPathComponent(new_query_file_simple)

            pathNewTest1 = URL(fileURLWithPath: dir).appendingPathComponent(new_query_file_test1)
            pathNewAlltests = URL(fileURLWithPath: dir).appendingPathComponent(new_query_file_alltests)

            pathNewActualTest1 = URL(fileURLWithPath: dir).appendingPathComponent(new_query_file_actual_test1)
            pathNewActualAlltests = URL(fileURLWithPath: dir).appendingPathComponent(new_query_file_actual_alltests)

            // write the query files
            do {

                try querySimpleForMondoSchemeContents.write(to: pathQuerySimpleForMondoSchemeFile, atomically: false, encoding: String.Encoding.utf8)


                try newSimpleQueryString.write(to: pathNewSimple, atomically: false, encoding: String.Encoding.utf8)

                try newTest1QueryString.write(to: pathNewTest1, atomically: false, encoding: String.Encoding.utf8)
                try newAlltestsQueryString.write(to: pathNewAlltests, atomically: false, encoding: String.Encoding.utf8)

                try newTest1ActualQueryString.write(to: pathNewActualTest1, atomically: false, encoding: String.Encoding.utf8)
                try newAlltestsActualQueryString.write(to: pathNewActualAlltests, atomically: false, encoding: String.Encoding.utf8)
            } catch {
                // this error handling could be better!  :)
                print("couldn't write to query files")
            }
        }


        // paths to the Schemes file containing the miniKanren query
        let schemeScriptPathStringNewSimple = pathNewSimple.path
        let schemeScriptPathStringNewTest1 = pathNewTest1.path
        let schemeScriptPathStringNewAlltests = pathNewAlltests.path


        // create the operations that will be placed in the operation queue


        let runSchemeOpSimple = RunSchemeOperation(editorWindowController: self, schemeScriptPathString: schemeScriptPathStringNewSimple, taskType: "simple")
        let runSchemeOpTest1 = RunSchemeOperation(editorWindowController: self, schemeScriptPathString: schemeScriptPathStringNewTest1, taskType: "test1")
        let runSchemeOpAllTests = RunSchemeOperation(editorWindowController: self, schemeScriptPathString: schemeScriptPathStringNewAlltests, taskType: "allTests")


        schemeOperationAllTests = runSchemeOpAllTests


        // wait until the previous operations kill their tasks and finish, before adding the new operations
        //
        // This operation seems expensive.  Barliman seems to work okay without this call.  Need we worry about a race condition here?
        //
        runSchemeOperationQueue.waitUntilAllOperationsAreFinished()


        // now that the previous operations have completed, safe to add the new operations
        runSchemeOperationQueue.addOperation(runSchemeOpAllTests)

        runSchemeOperationQueue.addOperation(runSchemeOpSimple)

        if shouldProcessTest(input: in1, output: out1) {
            print("queuing test1")
            runSchemeOperationQueue.addOperation(runSchemeOpTest1)
        }
    }


}

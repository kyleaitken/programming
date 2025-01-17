//
//  SampleTranslator.swift
//  SampleTranslator
//
//  Created by Wilf Lalonde on 2022-12-19
//  and Jeeheon Kim (for Wilf Lalonde) on 2022-1-10
//


import Foundation

typealias compileClosure = (VirtualTree) -> Void
typealias evaluateClosure = (VirtualTree) -> Int

public final class SampleTranslator: Translator {
  var parser: Parser?
  var tree: VirtualTree? = nil
  var codeIfCompiler: InputStream = InputStream()
    
  public final class InputStream {
    public var content: String = ""
    
    final func write(_ text: String){
      content += "\n\(text)"
    }
    
    final func show() {
      Swift.print(content)
    }
  }
  var expressionsIfEvaluator: [String: Any]?
  var compilationOperatorMap: [String: compileClosure]?
  var evaluationOperatorMap: [String: evaluateClosure]?
    
  public func canPerformAction(_ :String) -> Bool {return false}
  public func performAction(_ :String, _ :[Any]) -> Void {}

  init() {
    parser = Parser(sponsor: self, parserTables: parserTables, scannerTables: scannerTables)
    // codeIfCompiler <- not sure what this does
    // codeIfCompiler = TextOutputStream()
    expressionsIfEvaluator = Dictionary() // each key is a variable
    compilationOperatorMap = [
      "+": compilePlus,
      "*": compileMultiply,
      "<-": compileAssign,
      "Identifier": compileIdentifier,
      "Integer": compileInteger,
      "send": compileFunctionCall,
    ]
    evaluationOperatorMap = [
      "+": evaluatePlus,
      "*": evaluateMultiply,
      "<-": evaluateAssign,
      "Identifier": evaluateIdentifier,
      "Integer": evaluateInteger,
      // "send": "evaluateFunctionCall",
    ]
  }

  func compile(text: String) -> String {
      tree = parser!.parse(text)
      guard tree != nil else {
          error("CompilationError: tree failed to build")
        return ""
      }
      compileExpressionFor(tree!)
      return codeIfCompiler.content
  }

  func compileExpressionFor(_ tree: VirtualTree) {
    if let operatorMapFunction = compilationOperatorMap?[tree.label] {
      operatorMapFunction(tree)
    }
  }


  func compilePlus(_ tree: VirtualTree) -> Void {
    let t = tree as! Tree
    compileExpressionFor(t.children[0])
    compileExpressionFor(t.children[1])
    generate(instruction: "PLUS")
  }

  func compileMultiply(_ tree: VirtualTree) -> Void{
    let t = tree as! Tree
    compileExpressionFor(t.children[0])
    compileExpressionFor(t.children[1])
    generate(instruction: "MULTIPLY")
  }

  func compileAssign(_ tree: VirtualTree) -> Void {
    let t = tree as! Tree
    for index in t.children.indices {
      compileExpressionFor(t.children[index])
      generate(instruction: "POP")
    }
  }

  func compileIdentifier(_ token: VirtualTree) -> Void {
    generate(instruction: "PUSH", with: (token as! Token).symbol)
  }

  func compileInteger(_ token: VirtualTree) -> Void {
    generate(instruction: "PUSH", with: Int((token as! Token).symbol) ?? -1 )
  }

  func compileFunctionCall(_ tree: VirtualTree) -> Void {
    let t = tree as! Tree
    let childrenIndices: CountableClosedRange = 1...t.children.count
    for index in childrenIndices {
      compileExpressionFor(t.children[index])
    }
    let aToken = t.children[0] as! Token
    generate(instruction: "FUNCTION_CALL", with: aToken.symbol)
  }

  func generate(instruction: String) {
    codeIfCompiler.write("\(instruction)")
  }

  func generate(instruction: String, with: String) {
    let string = "\(instruction) \(with)"
    codeIfCompiler.write(string)
  }
  
  func generate(instruction: String, with: Int) {
    let string = "\(instruction) \(with)\n"
    codeIfCompiler.write(string)
  }

  func evaluate(text: String) -> Any? {
    // If no variables are set up, just return the expression
    // Otherwise, return a dictionary of variables
    tree = parser!.parse(text)
    guard tree != nil else {
        error("CompilationError: tree failed to build")
        return nil
      }
      let result = evaluateExpressionFor(tree!) // see result and variable dictionary
      if expressionsIfEvaluator!.count == 0 {
        return "\(result)" 
      } else {
        return expressionsIfEvaluator
      }
  }

  func evaluateExpressionFor(_ tree: VirtualTree) -> Int {
    return evaluationOperatorMap![tree.label]!(tree)
  }

  func evaluatePlus(_ tree: VirtualTree) -> Int {
    let t = tree as! Tree
    let exp1 = evaluateExpressionFor(t.children[0])
    let exp2 = evaluateExpressionFor(t.children[1])
    return exp1 + exp2
  }

  func evaluateMultiply(_ tree: VirtualTree) -> Int {
    let t = tree as! Tree
    let exp1 = evaluateExpressionFor(t.children[0])
    let exp2 = evaluateExpressionFor(t.children[1])
    return exp1 * exp2
  }

  func evaluateIdentifier(_ token: VirtualTree) -> Int {
    let t = token as! Token

    let identifier = t.symbol
    let value = expressionsIfEvaluator![identifier] as! Int

    return value
  }

  func evaluateInteger(_ token: VirtualTree) -> Int {
    let t = token as! Token
    return Int(t.symbol)!
  }

  func evaluateAssign(_ tree: VirtualTree) -> Int {
    //TODO
      return 0
  }


  func evaluateWhere(_ tree: VirtualTree) -> Int { 
    //TODO
      return 0
  }
    

var scannerTables: Array<Any> = [
    ["ScannerReadaheadTable", 1, ([256], "L", 5), (")", "RK", 7), ("*", "RK", 8), ("+", "RK", 9), (",", "RK", 10), ("0123456789", "RK", 2), ("(", "RK", 6), (";", "RK", 12), ("=", "RK", 13), ("ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 3), ([9, 10, 12, 13], "R", 4), (" ", "R", 4)],
    ["ScannerReadaheadTable", 2, ([9, 10, 12, 13, 256], "L", 11), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_+*=[]{}()^;#:.$ ", "L", 11), ("0123456789", "RK", 2)],
    ["ScannerReadaheadTable", 3, ([9, 10, 12, 13, 256], "L", 14), ("+*=[]{}()^;#:.$ ", "L", 14), ("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz", "RK", 3)],
    ["ScannerReadaheadTable", 4, ([256], "L", 1), ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_0123456789+*=[]{}()^;#:.$", "L", 1), ([9, 10, 12, 13], "R", 4), (" ", "R", 4)],
    ["SemanticTable", 5, "buildToken", ["-|"], 1],
    ["SemanticTable", 6, "buildToken", ["("], 1],
    ["SemanticTable", 7, "buildToken", [")"], 1],
    ["SemanticTable", 8, "buildToken", ["*"], 1],
    ["SemanticTable", 9, "buildToken", ["+"], 1],
    ["SemanticTable", 10, "buildToken", [","], 1],
    ["SemanticTable", 11, "buildToken", ["Integer"], 1],
    ["SemanticTable", 12, "buildToken", [";"], 1],
    ["SemanticTable", 13, "buildToken", ["="], 1],
    ["SemanticTable", 14, "buildToken", ["Identifier"], 1]]

var parserTables: Array<Any> = [
   ["keywords", "where"],
   ["ReadaheadTable", 1, ("Integer", "RSN", 28), ("Identifier", "RSN", 4), ("(", "RS", 5)],
   ["ReadaheadTable", 2, ("+", "RS", 6), ("-|", "L", 25)],
   ["ReadaheadTable", 3, ("*", "RS", 7), ("+", "L", 26), ("-|", "L", 26), (";", "L", 26), (")", "L", 26), (",", "L", 26)],
   ["ReadaheadTable", 4, ("(", "RS", 8), ("=", "RS", 9), ("+", "L", 28), ("*", "L", 28), ("-|", "L", 28), (";", "L", 28), (")", "L", 28), (",", "L", 28)],
   ["ReadaheadTable", 5, ("Integer", "RSN", 28), ("Identifier", "RSN", 11), ("(", "RS", 5)],
   ["ReadaheadTable", 6, ("Identifier", "RSN", 11), ("(", "RS", 5), ("Integer", "RSN", 28)],
   ["ReadaheadTable", 7, ("Identifier", "RSN", 11), ("(", "RS", 5), ("Integer", "RSN", 28)],
   ["ReadaheadTable", 8, (")", "RS", 32), ("Integer", "RSN", 28), ("Identifier", "RSN", 11), ("(", "RS", 5)],
   ["ReadaheadTable", 9, ("Integer", "RSN", 28), ("Identifier", "RSN", 11), ("(", "RS", 5)],
   ["ReadaheadTable", 10, (")", "RS", 29), ("+", "RS", 6)],
   ["ReadaheadTable", 11, ("(", "RS", 8), ("+", "L", 28), ("*", "L", 28), ("-|", "L", 28), (";", "L", 28), (")", "L", 28), (",", "L", 28)],
   ["ReadaheadTable", 12, ("*", "RS", 7), ("+", "L", 30), ("-|", "L", 30), (";", "L", 30), (")", "L", 30), (",", "L", 30)],
   ["ReadaheadTable", 13, ("+", "RS", 6), (",", "RS", 15), (")", "RS", 32)],
   ["ReadaheadTable", 14, ("+", "RS", 6), (";", "RS", 16)],
   ["ReadaheadTable", 15, ("Integer", "RSN", 28), ("Identifier", "RSN", 11), ("(", "RS", 5)],
   ["ReadaheadTable", 16, ("Identifier", "RSN", 18), ("-|", "L", 33)],
   ["ReadaheadTable", 17, ("+", "RS", 6), (",", "RS", 15), (")", "RS", 32)],
   ["ReadaheadTable", 18, ("=", "RS", 9)],
   ["ReadbackTable", 19, (("(", 8), "RS", 22), (("Expression", 13), "RSN", 34), (("Expression", 17), "RSN", 35)],
   ["ReadbackTable", 20, (("Expression", 10), "RSN", 40), (("Expression", 17), "RSN", 40), (("Expression", 2), "RSN", 40), (("Expression", 13), "RSN", 40), (("Expression", 14), "RSN", 40)],
   ["ReadbackTable", 21, (("Term", 12), "RSN", 41), (("Term", 3), "RSN", 41)],
   ["ReadbackTable", 22, (("Identifier", 4), "RSN", 42), (("Identifier", 11), "RSN", 42)],
   ["ReadbackTable", 23, (("Expression", 13), "RSN", 34), (("Expression", 17), "RSN", 35)],
   ["ReadbackTable", 24, (("Identifier", 4), "RSN", 43), (("Identifier", 18), "RSN", 33)],
   ["ShiftbackTable", 25, 1, 37],
   ["ShiftbackTable", 26, 1, 36],
   ["ShiftbackTable", 27, 1, 38],
   ["ShiftbackTable", 28, 1, 39],
   ["ShiftbackTable", 29, 3, 39],
   ["ShiftbackTable", 30, 2, 20],
   ["ShiftbackTable", 31, 2, 21],
   ["ShiftbackTable", 32, 1, 19],
   ["ShiftbackTable", 33, 3, 24],
   ["ShiftbackTable", 34, 1, 22],
   ["ShiftbackTable", 35, 1, 23],
   ["ReduceTable", 36, "Expression", (1, "RSN", 2),(5, "RSN", 10),(8, "RSN", 13),(9, "RSN", 14),(15, "RSN", 17)],
   ["ReduceTable", 37, "Grammar", (1, "RSN", 44)],
   ["ReduceTable", 38, "Term", (1, "RSN", 3),(5, "RSN", 3),(6, "RSN", 12),(8, "RSN", 3),(9, "RSN", 3),(15, "RSN", 3)],
   ["ReduceTable", 39, "Primary", (1, "RSN", 27),(5, "RSN", 27),(6, "RSN", 27),(7, "RSN", 31),(8, "RSN", 27),(9, "RSN", 27),(15, "RSN", 27)],
   ["SemanticTable", 40, "buildTree", ["+"], 36],
   ["SemanticTable", 41, "buildTree", ["*"], 38],
   ["SemanticTable", 42, "buildTree", ["send"], 39],
   ["SemanticTable", 43, "buildTree", ["<-"], 37],
   ["AcceptTable", 44]]
}

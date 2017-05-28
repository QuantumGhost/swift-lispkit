//
//  StringLibrary.swift
//  LispKit
//
//  Created by Matthias Zenger on 22/01/2016.
//  Copyright © 2016, 2017 ObjectHub. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


public final class StringLibrary: NativeLibrary {
  
  /// Name of the library.
  public override class var name: [String] {
    return ["lispkit", "string"]
  }
  
  /// Dependencies of the library.
  public override func dependencies() {
    self.`import`(from: ["lispkit", "control"], "let", "let*", "do", "unless", "when", "if")
    self.`import`(from: ["lispkit", "base"],    "define", "set!", "or", "not", "apply")
    self.`import`(from: ["lispkit", "list"],    "cons", "null?")
    self.`import`(from: ["lispkit", "math"],    "fx1+", "fx1-", "fx=", "fx>", "fx<", "fx<=", "fx>=")
  }
  
  /// Declarations of the library.
  public override func declarations() {
    self.define(Procedure("string?", isString))
    self.define(Procedure("make-string", makeString))
    self.define(Procedure("string", string))
    self.define(Procedure("string-ref", stringRef))
    self.define(Procedure("string-set!", stringSet))
    self.define(Procedure("string-length", stringLength))
    self.define(Procedure("string-append", stringAppend))
    self.define(Procedure("string-concatenate", stringConcatenate))
    self.define(Procedure("string=?", stringEquals))
    self.define(Procedure("string<?", stringLessThan))
    self.define(Procedure("string>?", stringLessThanEquals))
    self.define(Procedure("string<=?", stringGreaterThan))
    self.define(Procedure("string>=?", stringGreaterThanEquals))
    self.define(Procedure("string-ci=?", stringCiEquals))
    self.define(Procedure("string-ci<?", stringCiLessThan))
    self.define(Procedure("string-ci>?", stringCiLessThanEquals))
    self.define(Procedure("string-ci<=?", stringCiGreaterThan))
    self.define(Procedure("string-ci>=?", stringCiGreaterThanEquals))
    self.define(Procedure("string-contains?", stringContains))
    self.define(Procedure("string-upcase", stringUpcase))
    self.define(Procedure("string-downcase", stringDowncase))
    self.define(Procedure("string-titlecase", stringTitlecase))
    self.define(Procedure("string-foldcase", stringFoldcase))
    self.define(Procedure("list->string", listToString))
    self.define(Procedure("string->list", stringToList))
    self.define(Procedure("substring", substring))
    self.define(Procedure("string-copy", stringCopy))
    self.define(Procedure("string-copy!", stringInsert))
    self.define(Procedure("string-fill!", stringFill))
    self.define(Procedure("_string-list-ref", stringListRef))
    self.define(Procedure("_string-list-length", stringListLength))
    self.define("string-map", via:
      "(define (string-map f xs . xss)",
      "  (let* ((strs (cons xs xss))",
      "         (len (_string-list-length strs))",
      "         (res (make-string len)))",
      "    (if (null? xss)",
      "        (do ((i 0 (fx1+ i)))",
      "            ((fx>= i len) res)",
      "          (string-set! res i (f (string-ref xs i))))",
      "        (do ((i 0 (fx1+ i)))",
      "            ((fx>= i len) res)",
      "          (string-set! res i (apply f (_string-list-ref i strs)))))))")
    self.define("string-for-each", via:
      "(define (string-for-each f xs . xss)",
      "  (let* ((strs (cons xs xss))",
      "         (len (_string-list-length strs)))",
      "    (do ((i 0 (fx1+ i)))",
      "         ((fx>= i len))",
      "      (apply f (_string-list-ref i strs)))))")
  }
  
  func isString(_ expr: Expr) -> Expr {
    if case .string(_) = expr {
      return .true
    }
    return .false
  }
  
  func makeString(_ k: Expr, ch: Expr?) throws -> Expr {
    let uniChars = Array<UniChar>(repeating: try ch?.asUniChar() ?? UniChar(" "),
                                  count: try k.asInt())
    return .string(NSMutableString(string: String(utf16CodeUnits: uniChars, count: uniChars.count)))
  }
  
  func string(_ exprs: Arguments) throws -> Expr {
    var uniChars: [UniChar] = []
    for expr in exprs {
      uniChars.append(try expr.asUniChar())
    }
    return .string(NSMutableString(string: String(utf16CodeUnits: uniChars, count: uniChars.count)))
  }
  
  func stringLength(_ expr: Expr) throws -> Expr {
    return .fixnum(Int64(try expr.asString().utf16.count))
  }
  
  func stringListLength(_ strings: Expr) throws -> Expr {
    var n = Int.max
    var list = strings
    while case .pair(let expr, let next) = list {
      let str = try expr.asString().utf16
      if str.count < n {
        n = str.count
      }
      list = next
    }
    guard list.isNull else {
      throw EvalError.typeError(strings, [.properListType])
    }
    return .fixnum(Int64(n))
  }
  
  func stringRef(_ expr: Expr, _ index: Expr) throws -> Expr {
    let str = try expr.asString().utf16
    let k = try index.asInt()
    let i = str.index(str.startIndex, offsetBy: k)
    guard i < str.endIndex else {
      throw EvalError.indexOutOfBounds(Int64(k), Int64(str.count - 1), expr)
    }
    return .char(str[i])
  }
  
  func stringListRef(_ index: Expr, _ strings: Expr) throws -> Expr {
    let k = try index.asInt()
    var res = Exprs()
    var list = strings
    while case .pair(let expr, let next) = list {
      let str = try expr.asString().utf16
      let i = str.index(str.startIndex, offsetBy: k)
      guard i < str.endIndex else {
        return .false
      }
      res.append(.char(str[i]))
      list = next
    }
    guard list.isNull else {
      throw EvalError.typeError(strings, [.properListType])
    }
    return .makeList(res)
  }
  
  func stringSet(_ expr: Expr, _ index: Expr, char: Expr) throws -> Expr {
    let str = try expr.asMutableStr()
    str.replaceCharacters(in: NSRange(location: try index.asInt(below: str.length), length: 1),
                          with: String(utf16CodeUnits: [try char.asUniChar()], count: 1))
    return .void
  }
  
  func stringAppend(_ exprs: Arguments) throws -> Expr {
    let str = NSMutableString()
    for expr in exprs {
      str.append(try expr.asString())
    }
    return .string(str)
  }
  
  func stringConcatenate(_ expr: Expr) throws -> Expr {
    let res = NSMutableString()
    var list = expr
    while case .pair(let str, let next) = list {
      res.append(try str.asString())
      list = next
    }
    guard list.isNull else {
      throw EvalError.typeError(expr, [.properListType])
    }
    return .string(res)
  }
  
  func stringEquals(_ expr: Expr, _ args: Arguments) throws -> Expr {
    let str = try expr.asString()
    for arg in args {
      guard try str == arg.asString() else {
        return .false
      }
    }
    return .true
  }
  
  func stringLessThan(_ expr: Expr, _ args: Arguments) throws -> Expr {
    var str = try expr.asString()
    for arg in args {
      let next = try arg.asString()
      guard str < next else {
        return .false
      }
      str = next
    }
    return .true
  }
  
  func stringLessThanEquals(_ expr: Expr, _ args: Arguments) throws -> Expr {
    var str = try expr.asString()
    for arg in args {
      let next = try arg.asString()
      guard str <= next else {
        return .false
      }
      str = next
    }
    return .true
  }
  
  func stringGreaterThan(_ expr: Expr, _ args: Arguments) throws -> Expr {
    var str = try expr.asString()
    for arg in args {
      let next = try arg.asString()
      guard str > next else {
        return .false
      }
      str = next
    }
    return .true
  }
  
  func stringGreaterThanEquals(_ expr: Expr, _ args: Arguments) throws -> Expr {
    var str = try expr.asString()
    for arg in args {
      let next = try arg.asString()
      guard str >= next else {
        return .false
      }
      str = next
    }
    return .true
  }
  
  func stringCiEquals(_ expr: Expr, _ args: Arguments) throws -> Expr {
    let str = try expr.asString().lowercased()
    for arg in args {
      guard try str == arg.asString().lowercased() else {
        return .false
      }
    }
    return .true
  }
  
  func stringCiLessThan(_ expr: Expr, _ args: Arguments) throws -> Expr {
    var str = try expr.asString().lowercased()
    for arg in args {
      let next = try arg.asString().lowercased()
      guard str < next else {
        return .false
      }
      str = next
    }
    return .true
  }
  
  func stringCiLessThanEquals(_ expr: Expr, _ args: Arguments) throws -> Expr {
    var str = try expr.asString().lowercased()
    for arg in args {
      let next = try arg.asString().lowercased()
      guard str <= next else {
        return .false
      }
      str = next
    }
    return .true
  }
  
  func stringCiGreaterThan(_ expr: Expr, _ args: Arguments) throws -> Expr {
    var str = try expr.asString().lowercased()
    for arg in args {
      let next = try arg.asString().lowercased()
      guard str > next else {
        return .false
      }
      str = next
    }
    return .true
  }
  
  func stringCiGreaterThanEquals(_ expr: Expr, _ args: Arguments) throws -> Expr {
    var str = try expr.asString().lowercased()
    for arg in args {
      let next = try arg.asString().lowercased()
      guard str >= next else {
        return .false
      }
      str = next
    }
    return .true
  }
  
  func stringContains(_ expr: Expr, _ other: Expr) throws -> Expr {
    return .makeBoolean(try expr.asString().contains(try other.asString()))
  }
  
  func stringUpcase(_ expr: Expr) throws -> Expr {
    return .string(NSMutableString(string: try expr.asMutableStr().uppercased))
  }
  
  func stringDowncase(_ expr: Expr) throws -> Expr {
    return .string(NSMutableString(string: try expr.asMutableStr().lowercased))
  }
  
  func stringTitlecase(_ expr: Expr) throws -> Expr {
    return .string(NSMutableString(string: try expr.asMutableStr().capitalized))
  }
  
  func stringFoldcase(_ expr: Expr) throws -> Expr {
    return .string(NSMutableString(
      string: try expr.asMutableStr().folding(options: [.caseInsensitive], locale: nil)))
  }
  
  func stringToList(_ expr: Expr, args: Arguments) throws -> Expr {
    let str = try expr.asString().utf16
    guard let (s, e) = args.optional(Expr.makeNumber(0), Expr.makeNumber(str.count)) else {
      throw EvalError.argumentCountError(formals: 2, args: .pair(expr, .makeList(args)))
    }
    var end = try e.asInt(below: str.count + 1)
    let start = try s.asInt(below: end + 1)
    var i = str.index(str.startIndex, offsetBy: end)
    var res = Expr.null
    while end > start {
      i = str.index(before: i)
      res = .pair(.char(str[i]), res)
      end -= 1
    }
    return res
  }
  
  func listToString(_ expr: Expr) throws -> Expr {
    var list = expr
    var uniChars: [UniChar] = []
    while case .pair(let ch, let next) = list {
      uniChars.append(try ch.asUniChar())
      list = next
    }
    guard list.isNull else {
      throw EvalError.typeError(expr, [.properListType])
    }
    return .string(NSMutableString(string: String(utf16CodeUnits: uniChars, count: uniChars.count)))
  }
  
  func substring(_ expr: Expr, _ s: Expr, _ e: Expr) throws -> Expr {
    let str = try expr.asString().utf16
    let end = try e.asInt(below: str.count + 1)
    let start = try s.asInt(below: end + 1)
    // short-cut if this is a full copy
    if start == 0 && end == str.count {
      return .string(NSMutableString(string: try expr.asString()))
    }
    // extract substring
    let ei = str.index(str.startIndex, offsetBy: end)
    let si = str.index(str.startIndex, offsetBy: start)
    var uniChars: [UniChar] = []
    for ch in str[si..<ei] {
      uniChars.append(ch)
    }
    return .string(NSMutableString(string: String(utf16CodeUnits: uniChars, count: uniChars.count)))
  }
  
  func stringCopy(_ expr: Expr, args: Arguments) throws -> Expr {
    let str = try expr.asString().utf16
    guard let (s, e) = args.optional(Expr.makeNumber(0), Expr.makeNumber(str.count)) else {
      throw EvalError.argumentCountError(formals: 2, args: .pair(expr, .makeList(args)))
    }
    let end = try e.asInt(below: str.count + 1)
    let start = try s.asInt(below: end + 1)
    // short-cut if this is a full copy
    if start == 0 && end == str.count {
      return .string(NSMutableString(string: try expr.asString()))
    }
    // extract substring to copy
    let ei = str.index(str.startIndex, offsetBy: end)
    let si = str.index(str.startIndex, offsetBy: start)
    var uniChars: [UniChar] = []
    for ch in str[si..<ei] {
      uniChars.append(ch)
    }
    return .string(NSMutableString(string: String(utf16CodeUnits: uniChars, count: uniChars.count)))
  }
  
  func stringInsert(_ expr: Expr, _ index: Expr, _ from: Expr, args: Arguments) throws -> Expr {
    let str = try from.asString().utf16
    guard let (s, e) = args.optional(Expr.makeNumber(0), Expr.makeNumber(str.count)) else {
      throw EvalError.argumentCountError(formals: 2, args: .pair(expr, .makeList(args)))
    }
    let end = try e.asInt(below: str.count + 1)
    let ei = str.index(str.startIndex, offsetBy: end)
    let si = str.index(str.startIndex, offsetBy: try s.asInt(below: end + 1))
    var uniChars: [UniChar] = []
    for ch in str[si..<ei] {
      uniChars.append(ch)
    }
    let target = try expr.asMutableStr()
    target.insert(String(utf16CodeUnits: uniChars, count: uniChars.count),
                  at: try index.asInt(below: target.length + 1))
    return .void
  }
  
  func stringFill(_ expr: Expr, _ ch: Expr, _ args: Arguments) throws -> Expr {
    let str = try expr.asMutableStr()
    guard let (s, e) = args.optional(Expr.makeNumber(0), Expr.makeNumber(str.length)) else {
      throw EvalError.argumentCountError(formals: 2, args: .pair(expr, .makeList(args)))
    }
    let end = try e.asInt(below: str.length + 1)
    let start = try s.asInt(below: end + 1)
    if start < end {
      let uniChars = Array<UniChar>(repeating: try ch.asUniChar(), count: end - start)
      str.replaceCharacters(in: NSRange(location: start, length: end - start),
                            with: String(utf16CodeUnits: uniChars, count: uniChars.count))
    }
    return .void
  }
}
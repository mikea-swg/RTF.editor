//
//  IntegerNumber.swift
//  RTFEditor
//
//  Created by Josip Bernat on 26.05.2025..
//

import Foundation

protocol IntegerNumber {
    func toInt() -> Int
}

extension Int: IntegerNumber {
    func toInt() -> Int {
        self
    }
}

extension Float: IntegerNumber {
    func toInt() -> Int {
        Int(self)
    }
}

extension CGFloat: IntegerNumber {
    func toInt() -> Int {
        Int(self)
    }
    
    func formatted() -> String {
        if self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self) // No decimals
        } else {
            return String(format: "%.2f", self) // Two decimal places
        }
    }

}

extension Double: IntegerNumber {
    func toInt() -> Int {
        Int(self)
    }
}

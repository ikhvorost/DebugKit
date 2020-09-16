//
//  File.swift
//  
//
//  Created by Iurii Khvorost on 27.07.2020.
//

import Foundation

func synchronized<T : AnyObject, U>(_ obj: T, closure: () -> U) -> U {
	objc_sync_enter(obj)
	defer {
		objc_sync_exit(obj)
	}
	return closure()
}

@propertyWrapper
class Atomic<T> {
    private var value: T

    init(wrappedValue value: T) {
        self.value = value
    }

    var wrappedValue: T {
		get {
			synchronized(self) { value }
		}
		set {
			synchronized(self) { value = newValue }
		}
    }
}

public extension DispatchQueue {
    private static var _onceTracker = [String]()
	
    class func once(file: String = #file, function: String = #function, line: Int = #line, block:()->Void) {
        let token = file + ":" + function + ":" + String(line)
        once(token: token, block: block)
    }
	
    /**
     Executes a block of code, associated with a unique token, only once.  The code is thread safe and will
     only execute the code once even in the presence of multithreaded calls.
     - parameter token: A unique reverse DNS style name such as com.vectorform.<name> or a GUID
     - parameter block: Block to execute once
     */
    class func once(token: String, block:()->Void) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }
		
        guard !_onceTracker.contains(token)  else { return }
		
        _onceTracker.append(token)
		
        block()
    }
}

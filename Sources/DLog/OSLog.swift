//
//  OSLog.swift
//
//  Created by Iurii Khvorost <iurii.khvorost@gmail.com> on 2020/08/03.
//  Copyright © 2020 Iurii Khvorost. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//


import Foundation
import os
import os.log
import os.activity

/// A target output that sends log messages to the Unified Logging System.
///
/// It captures telemetry from your app for debugging and performance analysis and then you can use various tools to
/// retrieve log information such as: `Console` and `Instruments` apps, command line tool `"log"` etc.
///
public class OSLog : LogOutput {
	
	// Handle to dynamic shared object
	private static var dso = UnsafeMutableRawPointer(mutating: #dsohandle)
	
	// Load the symbol dynamically, since it is not exposed to Swift.
	private static let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
	private static let OS_ACTIVITY_NONE = unsafeBitCast(dlsym(RTLD_DEFAULT, "_os_activity_none"), to: os_activity_t.self)
	private static let OS_ACTIVITY_CURRENT = unsafeBitCast(dlsym(RTLD_DEFAULT, "_os_activity_current"), to: os_activity_t.self)
	
	private static let types: [LogType : OSLogType] = [
		.log : .default,
		// Debug
		.trace : .debug,
		.debug : .debug,
		// Info
		.info : .info,
		// Error
		.warning : .error,
		.error : .error,
		// Fault
		.assert : .fault,
		.fault : .fault,
	]
	
	private var subsystem: String
	@Atomic private var logs = [String : os.OSLog]()
	
	/// Creates`OSlog` output object.
	///
	/// To create OSLog you can use subsystem strings that identify major functional areas of your app, and you specify
	/// them in reverse DNS notation—for example, com.your_company.your_subsystem_name.
	///
	/// 	let log = DLog(OSLog(subsystem: "com.myapp.logger"))
	///
	/// - Parameters:
	///		- subsystem: An identifier string, in reverse DNS notation, that represents the subsystem that’s performing
	///		logging (defaults to `"com.dlog.logger"`).
	///		- source: A source output (defaults to `.textPlain`)
	///
	public init(subsystem: String = "com.dlog.logger", source: LogOutput = .textPlain) {
		self.subsystem = subsystem
		
		super.init(source: source)
	}
	
	private func oslog(category: String) -> os.OSLog {
		synchronized(self) {
			if let log = logs[category] {
				return log
			}
			let log = os.OSLog(subsystem: subsystem, category: category)
			logs[category] = log
			return log
		}
	}
	
	// MARK: - LogOutput
	
	override func log(item: LogItem, scopes: [LogScope]) -> String? {
		let log = oslog(category: item.category)
		
		let location = "<\(item.fileName):\(item.line)>"
		
		assert(Self.types[item.type] != nil)
		let type = Self.types[item.type]!
		os_log("%{public}@ %{public}@", dso: Self.dso, log: log, type: type, location, item.text)
	
		return super.log(item: item, scopes: scopes)
	}
	
	override func scopeEnter(scope: LogScope, scopes: [LogScope]) -> String? {
		let activity = _os_activity_create(Self.dso, strdup(scope.text), Self.OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
		os_activity_scope_enter(activity, &scope.os_state)
		
		return super.scopeEnter(scope: scope, scopes: scopes)
	}
	
	override func scopeLeave(scope: LogScope, scopes: [LogScope]) -> String? {
		os_activity_scope_leave(&scope.os_state);
		
		return super.scopeLeave(scope: scope, scopes: scopes)
	}
	
	override func intervalBegin(interval: LogInterval) {
		super.intervalBegin(interval: interval)
		
		let log = oslog(category: interval.category)
		if interval.signpostID == nil {
			interval.signpostID = OSSignpostID(log: log)
		}

		os_signpost(.begin, log: log, name: interval.name, signpostID: interval.signpostID!)
	}
	
	override func intervalEnd(interval: LogInterval, scopes: [LogScope]) -> String? {
		let log = oslog(category: interval.category)
		os_signpost(.end, log: log, name: interval.name, signpostID: interval.signpostID!)
		return super.intervalEnd(interval: interval, scopes: scopes)
	}
}

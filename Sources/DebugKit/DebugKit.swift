import Foundation
import os.log
import os.activity

// https://nshipster.com/swift-log/
// log stream --predicate 'eventMessage CONTAINS[c] "[dlog]"' --style syslog
// logger: level, filter by files

// oslog
// .tracev3
// stored /var/db/diagnostics/ with support in /var/db/uuidtext


let debugDateFormatter: DateFormatter = {
	let dateFormatter = DateFormatter()
	dateFormatter.dateFormat = "HH:mm:ss:SSS"
	return dateFormatter
}()


enum Platform {
	case macOS
	case macCatalyst
	case tvOS
	case watchOS
	case iOS
	
	static var current : Platform {
		#if os(OSX)
			return .macOS
		#elseif os(watchOS)
			return .watchOS
		#elseif os(tvOS)
			return .tvOS
		#elseif os(iOS)
			#if targetEnvironment(macCatalyst)
				return .macCatalyst
			#else
				return .iOS
			#endif
		#endif
	}
}

struct DebugKit {
    
}

// https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html
enum ANSIEscapeCode: String {
    case textBlack = "\u{001B}[30m"
    case textRed = "\u{001B}[31m"
    case textGreen = "\u{001B}[32m"
    case textYellow = "\u{001B}[33m"
    case textBlue = "\u{001B}[34m"
    case textMagenta = "\u{001B}[35m"
    case textCyan = "\u{001B}[36m"
    case textWhite = "\u{001B}[37m"
	
	case textBrightBlack = "\u{001b}[30;1m"
	case textBrightRed = "\u{001b}[31;1m"
	case textBrightGreen = "\u{001b}[32;1m"
	case textBrightYellow = "\u{001b}[33;1m"
	case textBrightBlue = "\u{001b}[34;1m"
	case textBrightMagenta = "\u{001b}[35;1m"
	case textBrightCyan = "\u{001b}[36;1m"
	case textBrightWhite = "\u{001b}[37;1m"
	
	case backgroundBlack = "\u{001b}[40m"
	case backgrounRed = "\u{001b}[41m"
	case backgroundGreen = "\u{001b}[42m"
	case backgroundYellow = "\u{001b}[43m"
	case backgroundBlue = "\u{001b}[44m"
	case backgroundMagenta = "\u{001b}[45m"
	case backgroundCyan = "\u{001b}[46m"
	case backgroundWhite = "\u{001b}[47m"
	
	case bold = "\u{001b}[1m"
	case underline = "\u{001b}[4m"
	case reversed = "\u{001b}[7m"
	
    case reset = "\u{001B}[0m"
}

extension String {
	func escape(code: ANSIEscapeCode) -> String {
		return "\(code.rawValue)\(self)\(ANSIEscapeCode.reset.rawValue)"
	}
}

extension OSLogType : Hashable {
	public var hashValue: Int {
		switch self {
			case .default:
				return 0
			case .info:
				return 1
			case .debug:
				return 2
			case .error:
				return 3
			case .fault:
				return 4
			default:
				return 0
		}
	}
}

public struct LogType  {
	let icon: Character
	let name: String
	let type: OSLogType
	
	static let trace = LogType(icon: "✳️", name: "TRACE", type: OSLogType.default)
	static let info = LogType(icon: "ℹ️", name: "INFO", type: OSLogType.info)
	static let debug = LogType(icon: "▶️", name: "DEBUG", type: OSLogType.debug)
	static let error = LogType(icon: "⚠️", name: "ERROR", type: OSLogType.error)
	static let fault = LogType(icon: "🛑", name: "FAULT", type: OSLogType.fault)
	
	static let assert = LogType(icon: "🅰️", name: "ASSERT", type: OSLogType.debug)
}

public struct LogMessage {
	let category: String
	let text: String
	let type: LogType
	let time: String
	let fileName: String
	let function: String
	let line: UInt
	let scope: LogScope?
}

public class LogScope {
	let level: Int
	let name: String
	let time = Date()
	let category: String
	var os_state = os_activity_scope_state_s()
	//let parent: Scope?
	
	init(level: Int, name: String, category: String) {
		self.level = level
		self.name = name
		self.category = category
	}
}

public protocol LogOutput {
	func log(message: LogMessage)
	
	func scopeEnter(scope: LogScope)
	func scopeLeave(scope: LogScope)
}

public class XConsoleOutput : LogOutput {
	
	func write(category: String, time: String, padding: String, icon: String, type: LogType, location: String, text: String) {
		print(time, "[\(category)]", padding, icon, "[\(type.name)]", location, text)
	}
	
	func writeScope(scope: LogScope, start: Bool) {
		let time = debugDateFormatter.string(from: Date())
		
		let icon = start ? "┌" : "└"
		let padding = String(repeating: "|\t", count: scope.level-1) + icon
		
		let interval = Int(scope.time.timeIntervalSinceNow * -1000)
		let ms = !start ? "(\(interval) ms)" : nil
			
		print(time, "[\(scope.category)]", padding, "[\(scope.name)]", ms ?? "")
	}
	
	public func log(message: LogMessage) {
		var padding = ""
		if let scope = message.scope {
			padding = String(repeating: "|\t", count: scope.level)
		}
		
		write(category: message.category, time: message.time, padding: padding, icon: "\(message.type.icon)", type: message.type, location: "<\(message.fileName):\(message.line)>", text: message.text)
	}
	
	public func scopeEnter(scope: LogScope) {
		writeScope(scope: scope, start: true)
	}
	
	public func scopeLeave(scope: LogScope) {
		writeScope(scope: scope, start: false)
	}
}

public class TerminalOutput : XConsoleOutput {
	
	struct Colors {
		let textColor: ANSIEscapeCode
		let backgroundColor: ANSIEscapeCode
	}
	
	static let colors = [
		OSLogType.default : Colors(textColor: .textGreen, backgroundColor: .backgroundGreen),
		OSLogType.info : Colors(textColor: .textBrightBlack, backgroundColor: .backgroundBlue),
		OSLogType.debug : Colors(textColor: .textWhite, backgroundColor: .reversed),
		OSLogType.error : Colors(textColor: .textYellow, backgroundColor: .backgroundYellow),
		OSLogType.fault : Colors(textColor: .textRed, backgroundColor: .backgrounRed)
	]
	
	override func write(category: String, time: String, padding: String, icon: String, type: LogType, location: String, text: String) {
		var tag = "[\(type.name)]"
		var file = location.escape(code: .underline)
		var msg = text

		if let color = Self.colors[type.type] {
			tag = tag.escape(code: color.backgroundColor)
			file = file.escape(code: color.textColor)
			msg = msg.escape(code: color.textColor)
		}
		
		print(time, "[\(category)]", padding, tag, file, msg)
	}
}

public class OSLogOutput : LogOutput {
	
	// Formatters
	//	Type Format String Example Output
	//	time_t %{time_t}d 2016-01-12 19:41:37
	//	timeval %{timeval}.*P 2016-01-12 19:41:37.774236
	//	timespec %{timespec}.*P 2016-01-12 19:41:37.774236823
	//	errno %{errno}d Broken pipe
	//	uuid_t %{uuid_t}.16P
	//	%{uuid_t}.*P 10742E39-0657-41F8-AB99-878C5EC2DCAA
	//	sockaddr %{network:sockaddr}.*P fe80::f:86ff:fee9:5c16
	//	17.43.23.87
	//	in_addr %{network:in_addr}d 17.43.23.87
	//	in6_addr %{network:in6_addr}.16P fe80::f:86ff:fee9:5c16
	
	// Handle to dynamic shared object
	static var dso = UnsafeMutableRawPointer(mutating: #dsohandle)
	
	// Load the symbol dynamically, since it is not exposed to Swift...
	// see activity.h and dlfcn.h
	// https://nsscreencast.com/episodes/347-activity-tracing-in-swift
	// https://gist.github.com/zwaldowski/49f61292757f86d7d036a529f2d04f0c
	static let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
	static let OS_ACTIVITY_NONE = unsafeBitCast(dlsym(RTLD_DEFAULT, "_os_activity_none"), to: os_activity_t.self)
	static let OS_ACTIVITY_CURRENT = unsafeBitCast(dlsym(RTLD_DEFAULT, "_os_activity_current"), to: os_activity_t.self)
	
	var log: OSLog?
	
	private func oslog(category: String) -> OSLog {
		DispatchQueue.once {
			let subsystem = Bundle.main.bundleIdentifier ?? ""
			log = OSLog(subsystem: subsystem, category: category)
		}
		assert(log != nil)
		return log!
	}
	
	public func log(message: LogMessage) {
		let log = oslog(category: message.category)
		
		let location = "<\(message.fileName):\(message.line)>"
		os_log("%s %s", dso: Self.dso, log: log, type: message.type.type, location, message.text)
	}
	
	public func scopeEnter(scope: LogScope) {
		let activity = _os_activity_create(Self.dso, strdup(scope.name), Self.OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT)
		os_activity_scope_enter(activity, &scope.os_state)
	}
	
	public func scopeLeave(scope: LogScope) {
		os_activity_scope_leave(&scope.os_state);
	}
}

public class AdaptiveOutput : LogOutput {
	let output: LogOutput
	
	static var isDebug : Bool {
		var info = kinfo_proc()
		var mib : [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
		var size = MemoryLayout<kinfo_proc>.stride
		let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
		assert(junk == 0, "sysctl failed")
		return (info.kp_proc.p_flag & P_TRACED) != 0
	}
	
	static var isTerminal : Bool {
		return ProcessInfo.processInfo.environment["_"] != nil
	}
	
	init() {
		if Self.isDebug {
			output = XConsoleOutput()
		}
		else {
			output  = Self.isTerminal ? TerminalOutput() : OSLogOutput()
		}
	}
	
	public func log(message: LogMessage) {
		output.log(message: message)
	}
	
	public func scopeEnter(scope: LogScope) {
		output.scopeEnter(scope: scope)
	}
	
	public func scopeLeave(scope: LogScope) {
		output.scopeLeave(scope: scope)
	}
}

//public class FileOutput : LogOutput {
//}

//public class RestOutput : LogOutput {
//}

//public class FTPOutput : LogOutput {
//}

//public class SQLOutput : LogOutput {
//}

//public class JSONOutput : LogOutput {
//}

public class DLog {
	private let category: String
	private let outputs: [LogOutput]
	//private var level = .debug
	
	var scopes = [LogScope]()
	
	init(category: String = "DLOG", output: [LogOutput] = [AdaptiveOutput()]) {
		self.category = category
		self.outputs = output
	}
	
	private func log(_ text: String, type: LogType, file: String, function: String, line: UInt) {
		let fileName = NSString(string: file).lastPathComponent
		let time = debugDateFormatter.string(from: Date())
		
		let message = LogMessage(category: category, text: text, type: type, time: time, fileName: fileName, function: function, line: line, scope: scopes.last)
		outputs.forEach {
			$0.log(message: message)
		}
	}
	
	public func trace(_ text: String, file: String = #file, function: String = #function, line: UInt = #line) {
		log(text != "" ? text : function, type: .trace, file: file, function: function, line: line)
	}
	
	public func info(_ text: String, file: String = #file, function: String = #function, line: UInt = #line) {
		log(text, type: .info, file: file, function: function, line: line)
	}
	
	public func debug(_ text: String, file: String = #file, function: String = #function, line: UInt = #line) {
		log(text, type: .debug, file: file, function: function, line: line)
	}
	
	public func error(_ error: Error, file: String = #file, function: String = #function, line: UInt = #line) {
		log(error.localizedDescription, type: .error, file: file, function: function, line: line)
	}
	
	public func fault(_ text: String, file: String = #file, function: String = #function, line: UInt = #line) {
		log(text, type: .fault, file: file, function: function, line: line)
	}
	
	//public func assert(_ text: String, file: String = #file, function: String = #function, line: UInt = #line)
	//public func fail(_ text: String, file: String = #file, function: String = #function, line: UInt = #line)
	
	// MARK: - Scope
	
	public func scopeCreate(_ name: String) -> LogScope {
		let scope = LogScope(level: scopes.count + 1, name: name, category: category)
		scopes.append(scope)
		return scope
	}
	
	func scopeEnter(_ scope: LogScope) {
		outputs.forEach { $0.scopeEnter(scope: scope) }
	}
	
	func scopeLeave(_ scope: LogScope) {
		outputs.forEach { $0.scopeLeave(scope: scope) }
		scopes.removeLast()
	}
	
	public func scope(_ name: String, closure: () -> Void) {
		let scope = scopeCreate(name)
		
		scopeEnter(scope)
		
		closure()
		
		scopeLeave(scope)
	}
}
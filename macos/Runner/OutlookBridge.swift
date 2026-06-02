import Cocoa
import FlutterMacOS

/// Bridges Flutter to Microsoft Outlook for Mac via AppleScript.
/// Used as a fallback calendar source when an Outlook ICS feed is
/// blocked (e.g. by a corporate network extension like Defender).
class OutlookBridge {
  static let channelName = "com.caltask/outlook"

  init(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        result(Self.isOutlookInstalled())
      case "fetchEvents":
        let args = call.arguments as? [String: Any] ?? [:]
        let daysBack    = args["daysBack"]    as? Int ?? 30
        let daysForward = args["daysForward"] as? Int ?? 30
        Self.fetchEvents(daysBack: daysBack, daysForward: daysForward, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - Availability

  private static func isOutlookInstalled() -> Bool {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.Outlook") != nil
  }

  // MARK: - Fetch

  private static func fetchEvents(daysBack: Int, daysForward: Int,
                                  result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      let script = buildScript(daysBack: daysBack, daysForward: daysForward)
      guard let appleScript = NSAppleScript(source: script) else {
        DispatchQueue.main.async {
          result(FlutterError(code: "INIT_FAILED",
                              message: "Could not create NSAppleScript", details: nil))
        }
        return
      }

      var errorDict: NSDictionary?
      let descriptor = appleScript.executeAndReturnError(&errorDict)

      if let err = errorDict {
        let msg = (err[NSAppleScript.errorMessage] as? String) ?? "\(err)"
        DispatchQueue.main.async {
          result(FlutterError(code: "APPLESCRIPT_ERROR", message: msg, details: nil))
        }
        return
      }

      let events = parseDescriptor(descriptor)
      DispatchQueue.main.async { result(events) }
    }
  }

  // MARK: - AppleScript builder

  private static func buildScript(daysBack: Int, daysForward: Int) -> String {
    """
    -- Helper: zero-pad a number to 2 digits
    on pad2(n)
        set s to n as text
        if length of s = 1 then set s to "0" & s
        return s
    end pad2

    -- Helper: format an AppleScript date as a local ISO-8601 string (no TZ suffix)
    on toISO(d)
        set y  to year of d as text
        set mo to my pad2(month of d as integer)
        set dy to my pad2(day of d)
        set h  to my pad2(hours of d)
        set mi to my pad2(minutes of d)
        set s  to my pad2(seconds of d)
        return y & "-" & mo & "-" & dy & "T" & h & ":" & mi & ":" & s
    end toISO

    tell application "Microsoft Outlook"
        set windowStart to (current date) - (\(daysBack) * days)
        set windowEnd   to (current date) + (\(daysForward) * days)
        set allRows to {}
        repeat with cal in every calendar
            try
                set calEvents to events of cal whose start time >= windowStart and start time <= windowEnd
                repeat with evt in calEvents
                    try
                        set startISO to my toISO(start time of evt)
                        set endISO   to my toISO(end time of evt)
                        -- Row: {id, title, start, end, location, allDay, calendarName}
                        set row to {(id of evt) as text, ¬
                                    subject of evt, ¬
                                    startISO, ¬
                                    endISO, ¬
                                    location of evt, ¬
                                    (all day flag of evt) as text, ¬
                                    name of cal}
                        set end of allRows to row
                    end try
                end repeat
            end try
        end repeat
        return allRows
    end tell
    """
  }

  // MARK: - Descriptor parser

  /// Converts the AppleScript result (list of 7-element lists) into
  /// a Flutter-friendly [[String: Any]] array.
  private static func parseDescriptor(_ descriptor: NSAppleEventDescriptor?) -> [[String: Any]] {
    guard let list = descriptor, list.numberOfItems > 0 else { return [] }
    var events: [[String: Any]] = []

    for i in 1...list.numberOfItems {
      guard let row = list.atIndex(i), row.numberOfItems == 7 else { continue }
      let id       = row.atIndex(1)?.stringValue ?? UUID().uuidString
      let title    = row.atIndex(2)?.stringValue ?? ""
      let start    = row.atIndex(3)?.stringValue ?? ""
      let end      = row.atIndex(4)?.stringValue ?? start
      let location = row.atIndex(5)?.stringValue ?? ""
      let allDay   = row.atIndex(6)?.stringValue == "true"
      let calName  = row.atIndex(7)?.stringValue ?? ""

      guard !title.isEmpty, !start.isEmpty else { continue }

      events.append([
        "id":           id,
        "title":        title,
        "start":        start,
        "end":          end,
        "location":     location,
        "isAllDay":     allDay,
        "calendarName": calName,
      ])
    }
    return events
  }
}

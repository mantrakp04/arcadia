import AppKit

final class LeftEdgeWatcher {
  static let shared = LeftEdgeWatcher()
  static let reach: CGFloat = 24

  var emit: ((String, [String: Any]) -> Void)?
  var pointerOverridden = false
  private var watched: Set<String> = []
  private var over: Set<String> = []
  private var monitors: [Any] = []

  private static let pointerEvents: NSEvent.EventTypeMask = [
    .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseUp, .rightMouseUp, .otherMouseUp,
  ]

  func watch(id: String, on: Bool) {
    over.remove(id)
    if on {
      watched.insert(id)
    } else {
      watched.remove(id)
    }
    if watched.isEmpty { return stop() }
    start()
    checkPointer()
  }

  private func checkPointer() {
    if pointerOverridden { return }
    check(NSEvent.mouseLocation, live: true)
  }

  func check(_ point: NSPoint, live: Bool) {
    for id in watched {
      guard let window = WindowManager.shared.windows[id] else {
        watched.remove(id)
        over.remove(id)
        continue
      }
      let now = isBeside(point, of: window, live: live)
      guard now != over.contains(id) else { continue }
      if now { over.insert(id) } else { over.remove(id) }
      let frame = window.frame
      emit?("onWindowEvent", ["type": "leftEdge", "id": id, "over": now, "point": [point.x - frame.minX, frame.maxY - point.y]])
    }
    if watched.isEmpty { stop() }
  }

  private func isBeside(_ point: NSPoint, of window: NSWindow, live: Bool) -> Bool {
    guard window.isVisible, !window.isMiniaturized, !window.styleMask.contains(.fullScreen), let screen = window.screen else { return false }
    let frame = window.frame
    guard point.x < frame.minX, point.x >= max(screen.frame.minX, frame.minX - Self.reach),
          point.y >= frame.minY, point.y < frame.maxY else { return false }
    guard live else { return true }
    let edge = NSPoint(x: frame.minX + 1, y: point.y)
    guard NSWindow.windowNumber(at: edge, belowWindowWithWindowNumber: 0) == window.windowNumber else { return false }
    let under = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
    if under != window.windowNumber, NSApp.window(withWindowNumber: under) != nil { return false }
    return NSApp.isActive || frame.minX - screen.frame.minX <= Self.reach
  }

  private func start() {
    guard monitors.isEmpty else { return }
    if let global = NSEvent.addGlobalMonitorForEvents(matching: Self.pointerEvents, handler: { [weak self] _ in
      self?.checkPointer()
    }) {
      monitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(matching: Self.pointerEvents, handler: { [weak self] event in
      self?.checkPointer()
      return event
    }) {
      monitors.append(local)
    }
  }

  func reset() {
    watched = []
    over = []
    stop()
  }

  private func stop() {
    for monitor in monitors { NSEvent.removeMonitor(monitor) }
    monitors = []
  }
}

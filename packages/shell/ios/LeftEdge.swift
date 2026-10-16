import AppKit

final class LeftEdgeWatcher {
  static let shared = LeftEdgeWatcher()
  static let maxGap: CGFloat = 24

  var emit: ((String, [String: Any]) -> Void)?
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
    check(NSEvent.mouseLocation, occlusion: true)
  }

  func check(_ point: NSPoint, occlusion: Bool) {
    for id in watched {
      guard let window = WindowManager.shared.windows[id] else {
        watched.remove(id)
        over.remove(id)
        continue
      }
      let now = isOverGap(point, of: window, occlusion: occlusion)
      guard now != over.contains(id) else { continue }
      if now { over.insert(id) } else { over.remove(id) }
      let frame = window.frame
      emit?("onWindowEvent", ["type": "leftEdge", "id": id, "over": now, "point": [point.x - frame.minX, frame.maxY - point.y]])
    }
    if watched.isEmpty { stop() }
  }

  private func isOverGap(_ point: NSPoint, of window: NSWindow, occlusion: Bool) -> Bool {
    guard window.isVisible, !window.isMiniaturized, !window.styleMask.contains(.fullScreen), let screen = window.screen else { return false }
    let frame = window.frame
    let gap = frame.minX - screen.frame.minX
    guard gap > 0, gap <= Self.maxGap, point.x >= screen.frame.minX, point.x < frame.minX,
          point.y >= frame.minY, point.y < frame.maxY else { return false }
    guard occlusion else { return true }
    let edge = NSPoint(x: frame.minX + 1, y: point.y)
    return NSWindow.windowNumber(at: edge, belowWindowWithWindowNumber: 0) == window.windowNumber
  }

  private func start() {
    guard monitors.isEmpty else { return }
    if let global = NSEvent.addGlobalMonitorForEvents(matching: Self.pointerEvents, handler: { [weak self] _ in
      self?.check(NSEvent.mouseLocation, occlusion: true)
    }) {
      monitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(matching: Self.pointerEvents, handler: { [weak self] event in
      self?.check(NSEvent.mouseLocation, occlusion: true)
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

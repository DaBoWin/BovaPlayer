import Cocoa
import FlutterMacOS
import SystemConfiguration

@main
class AppDelegate: FlutterAppDelegate {
  private var lastBytesIn: UInt64 = 0
  private var lastBytesOut: UInt64 = 0
  private var lastCheckTime: Date = Date()
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    
    // 注册红绿灯控制的 MethodChannel
    let trafficLightsChannel = FlutterMethodChannel(
      name: "com.bovaplayer/traffic_lights",
      binaryMessenger: controller.engine.binaryMessenger
    )

    trafficLightsChannel.setMethodCallHandler { [weak self] (call, result) in
      guard let window = self?.mainFlutterWindow else {
        result(FlutterError(code: "NO_WINDOW", message: "Main window not found", details: nil))
        return
      }
      switch call.method {
      case "hide":
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        result(nil)
      case "show":
        window.standardWindowButton(.closeButton)?.isHidden = false
        window.standardWindowButton(.miniaturizeButton)?.isHidden = false
        window.standardWindowButton(.zoomButton)?.isHidden = false
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    
    // 注册网络速度监控的 MethodChannel
    let networkSpeedChannel = FlutterMethodChannel(
      name: "com.bovaplayer/network_speed",
      binaryMessenger: controller.engine.binaryMessenger
    )
    
    networkSpeedChannel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "getNetworkSpeed":
        if let speed = self?.getNetworkSpeed() {
          result(speed)
        } else {
          result(0.0)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.applicationDidFinishLaunching(notification)
  }
  
  // 获取网络速度（字节/秒）
  private func getNetworkSpeed() -> Double {
    let now = Date()
    let timeDiff = now.timeIntervalSince(lastCheckTime)
    
    guard timeDiff > 0 else { return 0.0 }
    
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return 0.0 }
    defer { freeifaddrs(ifaddr) }
    
    var totalBytesIn: UInt64 = 0
    var totalBytesOut: UInt64 = 0
    
    var ptr = ifaddr
    while ptr != nil {
      defer { ptr = ptr?.pointee.ifa_next }
      
      guard let interface = ptr?.pointee else { continue }
      let name = String(cString: interface.ifa_name)
      
      // 只统计活跃的网络接口（en0=WiFi, en1=以太网等）
      guard name.hasPrefix("en") || name.hasPrefix("pdp_ip") else { continue }
      
      guard let addr = interface.ifa_addr else { continue }
      guard addr.pointee.sa_family == UInt8(AF_LINK) else { continue }
      
      let data = unsafeBitCast(addr, to: UnsafeMutablePointer<sockaddr_dl>.self)
      
      if data.pointee.sdl_type == IFT_ETHER || data.pointee.sdl_type == IFT_CELLULAR {
        var networkData: UnsafeMutablePointer<if_data>?
        
        if let dataPtr = interface.ifa_data {
          networkData = dataPtr.assumingMemoryBound(to: if_data.self)
        }
        
        if let stats = networkData?.pointee {
          totalBytesIn += UInt64(stats.ifi_ibytes)
          totalBytesOut += UInt64(stats.ifi_obytes)
        }
      }
    }
    
    // 计算速度（只计算下载速度）
    let speed: Double
    if lastBytesIn > 0 && totalBytesIn >= lastBytesIn {
      let bytesDiff = Double(totalBytesIn - lastBytesIn)
      speed = bytesDiff / timeDiff
    } else {
      speed = 0.0
    }
    
    lastBytesIn = totalBytesIn
    lastBytesOut = totalBytesOut
    lastCheckTime = now
    
    return speed
  }
}

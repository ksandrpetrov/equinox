import ServiceManagement

enum LaunchAtLogin {
    static var status: SMAppService.Status {
        SMAppService.mainApp.status
    }

    static var isEnabled: Bool {
        status == .enabled
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) throws -> SMAppService.Status {
        if enabled {
            if status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if status != .notRegistered {
                try SMAppService.mainApp.unregister()
            }
        }
        return status
    }
}

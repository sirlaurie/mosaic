import Foundation
import Combine

class UserPreferences: ObservableObject {
    static let shared = UserPreferences()
    
    @Published var customLazyDirectories: [String] {
        didSet {
            UserDefaults.standard.set(customLazyDirectories, forKey: "customLazyDirectories")
        }
    }
    
    private init() {
        self.customLazyDirectories = UserDefaults.standard.stringArray(forKey: "customLazyDirectories") ?? []
    }
    
    func addDirectory(_ name: String) {
        if !customLazyDirectories.contains(name) {
            customLazyDirectories.append(name)
        }
    }
    
    func removeDirectory(_ name: String) {
        customLazyDirectories.removeAll { $0 == name }
    }
}

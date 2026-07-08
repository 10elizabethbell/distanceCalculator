import AppKit
import CoreLocation
import MapKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var resultItem: NSMenuItem!
    private let geocoder = CLGeocoder()
    private let originAddress = "51 Franklin Ave, Seaside Heights, NJ"
    private var geocodeCache: [String: CLLocationCoordinate2D] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🚗"

        let menu = NSMenu()
        menu.autoenablesItems = false

        let originItem = NSMenuItem(title: "From: \(originAddress)", action: nil, keyEquivalent: "")
        originItem.isEnabled = false
        menu.addItem(originItem)

        resultItem = NSMenuItem(title: "No trip calculated yet", action: nil, keyEquivalent: "")
        resultItem.isEnabled = false
        menu.addItem(resultItem)

        menu.addItem(.separator())

        let calcItem = NSMenuItem(title: "Calculate Drive Time…", action: #selector(promptForDestination), keyEquivalent: "d")
        calcItem.target = self
        menu.addItem(calcItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func promptForDestination() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Drive Time Calculator"
        alert.addButton(withTitle: "Calculate")
        alert.addButton(withTitle: "Cancel")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 96))
        let fromLabel = NSTextField(labelWithString: "From:")
        fromLabel.frame = NSRect(x: 0, y: 78, width: 280, height: 16)
        let fromField = NSTextField(frame: NSRect(x: 0, y: 52, width: 280, height: 24))
        fromField.stringValue = originAddress
        let toLabel = NSTextField(labelWithString: "To:")
        toLabel.frame = NSRect(x: 0, y: 28, width: 280, height: 16)
        let toField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        toField.placeholderString = "e.g. Philadelphia"
        container.addSubview(fromLabel)
        container.addSubview(fromField)
        container.addSubview(toLabel)
        container.addSubview(toField)
        alert.accessoryView = container
        alert.window.initialFirstResponder = toField

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let origin = fromField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = toField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !origin.isEmpty, !destination.isEmpty else { return }

        statusItem.button?.title = "🚗 …"
        cachedGeocode(origin) { [weak self] originResult in
            guard let self else { return }
            switch originResult {
            case .failure(let error):
                self.finish(with: .failure(error), origin: origin, destination: destination)
            case .success(let originCoordinate):
                self.cachedGeocode(destination) { destResult in
                    switch destResult {
                    case .failure(let error):
                        self.finish(with: .failure(error), origin: origin, destination: destination)
                    case .success(let destCoordinate):
                        self.calculateETA(from: originCoordinate, to: destCoordinate,
                                          originName: origin, destinationName: destination)
                    }
                }
            }
        }
    }

    private func cachedGeocode(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        if let cached = geocodeCache[address] {
            completion(.success(cached))
            return
        }
        geocode(address) { [weak self] result in
            if case .success(let coordinate) = result {
                self?.geocodeCache[address] = coordinate
            }
            completion(result)
        }
    }

    private func geocode(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        geocoder.geocodeAddressString(address) { placemarks, error in
            DispatchQueue.main.async {
                if let coordinate = placemarks?.first?.location?.coordinate {
                    completion(.success(coordinate))
                } else {
                    let message = "Could not find “\(address)”"
                    completion(.failure(error ?? NSError(
                        domain: "DistanceCalculator", code: 1,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )))
                }
            }
        }
    }

    private func calculateETA(from origin: CLLocationCoordinate2D,
                              to destination: CLLocationCoordinate2D,
                              originName: String,
                              destinationName: String) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        MKDirections(request: request).calculateETA { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let response {
                    self.finish(with: .success(response), origin: originName, destination: destinationName)
                } else {
                    self.finish(with: .failure(error ?? NSError(
                        domain: "DistanceCalculator", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No driving route found."]
                    )), origin: originName, destination: destinationName)
                }
            }
        }
    }

    private func finish(with result: Result<MKDirections.ETAResponse, Error>, origin: String, destination: String) {
        statusItem.button?.title = "🚗"

        let alert = NSAlert()
        switch result {
        case .success(let response):
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .short
            let time = formatter.string(from: response.expectedTravelTime) ?? "?"
            let miles = response.distance / 1609.344
            let summary = "\(time) (\(String(format: "%.0f", miles)) mi)"

            resultItem.title = "To \(destination): \(summary)"
            alert.messageText = "Drive time to \(destination)"
            alert.informativeText = "\(summary)\n\nFrom: \(origin)"
        case .failure(let error):
            alert.alertStyle = .warning
            alert.messageText = "Couldn’t calculate drive time"
            alert.informativeText = error.localizedDescription
        }
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

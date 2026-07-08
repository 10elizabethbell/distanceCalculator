import AppKit
import CoreLocation
import MapKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var resultItem: NSMenuItem!
    private let geocoder = CLGeocoder()
    private let originAddress = "51 Franklin Ave, Seaside Heights, NJ"
    private var cachedOriginCoordinate: CLLocationCoordinate2D?

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
        alert.informativeText = "From: \(originAddress)\n\nEnter the destination city:"
        alert.addButton(withTitle: "Calculate")
        alert.addButton(withTitle: "Cancel")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "e.g. Philadelphia"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let destination = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return }

        statusItem.button?.title = "🚗 …"
        resolveOrigin { [weak self] originResult in
            guard let self else { return }
            switch originResult {
            case .failure(let error):
                self.finish(with: .failure(error), destination: destination)
            case .success(let origin):
                self.geocode(destination) { destResult in
                    switch destResult {
                    case .failure(let error):
                        self.finish(with: .failure(error), destination: destination)
                    case .success(let dest):
                        self.calculateETA(from: origin, to: dest, destinationName: destination)
                    }
                }
            }
        }
    }

    private func resolveOrigin(completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        if let cached = cachedOriginCoordinate {
            completion(.success(cached))
            return
        }
        geocode(originAddress) { [weak self] result in
            if case .success(let coordinate) = result {
                self?.cachedOriginCoordinate = coordinate
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
                              destinationName: String) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        MKDirections(request: request).calculateETA { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let response {
                    self.finish(with: .success(response), destination: destinationName)
                } else {
                    self.finish(with: .failure(error ?? NSError(
                        domain: "DistanceCalculator", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "No driving route found."]
                    )), destination: destinationName)
                }
            }
        }
    }

    private func finish(with result: Result<MKDirections.ETAResponse, Error>, destination: String) {
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
            alert.informativeText = "\(summary)\n\nFrom: \(originAddress)"
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

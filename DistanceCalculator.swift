import AppKit
import CoreLocation
import MapKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var resultItem: NSMenuItem!
    private var fromField: NSTextField!
    private var toField: NSTextField!
    private let geocoder = CLGeocoder()
    private let originAddress = "51 Franklin Ave, Seaside Heights, NJ"
    private var geocodeCache: [String: CLLocationCoordinate2D] = [:]
    private var isCalculating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "🚗"

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let formItem = NSMenuItem()
        formItem.view = makeFormView()
        menu.addItem(formItem)

        menu.addItem(.separator())

        resultItem = NSMenuItem(title: "No trip calculated yet", action: nil, keyEquivalent: "")
        resultItem.isEnabled = false
        menu.addItem(resultItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func makeFormView() -> NSView {
        let width: CGFloat = 300
        let pad: CGFloat = 14
        let innerWidth = width - 2 * pad
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 162))

        let fromLabel = NSTextField(labelWithString: "From:")
        fromLabel.frame = NSRect(x: pad, y: 136, width: innerWidth, height: 16)

        fromField = NSTextField(frame: NSRect(x: pad, y: 108, width: innerWidth, height: 24))
        fromField.stringValue = originAddress

        let toLabel = NSTextField(labelWithString: "To:")
        toLabel.frame = NSRect(x: pad, y: 82, width: innerWidth, height: 16)

        toField = NSTextField(frame: NSRect(x: pad, y: 54, width: innerWidth, height: 24))
        toField.placeholderString = "e.g. Philadelphia"
        toField.target = self
        toField.action = #selector(calculate)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(closeMenu))
        cancelButton.bezelStyle = .rounded
        cancelButton.frame = NSRect(x: width - pad - 206, y: 12, width: 100, height: 30)

        let calcButton = NSButton(title: "Calculate", target: self, action: #selector(calculate))
        calcButton.bezelStyle = .rounded
        calcButton.keyEquivalent = "\r"
        calcButton.frame = NSRect(x: width - pad - 100, y: 12, width: 100, height: 30)

        view.addSubview(fromLabel)
        view.addSubview(fromField)
        view.addSubview(toLabel)
        view.addSubview(toField)
        view.addSubview(cancelButton)
        view.addSubview(calcButton)
        return view
    }

    func menuWillOpen(_ menu: NSMenu) {
        NSApp.activate(ignoringOtherApps: true)
        // Main-queue dispatch doesn't run during menu tracking; use the run loop in common modes.
        RunLoop.main.perform(inModes: [.common]) { [weak self] in
            guard let self, let window = self.toField.window else { return }
            window.makeFirstResponder(self.toField)
        }
    }

    @objc private func closeMenu() {
        statusItem.menu?.cancelTracking()
    }

    @objc private func calculate() {
        guard !isCalculating else { return }
        let origin = fromField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = toField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !origin.isEmpty, !destination.isEmpty else { return }

        isCalculating = true
        statusItem.button?.title = "🚗 …"
        resultItem.attributedTitle = nil
        resultItem.title = "Calculating…"

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

    // The main dispatch queue is starved while the menu is being tracked, so
    // deliver completions via the run loop in common modes (which include
    // event tracking) to allow updating the open menu in place.
    private func onMain(_ block: @escaping () -> Void) {
        RunLoop.main.perform(inModes: [.common], block: block)
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    private func geocode(_ address: String, completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        geocoder.geocodeAddressString(address) { placemarks, error in
            self.onMain {
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
            guard let self else { return }
            self.onMain {
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
        isCalculating = false
        statusItem.button?.title = "🚗"

        switch result {
        case .success(let response):
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .short
            let time = formatter.string(from: response.expectedTravelTime) ?? "?"
            let miles = response.distance / 1609.344
            let summary = "\(time) (\(String(format: "%.0f", miles)) mi)"
            let prefix = origin == originAddress
                ? "To \(destination): "
                : "\(origin) → \(destination): "

            let fontSize = NSFont.systemFontSize
            let title = NSMutableAttributedString(string: prefix, attributes: [
                .font: NSFont.menuFont(ofSize: fontSize),
                .foregroundColor: NSColor.labelColor,
            ])
            title.append(NSAttributedString(string: summary, attributes: [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: NSColor.labelColor,
            ]))
            resultItem.attributedTitle = title
            resultItem.title = prefix + summary
        case .failure(let error):
            resultItem.attributedTitle = nil
            resultItem.title = "Error: \(error.localizedDescription)"
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

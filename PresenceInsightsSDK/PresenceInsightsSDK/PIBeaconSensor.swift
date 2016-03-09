/**
*  PresenceInsightsSDK
*  PIBeaconSensor.swift
*
*  Handles all beacon and location management.
*
*  © Copyright 2015 IBM Corp.
*
*  Licensed under the Presence Insights Client iOS Framework License (the "License");
*  you may not use this file except in compliance with the License. You may find
*  a copy of the license in the license.txt file in this package.
*
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
**/


import UIKit
import CoreLocation

// MARK: - Delegate protocol.
public protocol PIBeaconSensorDelegate:class {
    func didRangeBeacons(beacons:[CLBeacon])
    func didEnterRegion(region: CLBeaconRegion)
    func didExitRegion(region: CLBeaconRegion)
}

// MARK: - PIBeaconSensor object
public class PIBeaconSensor: NSObject {
    
    private var PI_REPORT_INTERVAL: NSTimeInterval = 5
    
    public weak var delegate: PIBeaconSensorDelegate?
    
    private let piAdapter: PIAdapter
    private let locationManager: CLLocationManager
    private let regionManager: RegionManager
    private var lastDetected: NSDate?
    
    public init(adapter: PIAdapter) {
        
        piAdapter = adapter
        locationManager = CLLocationManager()
        locationManager.requestAlwaysAuthorization()
        regionManager = RegionManager(locationManager: locationManager)
        
        super.init()
        
        locationManager.delegate = self
    }
    
    /**
    Public function to start sensing and ranging beacons.

    - parameter callback: Returns result of starting the sensor as a boolean.
    */
    public func start(callback:(NSError?)->()) {
        piAdapter.getAllBeaconRegions({regions, error in
            
            guard let regions = regions where error == nil else {
                callback(error)
                return
            }
            
            if regions.count > 0 {
                self.regionManager.start()
                self.regionManager.addUuidRegions(regions)
            } else {
                self.piAdapter.printDebug("No Regions to monitor.")
            }
            callback(nil)
        })
    }
    
    /**
    Convenience function to start sensing and ranging beacons.
    
    - parameter callback: Returns result of starting the sensor as a boolean.
    */
    public func start() {
        start({error in
            self.piAdapter.printDebug("Failed to start beacon sensing: \(error)")
        })
    }
    
    /**
    Public function to stop beacon sensing and ranging.
    */
    public func stop() {
        piAdapter.printDebug("Stopped sensing for beacons.")
        regionManager.stop()
    }
    
    
    /**
    Public function to set the frequency to report to PI.
    
    - parameter interval: The time interval between sending a beacon payload to PI. (milliseconds)
    */
    public func setReportInterval(interval: NSTimeInterval) {
        PI_REPORT_INTERVAL = interval
    }
    
    /**
    Private function to convert an NSDate to an ISO8601 time string.
    
    - parameter detectedTime: NSDate to convert.
    
    - returns: ISO8601 formatted time string.
    */
    private func timeAsISO8601String(detectedTime: NSDate) -> String {
        let dateFormatter = NSDateFormatter()
        let enUSPOSIXLocale = NSLocale(localeIdentifier: "en_US_POSIX")
        dateFormatter.locale = enUSPOSIXLocale
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        
        return dateFormatter.stringFromDate(detectedTime)
    }
    
    /**
    Private function to append the detected time to the beacon that was detected.
    
    - parameter beacon:       The detected beacon.
    - parameter detectedTime: The time the beacon was detected.
    
    - returns: Dictionary of containing both the beacon data and the detected time.
    */
    private func createDictionaryWith(beacon: CLBeacon, detectedTime: NSDate) -> [String: AnyObject] {
        var dictionary = [String: AnyObject]()
        dictionary["descriptor"] = UIDevice.currentDevice().identifierForVendor?.UUIDString.lowercaseString
        dictionary["detectedTime"] = timeAsISO8601String(detectedTime)
        
        var data = [String: AnyObject]()
        
        data["rssi"] = beacon.rssi
        data["accuracy"] = beacon.accuracy
        data["proximityUUID"] = beacon.proximityUUID.UUIDString.lowercaseString
        data["major"] = beacon.major.stringValue
        data["minor"] = beacon.minor.stringValue
        data["proximity"] = beacon.proximity.description
        
        dictionary["data"] = data
        
        return dictionary
    }
    
}

// MARK: - CLLocationManagerDelegate functions
extension PIBeaconSensor: CLLocationManagerDelegate {
    
    public func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        regionManager.didDetermineState(state, region: region)
    }

    public func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        piAdapter.printDebug("Did Enter Region: " + region.description)
        guard let region = region as? CLBeaconRegion else {
            return
        }
        regionManager.didEnterRegion(region)
        if let d = delegate {
            d.didEnterRegion(region)
        }
    }
    
    public func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        piAdapter.printDebug("Did Exit Region: " + region.description)
        guard let region = region as? CLBeaconRegion else {
            return
        }
        regionManager.didExitRegion(region)
        if let d = delegate {
            d.didExitRegion(region)
        }
    }
    
    public func locationManager(manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], inRegion region: CLBeaconRegion) {
        piAdapter.printDebug("Did Range Beacons In Region: " + region.description)
        
        if (beacons.isEmpty) {
            return
        }
        
        let detectedTime = NSDate()
        let lastReport: NSTimeInterval!
        if let lastDetected = lastDetected {
            lastReport = detectedTime.timeIntervalSinceDate(lastDetected)
        } else {
            lastReport = PI_REPORT_INTERVAL + 1
        }
        
        if lastReport > PI_REPORT_INTERVAL {
            // array is ordered by accuracy, but if there are beacons with unknown accuracy (-1.0m) they will be at the front of the array
            let filteredBeacons = beacons.filter({ $0.accuracy > 0 })
            // if all beacons in the list are of unknown distance we still send the first one
            if (filteredBeacons.isEmpty) {
                piAdapter.sendBeaconPayload([self.createDictionaryWith(beacons.first!, detectedTime: detectedTime)])
            } else {
                piAdapter.sendBeaconPayload([self.createDictionaryWith(filteredBeacons.first!, detectedTime: detectedTime)])
            }
            lastDetected = detectedTime
        }
        
        if let d = delegate {
            d.didRangeBeacons(beacons)
        }
        
        regionManager.addBeaconRegions(beacons)
    }
    
    public func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
        if let r = region as? CLBeaconRegion {
            piAdapter.printDebug("Started monitoring region: " + r.proximityUUID.UUIDString)
        }
    }
    
    public func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        if let r = region as? CLBeaconRegion {
            piAdapter.printDebug("Failed to monitor for region: " + r.proximityUUID.UUIDString + " Error: \(error)")
        }
    }
    
    public func locationManager(manager: CLLocationManager, rangingBeaconsDidFailForRegion region: CLBeaconRegion, withError error: NSError) {
        piAdapter.printDebug("Failed to range beacons in region: " + region.proximityUUID.UUIDString + " Error: \(error)")
    }
    
    public func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        piAdapter.printDebug("Location Manager failed with error: \(error)")
    }
    
}
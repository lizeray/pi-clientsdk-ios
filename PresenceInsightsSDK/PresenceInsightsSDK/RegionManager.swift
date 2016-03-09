/**
*  PresenceInsightsSDK
*  RegionManager.swift
*
*  Object to contain all zone information.
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

import Foundation
import CoreLocation

internal class RegionManager {
    private let locationManager: CLLocationManager
    private var beaconRegions: [CLBeaconRegion] = []
    private var uuidRegions: [CLBeaconRegion] = []
    private var maxRegions: Int = 20
    private var numRegions: Int {
        get {
            return beaconRegions.count + uuidRegions.count
        }
    }
    
    init(locationManager: CLLocationManager) {
        self.locationManager = locationManager

        let regions = locationManager.monitoredRegions
        for case let region as CLBeaconRegion in regions {
            if NSUUID(UUIDString: region.identifier) == nil {
                beaconRegions.append(createBeaconRegionFromCLRegion(region))
            } else {
                // this will be a uuid region
                uuidRegions.append(createBeaconRegionFromCLRegion(region))
            }
        }
    }

    func start() {
        // to enable ranging in the background for iOS 9
        if #available(iOS 9, *) {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        locationManager.startUpdatingLocation()
        // we are only interested in beacons, so this accuracy will not require Wifi or GPS, which will save battery
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }

    func stop() {
        removeAllRegions()
        locationManager.stopUpdatingLocation()
    }

    func addUuidRegions(uuids: [String]) {
        for u in uuids {
            if let uuid = NSUUID(UUIDString: u) {
                let region = CLBeaconRegion(proximityUUID: uuid, identifier: u)
                
                // will notify state of uuid region whenever the user turns on the screen of their device
                region.notifyEntryStateOnDisplay = true
                
                self.locationManager.startMonitoringForRegion(region)
                self.uuidRegions.append(region)
            }
        }
    }
    
    func addBeaconRegions(beacons: [CLBeacon]) {
        for b in beacons {
            addBeaconRegion(b)
        }
    }
    
    func addBeaconRegion(beacon: CLBeacon) {
        let region = CLBeaconRegion(proximityUUID: beacon.proximityUUID, major: beacon.major.unsignedShortValue, minor: beacon.minor.unsignedShortValue, identifier: "\(beacon.proximityUUID.UUIDString);\(beacon.major);\(beacon.minor)")
        if numRegions >= maxRegions {
            let removedRegion = beaconRegions.removeLast()
            locationManager.stopMonitoringForRegion(removedRegion)
        }
        beaconRegions.append(region)
        locationManager.startMonitoringForRegion(region)
    }
    
    func didEnterRegion(region: CLBeaconRegion) {
        for uuidRegion in uuidRegions {
            if uuidRegion.identifier.lowercaseString == region.identifier.lowercaseString {
                locationManager.startRangingBeaconsInRegion(uuidRegion)
                break
            }
        }
    }
    
    func didDetermineState(state: CLRegionState, region: CLRegion) {
        if let region_ = region as? CLBeaconRegion where state.rawValue == CLRegionState.Inside.rawValue {
            didEnterRegion(region_)
        }
    }

    func didExitRegion(region: CLBeaconRegion){
        for uuidRegion in uuidRegions {
            if uuidRegion.identifier.lowercaseString == region.identifier.lowercaseString {
                locationManager.stopRangingBeaconsInRegion(uuidRegion)
                for beaconRegion in beaconRegions {
                    locationManager.stopMonitoringForRegion(beaconRegion)
                }
                beaconRegions = []
                break
            }
        }
    }
    
    func removeAllRegions() {
        // stop ranging
        for region in self.locationManager.rangedRegions {
            let beaconRegion = CLBeaconRegion(proximityUUID: NSUUID(UUIDString: region.identifier)!, identifier: region.identifier)
            locationManager.stopRangingBeaconsInRegion(beaconRegion)
        }

        // stop monitoring
        for case let region as CLBeaconRegion in self.locationManager.monitoredRegions {
            locationManager.stopMonitoringForRegion(region)
        }

        // clear region arrays
        uuidRegions = []
        beaconRegions = []
    }
    
    func createBeaconRegionFromCLRegion(region: CLRegion) -> CLBeaconRegion {
        let components = region.identifier.componentsSeparatedByString(";")
        var beaconRegion: CLBeaconRegion
        
        // beacon region (id = uuid;major;minor)
        if (components.count > 1) {
            beaconRegion = CLBeaconRegion(proximityUUID: NSUUID(UUIDString: components[0])!, major: CUnsignedShort(components[1])!, minor: CUnsignedShort(components[2])!, identifier: region.identifier)
        } else {
            beaconRegion = CLBeaconRegion(proximityUUID: NSUUID(UUIDString: components[0])!, identifier: region.identifier)
        }
        return beaconRegion
    }
}

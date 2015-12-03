#!/bin/sh
#
#  © Copyright 2015 IBM Corp.
#
#  Licensed under the Presence Insights Client iOS Framework License (the "License");
#  you may not use this file except in compliance with the License. You may find
#  a copy of the license in the license.txt file in this package.
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
# Purpose
#   This script cleans up the output of the framework build process to provide only the universal framework.
#   It is called at the end of the framework build script.

cp Output/PresenceInsightsSDK-Debug-iphonesimulator/PresenceInsightsSDK.framework/Modules/PresenceInsightsSDK.swiftmodule/* Output/PresenceInsightsSDK-Debug-iphoneuniversal/PresenceInsightsSDK.framework/Modules/PresenceInsightsSDK.swiftmodule/
mv Output/PresenceInsightsSDK-Debug-iphoneuniversal/PresenceInsightsSDK.framework Output/
rm -r Output/PresenceInsightsSDK-Debug-iphoneos
rm -r Output/PresenceInsightsSDK-Debug-iphonesimulator
rm -r Output/PresenceInsightsSDK-Debug-iphoneuniversal

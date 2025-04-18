import UIKit
import Flutter
import KlaviyoSwift

/// A class that receives and handles calls from Flutter to complete the payment.
public class KlaviyoFlutterPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
  private static let methodChannelName = "com.rightbite.denisr/klaviyo"
    
  private let METHOD_UPDATE_PROFILE = "updateProfile"
  private let METHOD_INITIALIZE = "initialize"
  private let METHOD_SEND_TOKEN = "sendTokenToKlaviyo"
  private let METHOD_LOG_EVENT = "logEvent"
  private let METHOD_HANDLE_PUSH = "handlePush"
  private let METHOD_SET_EXTERNAL_ID = "setExternalId"
  private let METHOD_GET_EXTERNAL_ID = "getExternalId"
  private let METHOD_RESET_PROFILE = "resetProfile"
  private let METHOD_SET_EMAIL = "setEmail"
  private let METHOD_GET_EMAIL = "getEmail"
  private let METHOD_SET_PHONE_NUMBER = "setPhoneNumber"
  private let METHOD_GET_PHONE_NUMBER = "getPhoneNumber"
  private let METHOD_SET_FIRST_NAME = "setFirstName"
  private let METHOD_SET_LAST_NAME = "setLastName"
  private let METHOD_SET_ORGANIZATION = "setOrganization"
  private let METHOD_SET_TITLE = "setTitle"
  private let METHOD_SET_IMAGE = "setImage"
  private let METHOD_SET_ADDRESS1 = "setAddress1"
  private let METHOD_SET_ADDRESS2 = "setAddress2"
  private let METHOD_SET_CITY = "setCity"
  private let METHOD_SET_COUNTRY = "setCountry"
  private let METHOD_SET_LATITUDE = "setLatitude"
  private let METHOD_SET_LONGITUDE = "setLongitude"
  private let METHOD_SET_REGION = "setRegion"
  private let METHOD_SET_ZIP = "setZip"
  private let METHOD_SET_TIMEZONE = "setTimezone"
  private let METHOD_SET_CUSTOM_ATTRIBUTE = "setCustomAttribute"

  private let klaviyo = KlaviyoSDK()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let channel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    let instance = KlaviyoFlutterPlugin()

    if #available(OSX 10.14, *) {
        let center = UNUserNotificationCenter.current()
        center.delegate = instance
    }

    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  // below method will be called when the user interacts with the push notification
  public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    // decrement the badge count on the app icon
    if #available(iOS 16.0, *) {
        UNUserNotificationCenter.current().setBadgeCount(UIApplication.shared.applicationIconBadgeNumber - 1)
    } else {
        UIApplication.shared.applicationIconBadgeNumber -= 1
    }

    // If this notification is Klaviyo's notification we'll handle it
    // else pass it on to the next push notification service to which it may belong
    let handled = KlaviyoSDK().handle(notificationResponse: response, withCompletionHandler: completionHandler)
    if !handled {
        completionHandler()
    }
  }

  // below method is called when the app receives push notifications when the app is the foreground
  public func userNotificationCenter(_ center: UNUserNotificationCenter,
                                  willPresent notification: UNNotification,
                                  withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
     var options: UNNotificationPresentationOptions =  [.alert]
     if #available(iOS 14.0, *) {
       options = [.list, .banner]
     }
     completionHandler(options)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    func setProfileAttribute(key: Profile.ProfileKey, name: String, argumentKey: String) {
        let arguments = call.arguments as! [String: Any]
        klaviyo.set(profileAttribute: key, value: arguments[argumentKey] as! String)
        result("\(name) updated")
    }
    switch call.method {
        case METHOD_INITIALIZE:
          let arguments = call.arguments as! [String: Any]
          klaviyo.initialize(with: arguments["apiKey"] as! String)
          result("Klaviyo initialized")

        case METHOD_SEND_TOKEN:
          let arguments = call.arguments as! [String: Any]
          let tokenData = arguments["token"] as! String
          klaviyo.set(pushToken: Data(hexString: tokenData))
          result("Token sent to Klaviyo")

        case METHOD_UPDATE_PROFILE:
          let arguments = call.arguments as! [String: Any]
          // parsing location
          let address1 = arguments["address1"] as? String
          let address2 = arguments["address2"] as? String
          let latitude = (arguments["latitude"] as? String)?.toDouble
          let longitude = (arguments["longitude"] as? String)?.toDouble
          let region = arguments["region"] as? String
        
          var location: Profile.Location?
        
          if(address1 != nil && address2 != nil && latitude != nil && longitude != nil && region != nil) {
            location = Profile.Location(
                address1: address1,
                address2: address2,
                latitude: latitude,
                longitude: longitude,
                region: region)
          }
        
        
          let profile = Profile(
            email: arguments["email"] as? String,
            phoneNumber: arguments["phone_number"] as? String,
            externalId: arguments["external_id"] as? String,
            firstName: arguments["first_name"] as? String,
            lastName: arguments["last_name"] as? String,
            organization: arguments["organization"] as? String,
            title: arguments["title"] as? String,
            image: arguments["image"] as? String,
            location: location,
            properties: arguments["properties"] as? [String:Any]
            )
          klaviyo.set(profile: profile)
          result("Profile updated")

        case METHOD_LOG_EVENT:
          let arguments = call.arguments as! [String: Any]
          let event = Event(
            name: .customEvent(arguments["name"] as! String),
            properties: arguments["metaData"] as? [String: Any])

          klaviyo.create(event: event)
          result("Event: [\(event)] created")
        
        case METHOD_HANDLE_PUSH:
          let arguments = call.arguments as! [String: Any]

          if let properties = arguments["message"] as? [String: Any],
            let _ = properties["_k"] {
              klaviyo.create(event: Event(name: .customEvent("$opened_push"), properties: properties))

              return result(true)
          }
          result(false)

        case METHOD_GET_EXTERNAL_ID:
          result(klaviyo.externalId)

        case METHOD_RESET_PROFILE:
          klaviyo.resetProfile()
          result(true)

        case METHOD_GET_EMAIL:
          result(klaviyo.email)

        case METHOD_GET_PHONE_NUMBER:
          result(klaviyo.phoneNumber)
        
        case METHOD_SET_EXTERNAL_ID:
          let arguments = call.arguments as! [String: Any]
          klaviyo.set(externalId: arguments["id"] as! String)
          result("ID updated")

        case METHOD_SET_EMAIL:
          let arguments = call.arguments as! [String: Any]
          klaviyo.set(email: arguments["email"] as! String)
          result("Email updated")

        case METHOD_SET_PHONE_NUMBER:
          let arguments = call.arguments as! [String: Any]
          klaviyo.set(phoneNumber: arguments["phoneNumber"] as! String)
          result("Phone updated")
        
        case METHOD_SET_FIRST_NAME:
          setProfileAttribute(key: .firstName, name: "First name", argumentKey: "firstName")
        
        case METHOD_SET_LAST_NAME:
          setProfileAttribute(key: .lastName, name: "Last name", argumentKey: "lastName")
        
        case METHOD_SET_TITLE:
          setProfileAttribute(key: .title, name: "Title", argumentKey: "title")
        
        case METHOD_SET_ORGANIZATION:
          setProfileAttribute(key: .organization, name: "Organization", argumentKey: "organization")
        
        case METHOD_SET_IMAGE:
          setProfileAttribute(key: .image, name: "Image", argumentKey: "image")
        
        case METHOD_SET_ADDRESS1:
          setProfileAttribute(key: .address1, name: "Address 1", argumentKey: "address")
        
        case METHOD_SET_ADDRESS2:
          setProfileAttribute(key: .address2, name: "Address 2", argumentKey: "address")
        
        case METHOD_SET_CITY:
          setProfileAttribute(key: .city, name: "City", argumentKey: "city")
        
        case METHOD_SET_COUNTRY:
          setProfileAttribute(key: .country, name: "Country", argumentKey: "country")
        
        case METHOD_SET_LATITUDE:
          setProfileAttribute(key: .latitude, name: "Latitude", argumentKey: "latitude")
        
        case METHOD_SET_LONGITUDE:
          setProfileAttribute(key: .longitude, name: "Longitude", argumentKey: "longitude")
        
        case METHOD_SET_REGION:
          setProfileAttribute(key: .region, name: "Region", argumentKey: "region")
        
        case METHOD_SET_ZIP:
          setProfileAttribute(key: .zip, name: "Zip", argumentKey: "zip")
        
        case METHOD_SET_TIMEZONE:
          // Klaviyo takes timezone from environment on iOS
          result("Success")
        
        case METHOD_SET_CUSTOM_ATTRIBUTE:
          let arguments = call.arguments as! [String: Any]
          let key = arguments["key"] as! String;
          let value = arguments["value"] as! String;
          klaviyo.set(profileAttribute: .custom(customKey: key), value: value)
          result("Attribute \(key) updated")

        default:
          result(FlutterMethodNotImplemented)
    }
  }
}

extension String {
    var toDouble: Double {
        return Double(self) ?? 0.0
    }
}

extension Data {
    init(hexString: String) {
        self = hexString
            .dropFirst(hexString.hasPrefix("0x") ? 2 : 0)
            .compactMap { $0.hexDigitValue.map { UInt8($0) } }
            .reduce(into: (data: Data(capacity: hexString.count / 2), byte: nil as UInt8?)) { partialResult, nibble in
                if let p = partialResult.byte {
                    partialResult.data.append(p + nibble)
                    partialResult.byte = nil
                } else {
                    partialResult.byte = nibble << 4
                }
            }.data
    }
}

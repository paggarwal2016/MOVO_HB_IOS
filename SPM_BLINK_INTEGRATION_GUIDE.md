  
\# BlinkIDUX SPM Integration Guide

\#\# Overview

This guide provides step-by-step instructions for integrating BlinkIDUX via Swift Package Manager (SPM) and configuring it for the OSCAR KYC Harmonic Gate.

\#\# Prerequisites

\- Xcode 14.0 or later  
\- iOS 13.0+ deployment target  
\- Valid BlinkID license key  
\- Camera usage permissions configured

\#\# Step 1: Add BlinkIDUX via SPM

\#\#\# 1.1 Open Package Dependencies

1\. Open your Xcode project  
2\. Go to \*\*File \> Add Package Dependencies...\*\*  
3\. Enter the BlinkID repository URL: \`https://github.com/BlinkID/blinkid-ios\`

\#\#\# 1.2 Configure Package Options

\`\`\`  
Repository: https://github.com/BlinkID/blinkid-ios  
Version: Latest (or specify version like 6.7.0)  
Add to Target: MovoCash  
\`\`\`

\#\#\# 1.3 Verify Package Addition

Check that the following appears in your project navigator:  
\`\`\`  
📦 Package Dependencies  
  └── 📦 blinkid-ios  
      └── 📦 BlinkID  
          └── 🔗 BlinkIDUX  
\`\`\`

\#\# Step 2: Configure Framework Embedding

\#\#\# 2.1 Target Settings

1\. Select your app target  
2\. Go to \*\*General \> Frameworks, Libraries, and Embedded Content\*\*  
3\. Verify BlinkIDUX is set to \*\*"Embed & Sign"\*\*

\`\`\`  
BlinkIDUX.framework \- Embed & Sign  
\`\`\`

\#\#\# 2.2 Build Settings Verification

Ensure the following build settings are configured:

\`\`\`bash  
\# Framework Search Paths  
FRAMEWORK\_SEARCH\_PATHS \= $(inherited)

\# Enable Modules  
CLANG\_ENABLE\_MODULES \= YES

\# Swift Optimization Level (Debug)  
SWIFT\_OPTIMIZATION\_LEVEL \= \-Onone

\# Swift Optimization Level (Release)  
SWIFT\_OPTIMIZATION\_LEVEL \= \-O  
\`\`\`

\#\# Step 3: Configure Info.plist Permissions

\#\#\# 3.1 Camera Permission

Add the following to your \`Info.plist\`:

\`\`\`xml  
\<key\>NSCameraUsageDescription\</key\>  
\<string\>Camera access is required to scan identity documents for verification\</string\>  
\`\`\`

\#\#\# 3.2 Additional Permissions (Optional)

\`\`\`xml  
\<\!-- For photo library access (if needed) \--\>  
\<key\>NSPhotoLibraryUsageDescription\</key\>  
\<string\>Photo library access is needed to select images for document verification\</string\>

\<\!-- For microphone (if liveness detection requires it) \--\>  
\<key\>NSMicrophoneUsageDescription\</key\>  
\<string\>Microphone access may be required for advanced liveness detection\</string\>  
\`\`\`

\#\# Step 4: License Configuration

\#\#\# 4.1 Obtain BlinkID License

1\. Register at \[BlinkID Developer Portal\](https://microblink.com/login)  
2\. Create new app and obtain license key  
3\. Download the license file or copy the license string

\#\#\# 4.2 Configure License in Code

Add to your \`AppDelegate.swift\` or early in app lifecycle:

\`\`\`swift  
import BlinkIDUX

class AppDelegate: UIResponder, UIApplicationDelegate {  
    func application(\_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: \[UIApplication.LaunchOptionsKey: Any\]?) \-\> Bool {

        // Configure BlinkID license  
        if let licenseKey \= Bundle.main.object(forInfoPlistKey: "BlinkIDLicenseKey") as? String {  
            BlinkIDManager.shared.setLicenseKey(licenseKey)  
        } else {  
            print("⚠️  BlinkID license key not found in Info.plist")  
        }

        return true  
    }  
}  
\`\`\`

\#\#\# 4.3 Add License to Info.plist

\`\`\`xml  
\<key\>BlinkIDLicenseKey\</key\>  
\<string\>YOUR\_BLINKID\_LICENSE\_KEY\_HERE\</string\>  
\`\`\`

\#\# Step 5: Verify Integration

\#\#\# 5.1 Build Verification

1\. Clean build folder: \*\*Product \> Clean Build Folder\*\*  
2\. Build project: \*\*⌘+B\*\*  
3\. Verify no compilation errors

Expected build output:  
\`\`\`  
✅ Build Succeeded  
✅ BlinkIDUX framework linked  
✅ No linker errors  
\`\`\`

\#\#\# 5.2 Runtime Verification

Add this test code to verify BlinkID is properly configured:

\`\`\`swift  
import BlinkIDUX

class ViewController: UIViewController {  
    override func viewDidLoad() {  
        super.viewDidLoad()

        // Verify BlinkID license status  
        if BlinkIDManager.shared.isLicenseValid() {  
            print("✅ BlinkID license is valid")  
        } else {  
            print("❌ BlinkID license is invalid or not set")  
        }

        // Test basic scanner availability  
        if BlinkIDManager.shared.isScannerAvailable() {  
            print("✅ BlinkID scanner is available")  
        } else {  
            print("❌ BlinkID scanner is not available")  
        }  
    }  
}  
\`\`\`

\#\# Step 6: Integration with KycBridge

\#\#\# 6.1 Verify KycBridge Import

Ensure your \`KycBridge.swift\` can import BlinkIDUX:

\`\`\`swift  
import Foundation  
import MobileBankingKycSdk  // Herring SDK  
import BlinkIDUX           // ✅ This should not cause errors

@objc public class KycBridge: NSObject {  
    // ... implementation  
}  
\`\`\`

\#\#\# 6.2 Test Basic Flow

\`\`\`swift  
// In your test view controller  
override func viewDidAppear(\_ animated: Bool) {  
    super.viewDidAppear(animated)

    // Clear any previous results  
    KycBridge.clearKycResult()

    // Test the full flow  
    KycBridge.launchKycFlow(from: self)  
}  
\`\`\`

\#\# Step 7: Common Issues & Troubleshooting

\#\#\# 7.1 Compilation Errors

\*\*Error: "No such module 'BlinkIDUX'"\*\*  
\- Solution: Verify SPM package is added and framework is embedded  
\- Check Framework Search Paths in build settings

\*\*Error: "dyld: Library not loaded"\*\*  
\- Solution: Ensure framework is set to "Embed & Sign", not just "Link"  
\- Clean and rebuild project

\#\#\# 7.2 Runtime Issues

\*\*Error: "BlinkID license is invalid"\*\*  
\- Verify license key is correctly added to Info.plist  
\- Ensure license key matches your bundle identifier  
\- Check license expiration date

\*\*Error: "Camera permission denied"\*\*  
\- Verify NSCameraUsageDescription is in Info.plist  
\- Test on physical device (camera not available in simulator)

\#\#\# 7.3 Performance Issues

\*\*Slow scanning performance:\*\*  
\- Ensure Release build configuration for production  
\- Verify Swift optimization level is set to \-O for Release  
\- Test on physical device, not simulator

\#\# Step 8: Device Testing

\#\#\# 8.1 Simulator Limitations

⚠️ \*\*Important\*\*: BlinkIDUX requires a physical device with camera. Simulator testing will fail.

\#\#\# 8.2 Physical Device Testing

1\. Connect iPhone/iPad to Xcode  
2\. Select device as run destination  
3\. Build and run: \*\*⌘+R\*\*  
4\. Test document scanning flow

\#\#\# 8.3 Document Testing

Test with these document types:  
\- ✅ US Driver's License  
\- ✅ US Passport  
\- ✅ National ID cards  
\- ✅ International passports

\#\# Step 9: Production Deployment

\#\#\# 9.1 Build Configuration

For App Store submission:  
\`\`\`bash  
\# Release build settings  
SWIFT\_OPTIMIZATION\_LEVEL \= \-O  
ENABLE\_BITCODE \= NO  \# BlinkID requires bitcode to be disabled  
GCC\_OPTIMIZATION\_LEVEL \= s  
\`\`\`

\#\#\# 9.2 License Management

\- Use production license key  
\- Implement license validation  
\- Handle license expiration gracefully

\#\#\# 9.3 Privacy Compliance

Ensure compliance with:  
\- iOS Privacy Guidelines  
\- Data Protection Regulations  
\- Document image handling policies

\#\# Step 10: Integration with OSCAR

\#\#\# 10.1 Verify OSCAR Compatibility

The enriched KycBridge should produce OSCAR-compatible JSON:

\`\`\`json  
{  
  "status": "success",  
  "fullName": "John Doe",  
  "document": { "type": "drivers\_license" },  
  "verification": { "confidence": 0.95 },  
  "oscarReady": {  
    "hasRequiredFields": true,  
    "dataQuality": 0.87,  
    "harmonicCompatibility": true  
  }  
}  
\`\`\`

\#\#\# 10.2 Test Full Pipeline

\`\`\`bash  
\# Test the complete flow  
1\. iOS Device: Scan document → Generate kyc\_result.json  
2\. OSCAR Gate: Read JSON → Process through 6 stages  
3\. TimeWave: Log results with ΔΦⁿ tracking  
\`\`\`

\#\# Verification Checklist

\- \[ \] BlinkIDUX package added via SPM  
\- \[ \] Framework set to "Embed & Sign"  
\- \[ \] Camera permissions configured  
\- \[ \] BlinkID license key configured  
\- \[ \] Build succeeds without errors  
\- \[ \] Runtime license validation passes  
\- \[ \] Scanner launches on physical device  
\- \[ \] Document scanning works  
\- \[ \] KycBridge produces enriched JSON  
\- \[ \] OSCAR gate processes enriched data  
\- \[ \] Full pipeline: scan → JSON → harmonic gate → TimeWave

\#\# Support Resources

\- \[BlinkID Documentation\](https://github.com/BlinkID/blinkid-ios)  
\- \[BlinkID Developer Portal\](https://microblink.com/docs)  
\- \[Apple SPM Documentation\](https://developer.apple.com/documentation/swift\_packages)

\---

\*This guide ensures proper BlinkIDUX integration for the OSCAR KYC Harmonic Gate system.  

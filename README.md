# ChromaCompanion
Mobile Computing Course Project

Colorblind and visually impaired individuals face challenges in accurately perceiving and coordinating clothing colors, which can often harm their self-expression and overall confidence. This can make the daily task of pairing clothing and shopping for new clothing particularly difficult without help from non-colorblind companions. Most current fashion applications lack accessibility features and fail to provide color and style advice designed for this specific user group, hence excluding them from the fashion sphere. 

The proposed solution would be a mobile application designed to address the needs of colorblind users to help them make more informed fashion choices. By leveraging image processing algorithms and simple color theory principles, the app will identify clothing colors from photos, and provide detailed color descriptions, suggest color pairings, and aesthetic recommendations (e.g. suitable for goth, earthy, etc. aesthetics). The application will strive to encompass an intuitive and accessible interface that empowers users to confidently express their individuality through fashion, removing a significant barrier in the fashion sphere.


FOR COLOR TO WORK:
Click on Chroma Companion in XCode and go to build settings. 
1. Search ENABLE_USER_SCRIPT_SANDBOXING, and for all 3 targets (ChromaCompanion, ChromaCompanionTests, ChromaCompanionUITests), set it to No
https://stackoverflow.com/questions/76590131/error-while-build-ios-app-in-xcode-sandbox-rsync-samba-13105-deny1-file-w
2. Search ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES, for all 3 targets, click on Yes, replace it with $(inherited) 
https://stackoverflow.com/questions/41570233/whats-always-embed-swift-standard-libraries-with-cocoapods-swift-3-and-xcode-8


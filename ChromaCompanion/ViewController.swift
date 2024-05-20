import UIKit
import Vision
import UIImageColors
import MLKit
import PhotosUI
import CropViewController

class ViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var overlayView: OverlayView!
    @IBOutlet var button: UIButton!
    private var objectDetector: ObjectDetector?
    private var detectedObjectFrame: CGRect?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup object detector.
        let options = ObjectDetectorOptions()
        options.detectorMode = .singleImage
        options.shouldEnableMultipleObjects = false
        options.shouldEnableClassification = true
        
        objectDetector = ObjectDetector.objectDetector(options: options)
        
        imageView.backgroundColor = .white
        button.setTitle("Take/Choose Picture", for: .normal)
        button.setTitleColor(.white, for: .normal)
    }
    
    @IBAction func didTapButton() {
        print("didTapButton called")
        let actionSheet = UIAlertController(title: "Select Picture", message: "Choose a source", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
            self.presentImagePicker(sourceType: .camera)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { _ in
            self.presentImagePicker(sourceType: .photoLibrary)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(actionSheet, animated: true, completion: nil)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func objectDetectorProcess(image: UIImage) {
        guard let objectDetector = objectDetector else {
            return
        }
        
        
        let visionImage = VisionImage(image: image)
        visionImage.orientation = image.imageOrientation
        
        objectDetector.process(visionImage) { detectedObjects, error in
            guard error == nil else {
                return
            }
            
            guard let detectedObjects = detectedObjects,
                  !detectedObjects.isEmpty else {
                self.performSaliencyDetection(image: image)
                return
            }
            
            
            DispatchQueue.main.async {
                self.setupOverlayView(image: image, detectedObjects: detectedObjects)
            }
        }
        
    }
    
    private func performSaliencyDetection(image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
            if let results = request.results,
               let salientObject = results.first,
               let salientRect = salientObject.salientObjects?.first?.boundingBox {
                
                print("Salient object at: \(salientRect)")
                
                let imageRect = ciImage.extent
                let normalizedSalientRect = VNImageRectForNormalizedRect(salientRect, Int(imageRect.width), Int(imageRect.height))
                
                DispatchQueue.main.async {
                    self.presentCropViewController(for: image, with: normalizedSalientRect)
                }
                
//                DispatchQueue.main.async {
//                    let customObject = DetectedObject(frame: normalizedSalientRect, id: 0, label: "Salient Object", confidence: 1.0)
//                    self.setupOverlayView(image: image, detectedObjects: [customObject])
//                }
            } else {
                print("No salient regions found.")
            }
        } catch {
            print("Error performing saliency request: \(error)")
        }
    }

    
    func setupOverlayView(image: UIImage, detectedObjects: [Object]) {
//        let colorArray: [UIColor] = [
//            .red,
//            .green,
//            .blue,
//            .yellow,
//            .magenta,
//            .cyan,
//            .black,
//        ]
//        
//        for i in 0..<detectedObjects.count {
//            let convertedRect = self.imageView.convertRect(fromImageRect: detectedObjects[i].frame)
//            let overlayObject: OverlayObject = OverlayObject(rect: convertedRect,
//                                                             color: colorArray[i % colorArray.count])
//            
//            overlayView.overlayObjects.append(overlayObject)
//        }
        overlayView.overlayObjects = []
        overlayView.setNeedsDisplay()
        if let firstObjectFrame = detectedObjects.first?.frame {
                    self.presentCropViewController(for: image, with: firstObjectFrame)
                }
    }
    
    private func presentCropViewController(for image: UIImage, with frame: CGRect) {
        let cropViewController = CropViewController(croppingStyle: .default, image: image)
        cropViewController.delegate = self
        
        let imageFrame = imageView.convertRect(fromImageRect: frame)
        let initialCropFrame = CGRect(x: imageFrame.origin.x * image.size.width / imageView.bounds.width,
                                      y: imageFrame.origin.y * image.size.height / imageView.bounds.height,
                                      width: imageFrame.width * image.size.width / imageView.bounds.width,
                                      height: imageFrame.height * image.size.height / imageView.bounds.height)
        cropViewController.imageCropFrame = initialCropFrame
        
        present(cropViewController, animated: true, completion: nil)
    }
    
    private func convertToImageRect(fromViewRect viewRect: CGRect, inImage image: UIImage) -> CGRect {
        let imageViewSize = imageView.frame.size
        let imageSize = image.size
        
        let scaleX = imageSize.width / imageViewSize.width
        let scaleY = imageSize.height / imageViewSize.height
        
        let imageRect = CGRect(x: viewRect.origin.x * scaleX,
                               y: viewRect.origin.y * scaleY,
                               width: viewRect.width * scaleX,
                               height: viewRect.height * scaleY)
        return imageRect
    }
}

extension ViewController: CropViewControllerDelegate {
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        cropViewController.dismiss(animated: true, completion: nil)
        imageView.image = image
        extractColors(from: image) // Call the extractColors function with the cropped image
    }
    
    func cropViewController(_ cropViewController: CropViewController, didFinishCancelled cancelled: Bool) {
        cropViewController.dismiss(animated: true, completion: nil)
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        
        DispatchQueue.main.async {
            self.imageView.image = image
            
            self.overlayView.overlayObjects = []
            self.overlayView.setNeedsDisplay()
            
            self.objectDetectorProcess(image: image)
        }

//        extractColors(from: image)
        
//        // Convert UIImage to CIImage
//        guard let ciImage = CIImage(image: image) else {
//            return
//        }
//        
//        // Create attention-based saliency request
//        let request = VNGenerateAttentionBasedSaliencyImageRequest()
//        
//        // Perform saliency request
//        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
//        DispatchQueue.global(qos: .userInitiated).async {
//            do {
//                try handler.perform([request])
//                if let results = request.results,
//                   let salientObject = results.first,
//                   let salientRect = salientObject.salientObjects?.first?.boundingBox {
//                    
//                    // Normalized coordinates to image coordinates
//                    let imageRect = ciImage.extent
//                    let normalizedSalientRect = VNImageRectForNormalizedRect(salientRect, Int(imageRect.width), Int(imageRect.height))
//                    
//                    // Crop image to salient rect
//                    let croppedImage = ciImage.cropped(to: normalizedSalientRect)
//                    let thumbnail = UIImage(ciImage: croppedImage)
//                    
//                    DispatchQueue.main.async {
//                        self.imageView.image = thumbnail
//                        self.extractColors(from: thumbnail)
//                    }
//                } else {
//                    // If no salient region found, use original image
//                    DispatchQueue.main.async {
//                        self.imageView.image = image
//                        self.extractColors(from: image)
//                    }
//                }
//            } catch {
//                print("Error performing saliency request: \(error)")
//                DispatchQueue.main.async {
//                    self.imageView.image = image
//                    self.extractColors(from: image)
//                }
//            }
//        }
    }
    
    private func extractColors(from image: UIImage) {
        image.getColors { colors in
            guard let colors = colors else { return }
            let background = colors.background ?? UIColor.black
            let primary = colors.primary ?? UIColor.black
            let secondary = colors.secondary ?? UIColor.black
            let detail = colors.detail ?? UIColor.black
            
            let backgroundColorName = findClosestColorName(to: background)
            let primaryColorName = findClosestColorName(to: primary)
            let secondaryColorName = findClosestColorName(to: secondary)
            let detailColorName = findClosestColorName(to: detail)
            
            DispatchQueue.main.async {
                self.presentColorAnalysisViewController(primary: primary, secondary: secondary, background: background, detail: detail, primaryName: primaryColorName, secondaryName: secondaryColorName, backgroundName: backgroundColorName, detailName: detailColorName)
            }
            print(backgroundColorName)
            print(primaryColorName)
            print(secondaryColorName)
            print(detailColorName)
            
            print("Background: \(background), Primary: \(primary), Secondary: \(secondary), Detail: \(detail)")
        }
    }
    
    private func presentColorAnalysisViewController(primary: UIColor, secondary: UIColor, background: UIColor, detail: UIColor, primaryName: String, secondaryName: String, backgroundName: String, detailName: String) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let colorInfoVC = storyboard.instantiateViewController(withIdentifier: "ColorAnalysisViewController") as? ColorAnalysisViewController else {
            return
        }
        
        colorInfoVC.primaryColor = primary
        colorInfoVC.secondaryColor = secondary
        colorInfoVC.backgroundColor = background
        colorInfoVC.detailColor = detail
        colorInfoVC.primaryColorName = primaryName
        colorInfoVC.secondaryColorName = secondaryName
        colorInfoVC.backgroundColorName = backgroundName
        colorInfoVC.detailColorName = detailName
        
        navigationController?.pushViewController(colorInfoVC, animated: true)
    }
}

class ColorAnalysisViewController: UIViewController {
    @IBOutlet weak var primaryColorView: UIView!
    @IBOutlet weak var secondaryColorView: UIView!
    @IBOutlet weak var backgroundColorView: UIView!
    @IBOutlet weak var detailColorView: UIView!
    
    @IBOutlet weak var primaryColorLabel: UILabel!
    @IBOutlet weak var secondaryColorLabel: UILabel!
    @IBOutlet weak var backgroundColorLabel: UILabel!
    @IBOutlet weak var detailColorLabel: UILabel!
    
    var primaryColor: UIColor?
    var secondaryColor: UIColor?
    var backgroundColor: UIColor?
    var detailColor: UIColor?
    
    var primaryColorName: String?
    var secondaryColorName: String?
    var backgroundColorName: String?
    var detailColorName: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("Background")
        print("Background: \(backgroundColor), Primary: \(primaryColor), Secondary: \(secondaryColor), Detail: \(detailColor)")
        // Set the background colors of the views to display the colors
        if let primaryColor = primaryColor {
            primaryColorView.backgroundColor = primaryColor
        } else {
            primaryColorView.backgroundColor = UIColor.clear
        }
        
        if let secondaryColor = secondaryColor {
            secondaryColorView.backgroundColor = secondaryColor
        } else {
            secondaryColorView.backgroundColor = UIColor.clear
        }
        
        if let backgroundColor = backgroundColor {
            backgroundColorView.backgroundColor = backgroundColor
        } else {
            backgroundColorView.backgroundColor = UIColor.clear
        }
        
        if let detailColor = detailColor {
            detailColorView.backgroundColor = detailColor
        } else {
            detailColorView.backgroundColor = UIColor.clear
        }
        
        primaryColorLabel.text = primaryColorName
        secondaryColorLabel.text = secondaryColorName
        backgroundColorLabel.text = backgroundColorName
        detailColorLabel.text = detailColorName
    }
}

struct ColorName {
    let name: String
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
}

let predefinedColors: [ColorName] = [
    //Red
    ColorName(name: "Bright Red", red: 1.0, green: 0.0, blue: 0.0),
    ColorName(name: "Pastel Red", red: 0.91, green: 0.663, blue: 0.663),
    
    //Pink
    ColorName(name: "Soft Pink", red: 1, green: 0.816, blue: 0.813),
    
    //Yellow
    
    //Green
    ColorName(name: "Green", red: 0.0, green: 1.0, blue: 0.0),
    ColorName(name: "Lime", red: 0.745, green: 1.0, blue: 0.369),
    
    //Blue
    ColorName(name: "Blue", red: 0.0, green: 0.0, blue: 1.0),
    
    //Purple
    
    //Black, White, Gray
    ColorName(name: "Black", red: 0.0, green: 0.0, blue: 0.0),
    ColorName(name: "Light Gray", red: 0.89, green: 0.89, blue: 0.89),
    ColorName(name: "Medium Gray", red: 0.61, green: 0.61, blue: 0.61),
    ColorName(name: "Dark Gray", red: 0.38, green: 0.38, blue: 0.38),
    ColorName(name: "White", red: 1.0, green: 1.0, blue: 1.0),
    // Add more colors as needed
]

func euclideanDistance(color1: (CGFloat, CGFloat, CGFloat), color2: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
    return sqrt(pow(color1.0 - color2.0, 2) + pow(color1.1 - color2.1, 2) + pow(color1.2 - color2.2, 2))
}

func findClosestColorName(to color: UIColor) -> String {
    guard let components = color.cgColor.components, components.count >= 3 else {
        return "Unknown"
    }
    
    let inputColor = (components[0], components[1], components[2])
    var closestColor: ColorName?
    var smallestDistance: CGFloat = .greatestFiniteMagnitude
    
    for predefinedColor in predefinedColors {
        let predefinedRGB = (predefinedColor.red, predefinedColor.green, predefinedColor.blue)
        let distance = euclideanDistance(color1: inputColor, color2: predefinedRGB)
        
        if distance < smallestDistance {
            smallestDistance = distance
            closestColor = predefinedColor
        }
    }
    
    return closestColor?.name ?? "Unknown"
}

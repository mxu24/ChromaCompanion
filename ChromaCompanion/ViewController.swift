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
        
        let options = ObjectDetectorOptions()
        options.detectorMode = .singleImage
        options.shouldEnableMultipleObjects = false
        options.shouldEnableClassification = true
        objectDetector = ObjectDetector.objectDetector(options: options)
        
        imageView.backgroundColor =  UIColor(red: 0.945, green: 0.949, blue: 0.945, alpha: 1.0)
        button.setTitle("Take/Choose Picture", for: .normal)
        button.setTitleColor(.white, for: .normal)
    }
    
    @IBAction func didTapButton() {
        let actionSheet = UIAlertController(title: "Select Picture", message: "Choose a method", preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { _ in
            self.getPicture(sourceType: .camera)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { _ in
            self.getPicture(sourceType: .photoLibrary)
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(actionSheet, animated: true, completion: nil)
    }
    
    private func getPicture(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func doObjectDetection(image: UIImage) {
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
                self.doSaliency(image: image)
                return
            }
            
            DispatchQueue.main.async {
                if let firstObjectFrame = detectedObjects.first?.frame {
                            self.doCrop(for: image, with: firstObjectFrame)
                        }
            }
        }
    }
    
    private func doSaliency(image: UIImage) {
        guard let ciImage = CIImage(image: image) else { return }
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
            if let results = request.results,
               let salientObject = results.first,
               let salientRect = salientObject.salientObjects?.first?.boundingBox {
                let imageRect = ciImage.extent
                let normalizedSalientRect = VNImageRectForNormalizedRect(salientRect, Int(imageRect.width), Int(imageRect.height))
                DispatchQueue.main.async {
                    self.doCrop(for: image, with: normalizedSalientRect)
                }
            }
        } catch {
            print("Error with Saliency")
        }
    }
    
    private func doCrop(for image: UIImage, with frame: CGRect) {
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
}

extension ViewController: CropViewControllerDelegate {
    func cropViewController(_ cropViewController: CropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
        cropViewController.dismiss(animated: true, completion: nil)
        imageView.image = image
        extractColors(from: image)
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
            self.doObjectDetection(image: image)
        }
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
                self.goToColorAnalysis(primary: primary, secondary: secondary, background: background, detail: detail, primaryName: primaryColorName, secondaryName: secondaryColorName, backgroundName: backgroundColorName, detailName: detailColorName)
            }
        }
    }
    
    private func goToColorAnalysis(primary: UIColor, secondary: UIColor, background: UIColor, detail: UIColor, primaryName: String, secondaryName: String, backgroundName: String, detailName: String) {
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
    @IBOutlet weak var aestheticLabel: UILabel!
    
    @IBOutlet weak var hueGraphView: UIView!
    @IBOutlet weak var hueIndicator: UIView!
    @IBOutlet weak var saturationGraphView: UIView!
    @IBOutlet weak var saturationIndicator: UIView!
    @IBOutlet weak var brightnessGraphView: UIView!
    @IBOutlet weak var brightnessIndicator: UIView!
    
    @IBOutlet weak var hueGraphView2: UIView!
    @IBOutlet weak var hueIndicator2: UIView!
    @IBOutlet weak var saturationGraphView2: UIView!
    @IBOutlet weak var saturationIndicator2: UIView!
    @IBOutlet weak var brightnessGraphView2: UIView!
    @IBOutlet weak var brightnessIndicator2: UIView!
    
    @IBOutlet weak var hueGraphView3: UIView!
    @IBOutlet weak var hueIndicator3: UIView!
    @IBOutlet weak var saturationGraphView3: UIView!
    @IBOutlet weak var saturationIndicator3: UIView!
    @IBOutlet weak var brightnessGraphView3: UIView!
    @IBOutlet weak var brightnessIndicator3: UIView!
    
    @IBOutlet weak var hueGraphView4: UIView!
    @IBOutlet weak var hueIndicator4: UIView!
    @IBOutlet weak var saturationGraphView4: UIView!
    @IBOutlet weak var saturationIndicator4: UIView!
    @IBOutlet weak var brightnessGraphView4: UIView!
    @IBOutlet weak var brightnessIndicator4: UIView!
    
    @IBOutlet weak var dominantRGB: UILabel!
    var primaryColor: UIColor?
    var secondaryColor: UIColor?
    var backgroundColor: UIColor?
    var detailColor: UIColor?
    
    var primaryColorName: String?
    var secondaryColorName: String?
    var backgroundColorName: String?
    var detailColorName: String?
    
    var circle: NSLayoutConstraint!
    var circles: NSLayoutConstraint!
    var circless: NSLayoutConstraint!
    var circle2: NSLayoutConstraint!
    var circles2: NSLayoutConstraint!
    var circless2: NSLayoutConstraint!
    var circle3: NSLayoutConstraint!
    var circles3: NSLayoutConstraint!
    var circless3: NSLayoutConstraint!
    var circle4: NSLayoutConstraint!
    var circles4: NSLayoutConstraint!
    var circless4: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        let colors = [backgroundColorName, primaryColorName]
        let groups = findGroups(for: colors)
        aestheticLabel.text = groups
        drawGraphs()
    }
    private func drawGraphs() {
        drawHueSaturation(hueGraphView, title: "Hue", for: backgroundColor ?? UIColor.clear)
        drawHueSaturation(hueGraphView2, title: "Hue", for: primaryColor ?? UIColor.clear)
        drawHueSaturation(hueGraphView3, title: "Hue", for: secondaryColor ?? UIColor.clear)
        drawHueSaturation(hueGraphView4, title: "Hue", for: detailColor ?? UIColor.clear)
        
        drawHueSaturation(saturationGraphView, title: "Saturation", for: backgroundColor ?? UIColor.clear)
        drawHueSaturation(saturationGraphView2, title: "Saturation", for: primaryColor ?? UIColor.clear)
        drawHueSaturation(saturationGraphView3, title: "Saturation", for: secondaryColor ?? UIColor.clear)
        drawHueSaturation(saturationGraphView4, title: "Saturation", for: detailColor ?? UIColor.clear)
        
        drawBrightness(brightnessGraphView, for: backgroundColor ?? UIColor.clear)
        drawBrightness(brightnessGraphView2, for: backgroundColor ?? UIColor.clear)
        drawBrightness(brightnessGraphView3, for: backgroundColor ?? UIColor.clear)
        drawBrightness(brightnessGraphView4, for: backgroundColor ?? UIColor.clear)
        
        updateIndicators(for: backgroundColor ?? UIColor.clear)
        updateIndicators2(for: primaryColor ?? UIColor.clear)
        updateIndicators3(for: secondaryColor ?? UIColor.clear)
        updateIndicators4(for: detailColor ?? UIColor.clear)
    }
    
    func findGroups(for colors: [String?]) -> String {
        let groups: [String: [String]] = [
            "Academia": ["Deep Red", "Maroon", "Dark Red", "Dark Pink", "Dark Purple", "Plum", "Burgundy", "Navy", "Forest Green", "Mustard", "Ivory", "Tan", "Chocolate", "Slate Gray", "White", "Snow", "Smoke", "Silver", "Crimson", "Firebrick", "Tomato", "Rose", "Sienna", "Peru", "Burly Wood", "Dark Gray", "Dim Gray"],
            "Coastal": ["Sky Blue", "Baby Blue", "Aqua Blue", "Seafoam Green", "Sandy Beige", "Turquoise", "Navy", "Coral", "Mint Green", "Light Blue", "Light Sky Blue", "Slate Blue", "Pale Blue", "Ivory", "White", "Snow", "Silver", "Teal", "Azure Blue", "Steel Blue", "Deep Sky Blue", "Midnight Blue", "Gray Blue", "Pale Violet Red"],
            "Cottagecore": ["Blush", "Peach Puff", "Light Coral", "Misty Rose", "Peach", "Pale Peach", "Salmon", "Lavender", "Thistle", "Tan", "Ivory", "Flax", "Light Yellow", "Pale Green", "Beige", "Sandy Brown", "White", "Snow", "Raspberry", "Hot Pink", "Fuchsia", "Orchid", "Rose", "Tangerine", "Vibrant Orange", "Light Orange", "Pumpkin", "Carrot Orange", "Pastel Yellow", "Lemon", "Golden Yellow", "Gold"],
            "Emo": ["Black", "Charcoal Gray", "Blood Red", "Deep Purple", "Dark Olive", "Slate Gray", "Midnight Blue", "Dark Blue", "Dark Lavender", "Sienna", "Saddle Brown", "Maroon", "Crimson", "Firebrick", "Dark Red", "Tomato", "Plum", "Navy", "Forest Green", "Army Green", "Teal Green"],
            "Professional": ["Navy", "Charcoal Gray", "Taupe", "Ivory", "White", "Slate Gray", "Light Gray", "Medium Gray", "Dark Gray", "Silver", "Gainsboro", "Smoke"],
            "Streetwear": ["Red", "Bright Red", "Vibrant Orange", "Bright Yellow", "Mustard", "Lime", "Olive", "Army Green", "Teal", "Bright Lime", "Bright Green", "Dark Green", "Yellow Green", "Burnt Orange", "Pumpkin", "Orange", "Carrot Orange", "Dark Olive", "Lemon", "Gold", "Bright Lime", "Bright Green", "Yellow Green", "Teal Green", "Sadge Green", "Navy", "Baby Blue", "Royal Blue", "Azure Blue", "Gray Blue", "Deep Sky Blue", "Slate Blue", "Dark Purple", "Violet", "Plum", "Blurple", "Light Pink", "Hot Pink", "Fuchsia", "Deep Pink", "Rose", "Coral", "Deep Pink", "Peach", "Tangerine", "Peach Puff", "Cherry Red", "Scarlet Red", "Raspberry", "Maroon", "Crimson", "Firebrick", "Tomato", "Black", "Charcoal Gray", "Black", "Dim Gray", "Burly Wood", "Peru", "Sienna", "Saddle Brown", "Brown", "Tan"],
            "Y2K": ["Bubblegum Pink", "Baby Blue", "Sky Blue", "Lemon", "Golden Yellow", "Pastel Pink", "Pastel Yellow", "Pale Violet Red", "Orchid", "Light Pink", "Light Orange", "Pale Green", "Lavender", "Light Yellow", "Light Coral", "Light Orange", "Pastel Yellow", "Light Green", "Light Blue", "Peach Puff", "Ivory", "Flax", "White", "Snow", "Hot Pink", "Fuchsia", "Salmon", "Coral", "Tangerine", "Vibrant Orange", "Pumpkin", "Carrot Orange"]
        ]
        
        var foundGroups: Set<String> = []
        
        for color in colors {
            guard let colorName = color else { continue }
            for (group, groupColors) in groups {
                if groupColors.contains(colorName) {
                    foundGroups.insert(group)
                }
            }
        }
        
        return foundGroups.joined(separator: ", ")
    }
    
    private func drawHueSaturation(_ graphView: UIView, title: String, for color: UIColor) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = graphView.bounds
        
        if title == "Hue" {
            gradientLayer.colors = (0...360).map { hue in
                UIColor(hue: CGFloat(hue) / 360.0, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor
            }
        } else if title == "Saturation" {
            gradientLayer.colors = [
                UIColor(hue: hue, saturation: 0.0, brightness: 1.0, alpha: 1.0).cgColor,
                UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0).cgColor
            ]
        }
        
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        graphView.layer.addSublayer(gradientLayer)
    }
    
    private func drawBrightness(_ graphView: UIView, for color: UIColor) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = graphView.bounds
        gradientLayer.colors = [
            UIColor.black.cgColor,
            UIColor.white.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        graphView.layer.addSublayer(gradientLayer)

    }
    
    private func setupIndicator(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circle = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circle.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circle.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func setupIndicators(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circles = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circles.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circles.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func setupIndicatorss(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circless = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circless.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circless.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func updateIndicators(for color: UIColor) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        setupIndicator(hueIndicator, for: hueGraphView, with: hue)
        setupIndicators(saturationIndicator, for: saturationGraphView, with: saturation)
        setupIndicatorss(brightnessIndicator, for: brightnessGraphView, with: brightness)
    }
    
    private func setupIndicator2(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circle2 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circle2.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circle2.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func setupIndicators2(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circles2 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circles2.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circles2.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func setupIndicatorss2(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circless2 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circless2.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circless2.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func updateIndicators2(for color: UIColor) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        setupIndicator2(hueIndicator2, for: hueGraphView2, with: hue)
        setupIndicators2(saturationIndicator2, for: saturationGraphView2, with: saturation)
        setupIndicatorss2(brightnessIndicator2, for: brightnessGraphView2, with: brightness)
    }
    
    private func setupIndicator3(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circle3 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circle3.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circle3.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func setupIndicators3(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circles3 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circles3.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circles3.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func setupIndicatorss3(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circless3 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circless3.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circless3.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func updateIndicators3(for color: UIColor) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        setupIndicator3(hueIndicator3, for: hueGraphView3, with: hue)
        setupIndicators3(saturationIndicator3, for: saturationGraphView3, with: saturation)
        setupIndicatorss3(brightnessIndicator3, for: brightnessGraphView3, with: brightness)
    }
    
    private func setupIndicator4(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circle4 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circle4.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circle4.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func setupIndicators4(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circles4 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circles4.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circles4.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
    
    private func setupIndicatorss4(_ indicator: UIView, for graphView: UIView, with value: CGFloat) {
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.backgroundColor = .white
        indicator.layer.borderColor = UIColor.black.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 5
        graphView.addSubview(indicator)
    
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 10),
            indicator.heightAnchor.constraint(equalToConstant: 10),
            indicator.centerYAnchor.constraint(equalTo: graphView.centerYAnchor)
        ])
        let position = 32 + (325 * value)
        circless4 = indicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0)
        circless4.isActive = true

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.circless4.constant = position
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
        
    }
        
    private func updateIndicators4(for color: UIColor) {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        setupIndicator4(hueIndicator4, for: hueGraphView4, with: hue)
        setupIndicators4(saturationIndicator4, for: saturationGraphView4, with: saturation)
        setupIndicatorss4(brightnessIndicator4, for: brightnessGraphView4, with: brightness)
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
    ColorName(name: "Bright Red", red: 0.98, green: 0.01, blue: 0.01),
    ColorName(name: "Bright Red", red: 0.96, green: 0.02, blue: 0.02),
    ColorName(name: "Red", red: 0.816, green: 0.192, blue: 0.176),
    ColorName(name: "Red", red: 0.84, green: 0.16, blue: 0.17),
    ColorName(name: "Red", red: 0.82, green: 0.14, blue: 0.18),
    ColorName(name: "Cherry Red", red: 0.6, green: 0.059, blue: 1),
    ColorName(name: "Cherry Red", red: 0.63, green: 0.07, blue: 1),
    ColorName(name: "Cherry Red", red: 0.61, green: 0.05, blue: 1),
    ColorName(name: "Scarlet Red", red: 0.565, green: 0.051, blue: 0.035),
    ColorName(name: "Scarlet Red", red: 0.55, green: 0.05, blue: 0.04),
    ColorName(name: "Scarlet Red", red: 0.57, green: 0.05, blue: 0.03),
    ColorName(name: "Raspberry", red: 0.827, green: 0.102, blue: 0.22),
    ColorName(name: "Raspberry", red: 0.84, green: 0.12, blue: 0.23),
    ColorName(name: "Raspberry", red: 0.81, green: 0.1, blue: 0.21),
    ColorName(name: "Maroon", red: 0.502, green: 0.102, blue: 0.22),
    ColorName(name: "Maroon", red: 0.49, green: 0.1, blue: 0.22),
    ColorName(name: "Maroon", red: 0.51, green: 0.12, blue: 0.21),
    ColorName(name: "Crimson", red: 0.863, green: 0.078, blue: 0.235),
    ColorName(name: "Firebrick", red: 0.698, green: 0.133, blue: 0.133),
    ColorName(name: "Dark Red", red: 0.545, green: 0.0, blue: 0.0),
    ColorName(name: "Tomato", red: 1.0, green: 0.388, blue: 0.278),
        
    //Pink
    ColorName(name: "Light Pink", red: 1, green: 0.714, blue: 0.757),
    ColorName(name: "Light Pink", red: 1, green: 0.73, blue: 0.76),
    ColorName(name: "Light Pink", red: 1, green: 0.72, blue: 0.75),
    ColorName(name: "Dark Pink", red: 0.906, green: 0.329, blue: 0.502),
    ColorName(name: "Dark Pink", red: 0.89, green: 0.33, blue: 0.51),
    ColorName(name: "Dark Pink", red: 0.91, green: 0.31, blue: 0.49),
    ColorName(name: "Hot Pink", red: 1, green: 0.412, blue: 0.706),
    ColorName(name: "Pastel Pink", red: 0.996, green: 0.773, blue: 0.898),
    ColorName(name: "Pastel Pink", red: 0.98, green: 0.77, blue: 0.89),
    ColorName(name: "Pastel Pink", red: 1, green: 0.78, blue: 0.90),
    ColorName(name: "Salmon", red: 0.992, green: 0.671, blue: 0.624),
    ColorName(name: "Salmon", red: 0.99, green: 0.68, blue: 0.62),
    ColorName(name: "Salmon", red: 0.98, green: 0.67, blue: 0.63),
    ColorName(name: "Coral", red: 0.996, green: 0.49, blue: 0.416),
    ColorName(name: "Coral", red: 1, green: 0.5, blue: 0.42),
    ColorName(name: "Coral", red: 0.99, green: 0.49, blue: 0.41),
    ColorName(name: "Deep Pink", red: 1, green: 0.078, blue: 0.576),
    ColorName(name: "Pale Violet Red", red: 0.859, green: 0.439, blue: 0.576),
    ColorName(name: "Fuchsia", red: 1, green: 0.0, blue: 1.0),
    ColorName(name: "Orchid", red: 0.855, green: 0.439, blue: 0.839),
    ColorName(name: "Blush", red: 0.871, green: 0.365, blue: 0.514),
    ColorName(name: "Rose", red: 1.0, green: 0.0, blue: 0.498),
    ColorName(name: "Peach Puff", red: 1.0, green: 0.855, blue: 0.725),
    ColorName(name: "Light Coral", red: 0.941, green: 0.502, blue: 0.502),
    ColorName(name: "Misty Rose", red: 1.0, green: 0.894, blue: 0.882),

    //Orange
    ColorName(name: "Tangerine", red: 0.949, green: 0.522, blue: 0),
    ColorName(name: "Tangerine", red: 0.91, green: 0.533, blue: 0.071),
    ColorName(name: "Tangerine", red: 0.961, green: 0.561, blue: 0.071),
    ColorName(name: "Tangerine", red: 1, green: 0.729, blue: 0),

    ColorName(name: "Vibrant Orange", red: 1, green: 0.525, blue: 0),
    ColorName(name: "Vibrant Orange", red: 0.949, green: 0.533, blue: 0),
    ColorName(name: "Vibrant Orange", red: 0.961, green: 0.561, blue: 0.047),
    ColorName(name: "Vibrant Orange", red: 1, green: 0.54, blue: 0.01),
    ColorName(name: "Vibrant Orange", red: 1, green: 0.52, blue: 0.02),

    ColorName(name: "Light Orange", red: 1, green: 0.71, blue: 0.388),
    ColorName(name: "Light Orange", red: 1, green: 0.682, blue: 0.318),
    ColorName(name: "Light Orange", red: 1, green: 0.749, blue: 0.463),
    ColorName(name: "Light Orange", red: 1, green: 0.796, blue: 0.247),

    ColorName(name: "Pale Peach", red: 1, green: 0.859, blue: 0.706),
    ColorName(name: "Pale Peach", red: 0.98, green: 0.859, blue: 0.718),
    ColorName(name: "Pale Peach", red: 0.98, green: 0.886, blue: 0.784),
    ColorName(name: "Pale Peach", red: 1, green: 0.824, blue: 0.686),
    ColorName(name: "Pale Peach", red: 0.961, green: 0.82, blue: 0.706),

    ColorName(name: "Pumpkin", red: 1.0, green: 0.459, blue: 0.094),
    ColorName(name: "Light Orange", red: 1, green: 0.71, blue: 0.388),
    ColorName(name: "Orange", red: 1, green: 0.627, blue: 0.212),
    ColorName(name: "Dark Orange", red: 1.0, green: 0.549, blue: 0.0),
    ColorName(name: "Burnt Orange", red: 0.8, green: 0.333, blue: 0.0),
    ColorName(name: "Peach", red: 1.0, green: 0.898, blue: 0.706),
    ColorName(name: "Carrot Orange", red: 0.929, green: 0.569, blue: 0.129),


    //Yellow
    ColorName(name: "Bright Yellow", red: 1, green: 0.984, blue: 0),
    ColorName(name: "Bright Yellow", red: 1, green: 0.964, blue: 0),
    ColorName(name: "Bright Yellow", red: 0.95, green: 1, blue: 0),

    ColorName(name: "Mustard", red: 0.996, green: 0.863, blue: 0.337),
    ColorName(name: "Mustard", red: 0.878, green: 0.765, blue: 0.298),
    ColorName(name: "Mustard", red: 0.878, green: 0.725, blue: 0.114),
    ColorName(name: "Mustard", red: 1, green: 0.87, blue: 0.34),
    ColorName(name: "Mustard", red: 0.99, green: 0.86, blue: 0.33),

    ColorName(name: "Pastel Yellow", red: 1, green: 1, blue: 0.584),
    ColorName(name: "Pastel Yellow", red: 1, green: 1, blue: 0.749),
    ColorName(name: "Pastel Yellow", red: 1, green: 1, blue: 0.431),
    ColorName(name: "Pastel Yellow", red: 1, green: 1, blue: 0.59),
    ColorName(name: "Pastel Yellow", red: 1, green: 1, blue: 0.58),

    ColorName(name: "Lemon", red: 1, green: 0.964, blue: 0),
    ColorName(name: "Golden Yellow", red: 0.98, green: 0.82, blue: 0.039),
    ColorName(name: "Mustard", red: 0.996, green: 0.863, blue: 0.337),
    ColorName(name: "Gold", red: 1, green: 0.843, blue: 0),
    ColorName(name: "Light Yellow", red: 1, green: 1, blue: 0.878),
    ColorName(name: "Ivory", red: 1, green: 1, blue: 0.941),
    ColorName(name: "Yellow", red: 1, green: 1, blue: 0),
    ColorName(name: "Flax", red: 0.933, green: 0.863, blue: 0.509),

    //Green
    ColorName(name: "Bright Green", red: 0.0, green: 1.0, blue: 0.0),
    ColorName(name: "Bright Green", red: 0.01, green: 0.98, blue: 0.01),
    ColorName(name: "Bright Green", red: 0.02, green: 0.96, blue: 0.02),
    ColorName(name: "Light Green", red: 0.565, green: 0.933, blue: 0.1),
    ColorName(name: "Light Green", red: 0.58, green: 0.92, blue: 0.12),
    ColorName(name: "Light Green", red: 0.56, green: 0.93, blue: 0.11),
    ColorName(name: "Dark Green", red: 0.0, green: 0.392, blue: 0.0),
    ColorName(name: "Dark Green", red: 0.01, green: 0.38, blue: 0.01),
    ColorName(name: "Dark Green", red: 0.02, green: 0.37, blue: 0.02),
    ColorName(name: "Mint Green", red: 0.596, green: 0.984, blue: 0.596),
    ColorName(name: "Mint Green", red: 0.8, green: 0.886, blue: 0.839),
    ColorName(name: "Yellow Green", red: 0.788, green: 0.765, blue: 0.063),
    ColorName(name: "Yellow Green", red: 0.831, green: 0.808, blue: 0.192),
    ColorName(name: "Yellow Green", red: 0.663, green: 0.69, blue: 0.216),
    ColorName(name: "Olive", red: 0.569, green: 0.561, blue: 0.322),
    ColorName(name: "Olive", red: 0.439, green: 0.51, blue: 0.22),
    ColorName(name: "Olive", red: 0.361, green: 0.353, blue: 0.094),
    ColorName(name: "Dark Olive", red: 0.333, green: 0.42, blue: 0.184),
    ColorName(name: "Lime", red: 0.745, green: 1.0, blue: 0.369),
    ColorName(name: "Army Green", red: 0.294, green: 0.325, blue: 0.125),
    ColorName(name: "Yellow Green", red: 0.678, green: 1, blue: 0.184),
    ColorName(name: "Sea Green", red: 0.18, green: 0.545, blue: 0.341),
    ColorName(name: "Sea Green", red: 0.18, green: 0.545, blue: 0.341),
    ColorName(name: "Forest Green", red: 0.133, green: 0.545, blue: 0.133),
    ColorName(name: "Forest Green", red: 0.067, green: 0.239, blue: 0.145),
    ColorName(name: "Pale Green", red: 0.596, green: 0.984, blue: 0.596),
    ColorName(name: "Bright Lime", red: 0.498, green: 1.0, blue: 0.0),
    ColorName(name: "Spring Green", red: 0.0, green: 1.0, blue: 0.498),
    ColorName(name: "Teal Green", red: 0.0, green: 0.502, blue: 0.502),
    ColorName(name: "Sage Green", red: 0.522, green: 0.651, blue: 0.58),

    //Blue
    ColorName(name: "Navy", red: 0.0, green: 0.0, blue: 0.502),
    ColorName(name: "Navy", red: 0.22, green: 0.239, blue: 0.29),
    ColorName(name: "Navy", red: 0.09, green: 0.09, blue: 0.322),
    ColorName(name: "Navy", red: 0.204, green: 0.204, blue: 0.439),
    ColorName(name: "Navy", red: 0.122, green: 0.122, blue: 0.49),

    ColorName(name: "Teal", red: 0.247, green: 0.878, blue: 0.816),
    ColorName(name: "Teal", red: 0.0, green: 0.651, blue: 0.651),

    ColorName(name: "Baby Blue", red: 0.537, green: 0.812, blue: 0.941),
    ColorName(name: "Baby Blue", red: 0.54, green: 0.81, blue: 0.94),
    ColorName(name: "Baby Blue", red: 0.53, green: 0.82, blue: 0.93),

    ColorName(name: "Sky Blue", red: 0.584, green: 0.784, blue: 0.847),
    ColorName(name: "Sky Blue", red: 0.59, green: 0.78, blue: 0.85),
    ColorName(name: "Sky Blue", red: 0.58, green: 0.79, blue: 0.84),

    ColorName(name: "Royal Blue", red: 0.067, green: 0.118, blue: 0.424),
    ColorName(name: "Royal Blue", red: 0.0, green: 0.0, blue: 1.0),
    ColorName(name: "Royal Blue", red: 0.067, green: 0.067, blue: 0.722),
    ColorName(name: "Royal Blue", red: 0.102, green: 0.102, blue: 0.839),
    ColorName(name: "Royal Blue", red: 0.337, green: 0.337, blue: 0.839),
    ColorName(name: "Royal Blue", red: 0.235, green: 0.235, blue: 0.878),

    ColorName(name: "Azure Blue", red: 0, green: 0.498, blue: 1),
    ColorName(name: "Azure Blue", red: 0.01, green: 0.50, blue: 1),
    ColorName(name: "Azure Blue", red: 0, green: 0.49, blue: 0.99),

    ColorName(name: "Gray Blue", red: 0.471, green: 0.525, blue: 0.608),
    ColorName(name: "Gray Blue", red: 0.48, green: 0.53, blue: 0.61),
    ColorName(name: "Gray Blue", red: 0.47, green: 0.52, blue: 0.60),

    ColorName(name: "Dark Blue", red: 0.0, green: 0.0, blue: 0.545),
    ColorName(name: "Azure Blue", red: 0.118, green: 0.565, blue: 1.0),
    ColorName(name: "Steel Blue", red: 0.275, green: 0.51, blue: 0.706),
    ColorName(name: "Pale Blue", red: 0.392, green: 0.584, blue: 0.929),
    ColorName(name: "Light Sky Blue", red: 0.529, green: 0.808, blue: 0.98),
    ColorName(name: "Deep Sky Blue", red: 0.0, green: 0.749, blue: 1.0),
    ColorName(name: "Midnight Blue", red: 0.098, green: 0.098, blue: 0.439),
    ColorName(name: "Slate Blue", red: 0.416, green: 0.353, blue: 0.804),

        
    //Purple
    ColorName(name: "Dark Purple", red: 0.314, green: 0.243, blue: 0.42),
    ColorName(name: "Dark Purple", red: 0.275, green: 0.18, blue: 0.42),
    ColorName(name: "Dark Purple", red: 0.216, green: 0.059, blue: 0.451),
    ColorName(name: "Dark Purple", red: 0.133, green: 0.039, blue: 0.278),
    ColorName(name: "Dark Purple", red: 0.22, green: 0.169, blue: 0.302),

    ColorName(name: "Lavender", red: 0.663, green: 0.569, blue: 0.91),
    ColorName(name: "Lavender", red: 0.78, green: 0.718, blue: 0.929),
    ColorName(name: "Lavender", red: 0.878, green: 0.831, blue: 0.988),
    ColorName(name: "Lavender", red: 0.914, green: 0.882, blue: 1),
    ColorName(name: "Lavender", red: 0.812, green: 0.737, blue: 1),

    ColorName(name: "Dark Lavender", red: 0.71, green: 0.671, blue: 0.812),
    ColorName(name: "Dark Lavender", red: 0.729, green: 0.698, blue: 0.8),
    ColorName(name: "Dark Lavender", red: 0.659, green: 0.596, blue: 0.82),

    ColorName(name: "Blurple", red: 0.333, green: 0.263, blue: 0.812),
    ColorName(name: "Blurple", red: 0.569, green: 0.518, blue: 0.89),
    ColorName(name: "Blurple", red: 0.271, green: 0.204, blue: 0.851),

    ColorName(name: "Violet", red: 0.933, green: 0.51, blue: 0.933),
    ColorName(name: "Purple", red: 0.502, green: 0.0, blue: 0.502),
    ColorName(name: "Plum", red: 0.867, green: 0.627, blue: 0.867),
    ColorName(name: "Thistle", red: 0.847, green: 0.749, blue: 0.847),
    ColorName(name: "Orchid", red: 0.855, green: 0.439, blue: 0.839),


    //Brown/Tan
    ColorName(name: "Tan", red: 0.812, green: 0.765, blue: 0.706),
    ColorName(name: "Tan", red: 0.824, green: 0.706, blue: 0.549),
    ColorName(name: "Tan", red: 0.89, green: 0.761, blue: 0.596),
    ColorName(name: "Tan", red: 0.812, green: 0.667, blue: 0.478),
    ColorName(name: "Tan", red: 0.812, green: 0.663, blue: 0.404),

    ColorName(name: "Bronze", red: 0.631, green: 0.467, blue: 0.086),
    ColorName(name: "Bronze Beige", red: 0.494, green: 0.451, blue: 0.353),

    ColorName(name: "Brown", red: 0.231, green: 0.145, blue: 0.047),
    ColorName(name: "Brown", red: 0.278, green: 0.161, blue: 0.024),
    ColorName(name: "Brown", red: 0.812, green: 0.765, blue: 0.706),
    ColorName(name: "Brown", red: 0.278, green: 0.192, blue: 0.024),
    ColorName(name: "Brown", red: 0.24, green: 0.15, blue: 0.05),
    ColorName(name: "Brown", red: 0.23, green: 0.14, blue: 0.04),
    ColorName(name: "Brown", red: 0.27, green: 0.18, blue: 0.06),
    ColorName(name: "Brown", red: 0.26, green: 0.17, blue: 0.05),

    ColorName(name: "Chocolate", red: 0.482, green: 0.247, blue: 0),
    ColorName(name: "Chocolate", red: 0.459, green: 0.267, blue: 0.059),
    ColorName(name: "Chocolate", red: 0.49, green: 0.329, blue: 0.153),
    ColorName(name: "Chocolate", red: 0.541, green: 0.318, blue: 0.082),
    ColorName(name: "Chocolate", red: 0.482, green: 0.247, blue: 0),
    ColorName(name: "Chocolate", red: 0.329, green: 0.169, blue: 0),

    ColorName(name: "Saddle Brown", red: 0.545, green: 0.271, blue: 0.075),
    ColorName(name: "Saddle Brown", red: 0.55, green: 0.27, blue: 0.08),
    ColorName(name: "Saddle Brown", red: 0.54, green: 0.26, blue: 0.07),
    ColorName(name: "Sienna", red: 0.627, green: 0.322, blue: 0.176),
    ColorName(name: "Sienna", red: 0.63, green: 0.32, blue: 0.18),
    ColorName(name: "Sienna", red: 0.62, green: 0.31, blue: 0.17),
    ColorName(name: "Sandy Brown", red: 0.957, green: 0.643, blue: 0.376),
    ColorName(name: "Peru", red: 0.804, green: 0.522, blue: 0.247),
    ColorName(name: "Peru", red: 0.81, green: 0.52, blue: 0.25),
    ColorName(name: "Peru", red: 0.80, green: 0.51, blue: 0.24),
    ColorName(name: "Burly Wood", red: 0.871, green: 0.722, blue: 0.529),


    //Black, White, Gray
    ColorName(name: "Black", red: 0.0, green: 0.0, blue: 0.0),
    ColorName(name: "Black", red: 0.11, green: 0.11, blue: 0.11),
    ColorName(name: "Black", red: 0.11, green: 0.11, blue: 0.11),
    ColorName(name: "White", red: 0.80, green: 0.80, blue: 0.80),
    ColorName(name: "White", red: 0.81, green: 0.81, blue: 0.81),
    ColorName(name: "White", red: 0.82, green: 0.82, blue: 0.82),
    ColorName(name: "White", red: 0.79, green: 0.79, blue: 0.79),
    ColorName(name: "White", red: 0.78, green: 0.78, blue: 0.78),
    ColorName(name: "White", red: 0.827, green: 0.827, blue: 0.827),
    ColorName(name: "White", red: 0.867, green: 0.867, blue: 0.867),
    ColorName(name: "Medium Gray", red: 0.61, green: 0.61, blue: 0.61),
    ColorName(name: "Medium Gray", red: 0.62, green: 0.62, blue: 0.62),
    ColorName(name: "Medium Gray", red: 0.60, green: 0.60, blue: 0.60),
    ColorName(name: "Medium Gray", red: 0.63, green: 0.63, blue: 0.63),
    ColorName(name: "Medium Gray", red: 0.59, green: 0.59, blue: 0.59),
    ColorName(name: "Medium Gray", red: 0.659, green: 0.659, blue: 0.659),
    ColorName(name: "Dark Gray", red: 0.38, green: 0.38, blue: 0.38),
    ColorName(name: "Dark Gray", red: 0.412, green: 0.412, blue: 0.412),
    ColorName(name: "Dark Gray", red: 0.333, green: 0.333, blue: 0.333),
    ColorName(name: "Dark Gray", red: 0.34, green: 0.34, blue: 0.34),
    ColorName(name: "Dark Gray", red: 0.32, green: 0.32, blue: 0.32),
    ColorName(name: "Dark Gray", red: 0.35, green: 0.35, blue: 0.35),
    ColorName(name: "Dark Gray", red: 0.31, green: 0.31, blue: 0.31),
    ColorName(name: "Slate Gray", red: 0.44, green: 0.50, blue: 0.56),
    ColorName(name: "Slate Gray", red: 0.45, green: 0.51, blue: 0.57),
    ColorName(name: "Slate Gray", red: 0.43, green: 0.49, blue: 0.55),
    ColorName(name: "Slate Gray", red: 0.46, green: 0.52, blue: 0.58),
    ColorName(name: "Slate Gray", red: 0.42, green: 0.48, blue: 0.54),
    ColorName(name: "Dim Gray", red: 0.41, green: 0.41, blue: 0.41),
    ColorName(name: "Dim Gray", red: 0.42, green: 0.42, blue: 0.42),
    ColorName(name: "Dim Gray", red: 0.40, green: 0.40, blue: 0.40),
    ColorName(name: "Dim Gray", red: 0.43, green: 0.43, blue: 0.43),
    ColorName(name: "Dim Gray", red: 0.39, green: 0.39, blue: 0.39),
    ColorName(name: "White", red: 1.0, green: 1.0, blue: 1.0),
    ColorName(name: "White", red: 0.93, green: 0.93, blue: 0.93),
    ColorName(name: "White", red: 0.949, green: 0.91, blue: 0.91),
    ColorName(name: "Ivory", red: 1.0, green: 1.0, blue: 0.941),
    ColorName(name: "Snow", red: 1.0, green: 0.98, blue: 0.98),
    ColorName(name: "Gainsboro", red: 0.863, green: 0.863, blue: 0.863),
    ColorName(name: "Smoke", red: 0.961, green: 0.961, blue: 0.961),
    ColorName(name: "Silver", red: 0.753, green: 0.753, blue: 0.753),

]

//Distance Calculator for colors
func calcDistance(color1: (CGFloat, CGFloat, CGFloat), color2: (CGFloat, CGFloat, CGFloat)) -> CGFloat {
    return sqrt(pow(color1.0 - color2.0, 2) + pow(color1.1 - color2.1, 2) + pow(color1.2 - color2.2, 2))
}

//Find the color name closest to the RGB values
func findClosestColorName(to color: UIColor) -> String {
    guard let components = color.cgColor.components, components.count >= 3 else {
        return "Unknown"
    }

    var closestColor: ColorName?
    var smallestDistance: CGFloat = .greatestFiniteMagnitude
    
    for predefinedColor in predefinedColors {
        let predefinedRGB = (predefinedColor.red, predefinedColor.green, predefinedColor.blue)
        let distance = calcDistance(color1: (components[0], components[1], components[2]), color2: predefinedRGB)
        
        if distance < smallestDistance {
            smallestDistance = distance
            closestColor = predefinedColor
        }
    }

    return closestColor?.name ?? "Unknown"
    
}

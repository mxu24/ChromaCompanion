import UIKit
import Vision
import UIImageColors

class ViewController: UIViewController {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.backgroundColor = .white
        button.setTitle("Take/Choose Picture", for: .normal)
        button.setTitleColor(.white, for: .normal)
    }
    
    @IBAction func didTapButton() {
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
        
        // Convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else {
            return
        }
        
        // Create attention-based saliency request
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        
        // Perform saliency request
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                if let results = request.results,
                   let salientObject = results.first,
                   let salientRect = salientObject.salientObjects?.first?.boundingBox {
                    
                    // Normalized coordinates to image coordinates
                    let imageRect = ciImage.extent
                    let normalizedSalientRect = VNImageRectForNormalizedRect(salientRect, Int(imageRect.width), Int(imageRect.height))
                    
                    // Crop image to salient rect
                    let croppedImage = ciImage.cropped(to: normalizedSalientRect)
                    let thumbnail = UIImage(ciImage: croppedImage)
                    
                    DispatchQueue.main.async {
                        self.imageView.image = thumbnail
                        self.extractColors(from: thumbnail)
                    }
                } else {
                    // If no salient region found, use original image
                    DispatchQueue.main.async {
                        self.imageView.image = image
                        self.extractColors(from: image)
                    }
                }
            } catch {
                print("Error performing saliency request: \(error)")
                DispatchQueue.main.async {
                    self.imageView.image = image
                    self.extractColors(from: image)
                }
            }
        }
    }
    
    private func extractColors(from image: UIImage) {
        image.getColors { colors in
            guard let colors = colors else { return }
            let background = colors.background ?? UIColor.black
            let primary = colors.primary ?? UIColor.black
            let secondary = colors.secondary ?? UIColor.black
            let detail = colors.detail ?? UIColor.black
            DispatchQueue.main.async {
                self.presentColorAnalysisViewController(primary: primary, secondary: secondary, background: background, detail: detail)
            }
            print("Background: \(background), Primary: \(primary), Secondary: \(secondary), Detail: \(detail)")
        }
    }
    
    private func presentColorAnalysisViewController(primary: UIColor, secondary: UIColor, background: UIColor, detail: UIColor) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let colorInfoVC = storyboard.instantiateViewController(withIdentifier: "ColorAnalysisViewController") as? ColorAnalysisViewController else {
            return
        }
        
        colorInfoVC.primaryColor = primary
        colorInfoVC.secondaryColor = secondary
        colorInfoVC.backgroundColor = background
        colorInfoVC.detailColor = detail
        
        navigationController?.pushViewController(colorInfoVC, animated: true)
    }
}

class ColorAnalysisViewController: UIViewController {
    @IBOutlet weak var primaryColorView: UIView!
    @IBOutlet weak var secondaryColorView: UIView!
    @IBOutlet weak var backgroundColorView: UIView!
    @IBOutlet weak var detailColorView: UIView!
    
    var primaryColor: UIColor?
    var secondaryColor: UIColor?
    var backgroundColor: UIColor?
    var detailColor: UIColor?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("Background")
        // Set the background colors of the views to display the colors
//        primaryColorView.backgroundColor = primaryColor
//        secondaryColorView.backgroundColor = secondaryColor
//        backgroundColorView.backgroundColor = backgroundColor
//        detailColorView.backgroundColor = detailColor
    }
}

// With guidance from demo by iOS Academy on YouTube

import UIKit
import Vision
//import UIImageColors

class ViewController: UIViewController{
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.backgroundColor = .white
        button.setTitle("Take Picture", for: .normal)
        button.setTitleColor(.white, for: .normal)
    }
    
    @IBAction func didTapButton() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension ViewController: UIImagePickerControllerDelegate,
                          UINavigationControllerDelegate {
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        guard let image = info[UIImagePickerController.InfoKey.editedImage] as? UIImage else {
            return
        }
        
        // convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else {
            return
        }
        
        // create objectness-based saliency request
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        
        // perform saliency request
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                if let results = request.results,
                   let salientObject = results.first,
                   let salientRect = salientObject.salientObjects?.first?.boundingBox {
                    
                    // normalized coordinates to image coordinates
                    let imageRect = ciImage.extent
                    let normalizedSalientRect = VNImageRectForNormalizedRect(salientRect, Int(imageRect.width), Int(imageRect.height))
                    
                    // crop image to salient rect
                    let croppedImage = ciImage.cropped(to: normalizedSalientRect)
                    let thumbnail = UIImage(ciImage: croppedImage)
                    
                    DispatchQueue.main.async {
                        self.imageView.image = thumbnail
                    }
                    
//                    let colors = thumbnail.getColors()
//                    let background = colors.background
//                    let primary = colors.primary
//                    let secondary = colors.secondary
//                    let detail = colors.detail
//                    print(background)
//                    print(primary)
//                    print(secondary)
//                    print(detail)
                } else {
                    // if no salient region found, use original image
                    DispatchQueue.main.async {
                        self.imageView.image = image
                    }
                    
//                    let colors = image.getColors()
//                    let background = colors?.background
//                    let primary = colors?.primary
//                    let secondary = colors?.secondary
//                    let detail = colors?.detail
                }
            } catch {
                print("Error performing saliency request: \(error)")
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
                
//                let colors = image.getColors()
//                let background = colors?.background
//                let primary = colors?.primary
//                let secondary = colors?.secondary
//                let detail = colors?.detail
            }
        }
    }

    
    

}


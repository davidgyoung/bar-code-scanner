//
//  ImagePreviewViewController.swift
//  BarCodeScanner
//
//  Created by David G. Young on 4/4/18.
//  Copyright © 2018 David G. Young. All rights reserved.
//

import UIKit

class ImagePreviewViewController: UIViewController{

    @IBOutlet weak var imageView: UIImageView!
    
    var image:UIImage? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Captured Image Preview"
        if let image = image {
            imageView.image = image
        }
    }
}

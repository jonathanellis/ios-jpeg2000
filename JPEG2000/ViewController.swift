//
//  ViewController.swift
//  JPEG2000
//
//  Created by Jonathan Ellis on 19/06/2023.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        let url = Bundle.main.url(forResource: "sample1.jp2", withExtension: nil)!
        let data = try! Data(contentsOf: url)
        imageView.image = UIImage(jpeg2000Data: data)
    }

}

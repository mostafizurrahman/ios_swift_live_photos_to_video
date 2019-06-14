//
//  LivePhotoCollectionViewController.swift
//  LivePreview
//
//  Created by David Rothschild on 1/1/17.
//  Copyright © 2017 Dave Rothschild. All rights reserved.
//

import UIKit
import Photos
import PhotosUI

class LivePhotoCollectionViewController: UIViewController {

    @IBOutlet weak var sampleImageView: UIImageView!
    @IBOutlet weak var widthLayout: NSLayoutConstraint!
    @IBOutlet weak var leadingSpace: NSLayoutConstraint!
    @IBOutlet weak var shareContainer: UIView!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    var photoView:PHLivePhotoView!
    var livePhotoAsset:PHAsset?
    @IBOutlet weak var containerView:UIView!
    var imageArray:[UIImage] = []
    var player:AVPlayer?
    var playerLayer:AVPlayerLayer?
    var playBarButton:UIBarButtonItem!
    var doneBarButton:UIBarButtonItem!
    @IBOutlet weak var imageCollectionView: UICollectionView!
    override func viewDidLoad() {
        super.viewDidLoad()

        self.leadingSpace.constant = UIScreen.main.bounds.width
        self.widthLayout.constant = UIScreen.main.bounds.width
        self.view.layoutIfNeeded()
        photoView = PHLivePhotoView(frame: self.containerView.bounds)
        photoView.contentMode = .scaleAspectFit
        self.containerView.insertSubview(photoView, at: 0)
        
        applyEdgeFilterToImage()
        self.playBarButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self,
                                            action: #selector(LivePhotoCollectionViewController.playAnimation))
        self.doneBarButton = UIBarButtonItem(barButtonSystemItem: .done, target: self,
                                             action: #selector(LivePhotoCollectionViewController.playAnimation))
        
        self.navigationItem.rightBarButtonItem = self.playBarButton
        
    }

    
    @IBAction func saveAsVideo(_ sender: Any) {
        var videoResource:PHAssetResource? = nil
        guard let _asset = self.livePhotoAsset else {return}
        let resourcesArray = PHAssetResource.assetResources(for: _asset)
        if (resourcesArray.count > 1) {
            for resource in resourcesArray {
                if let url = resource.value(forKey: "_fileURL") as? NSURL,
                    url.path?.contains("MOV") ?? false {
                    videoResource = resource
                    break
                }
            }
        }
        guard let video_res = videoResource else {return}
        if let video_url = video_res.value(forKey: "_fileURL") as? NSURL  {
    
            
            self.leadingSpace.constant = 0
            UIView.animate(withDuration: 0.4, animations: {
                self.view.layoutIfNeeded()
            }) { (finished) in
                self.navigationItem.rightBarButtonItem = self.doneBarButton
                print(video_url)
                if let _player = self.player {
                    _player.pause()
                }
                self.playBarButton.style = UIBarButtonItemStyle.done
                self.playerLayer?.contentsGravity = kCAGravityResizeAspectFill
                self.player = AVPlayer(url: video_url as URL)
                self.playerLayer = AVPlayerLayer(player: self.player)
                self.playerLayer?.frame = self.shareContainer.bounds
                guard  let lyr =  self.playerLayer else {
                    return
                }
                self.shareContainer?.layer.addSublayer(lyr)
                self.player?.play()
                NotificationCenter.default.addObserver(self, selector: #selector(self.avPlayerDidDismiss),
                                                       name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
            }
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
         self.playBarButton.target = nil
        self.doneBarButton.target = nil
    }
    
    
    @objc
    private func avPlayerDidDismiss(_ notification: Notification) {
        player?.currentItem?.seek(to: kCMTimeZero, completionHandler: nil)
        player?.play()
    }
    
    
    fileprivate func applyEdgeFilterToImage() {
        guard let asset = livePhotoAsset else { return }
        
        asset.requestContentEditingInput(with: .none) { [unowned self] (input, info) in
            guard let input = input else { print("error: \(info)"); return }
            var imageRatio:CGFloat = 0.0
            if input.mediaType == .image && input.mediaSubtypes.contains(.photoLive) {
                // We have a live photo
                let editingContext = PHLivePhotoEditingContext(livePhotoEditingInput: input)
                
                let context = CIContext.init(options: [:])
                editingContext?.frameProcessor = { (frame, error) -> CIImage? in
                    var image = frame.image
                    if let imageRef = context.createCGImage(image, from: image.extent) {
                        let uiimage = UIImage.init(cgImage: imageRef)
                        imageRatio = uiimage.size.width / uiimage.size.height
                        self.imageArray.append(uiimage)
                    }
                    image = image.applyingFilter("CIComicEffect", parameters: [:])
                    return image
                }
                
                editingContext?.prepareLivePhotoForPlayback(withTargetSize: self.photoView.bounds.size, options: .none) { (livePhoto, error) in
//                    guard let livePhoto = livePhoto else { print("Preparation error: \(error)"); return }
                    let image_height = self.imageCollectionView.frame.height - 16
                    let image_width = imageRatio * image_height
                    let layout = UICollectionViewFlowLayout()
                    layout.itemSize = CGSize(width: image_width, height: image_height)
                    layout.scrollDirection = .horizontal
                    layout.sectionInset = UIEdgeInsetsMake(8, 8, 8, 8)
                    self.imageCollectionView.collectionViewLayout.invalidateLayout()
                    self.imageCollectionView.collectionViewLayout = layout
                    self.imageCollectionView.reloadData()
                    self.indicator.isHidden = true
                    //            for _view in self.livePhotoView.subviews {
                    //                if let  __view = _view as? PHLivePhotoView {
                    //                    __view.livePhoto = livePhoto
                    //                    break
                    //                }
                    //            }
                }
            } else {
                print("This isn't a live photo")
                return
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureView()
    }
    
    @objc func playAnimation() {
        if self.navigationItem.rightBarButtonItem == self.playBarButton {
            photoView.startPlayback(with: .full)
        } else {
            self.view.sendSubview(toBack: self.imageCollectionView)
            self.navigationItem.rightBarButtonItem = self.playBarButton
            self.leadingSpace.constant = UIScreen.main.bounds.width
            UIView.animate(withDuration: 0.4, animations: {
                self.view.layoutIfNeeded()
            }) { (finished) in
                self.sampleImageView.isHidden = true
                self.player?.pause()
            }
        }
    }
    
    func configureView() {
        if let photoAsset = livePhotoAsset {
            PHImageManager.default().requestLivePhoto(for: photoAsset, targetSize: photoView.frame.size,
                                                      contentMode: .aspectFill, options: nil,
                                                      resultHandler: { (photo:PHLivePhoto?, info:[AnyHashable : Any]?) in
                
                if let livePhoto = photo {
                    self.photoView.livePhoto = livePhoto
                    self.photoView.startPlayback(with: .hint)
                    guard let location = photoAsset.location else {
                        return
                    }
                    let geoCoder = CLGeocoder()
                    geoCoder.reverseGeocodeLocation(location, completionHandler: { (placemark:[CLPlacemark]?, error:Error?) in
                        if error == nil {
                            self.navigationItem.title = placemark?.first?.locality
                        }
                    })
                }
            })
        }
    }

}


extension LivePhotoCollectionViewController:UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.imageArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageCell", for: indexPath)
        let image = self.imageArray[indexPath.row]
        if let imageView = cell.viewWithTag(111) as? UIImageView {
            imageView.image = image
        }
        cell.layer.shadowColor = UIColor.blue.cgColor
        cell.layer.shadowOpacity = 0.15
        cell.layer.shadowRadius = 5
        cell.layer.shadowOffset = CGSize(width: -1, height: 2)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let image = self.imageArray[indexPath.row]
        self.sampleImageView.image = image
        if self.sampleImageView.isHidden {
            self.shareContainer.bringSubview(toFront: self.sampleImageView)
            self.sampleImageView.isHidden = false
            self.leadingSpace.constant = 0
            self.navigationItem.rightBarButtonItem = self.doneBarButton
            UIView.animate(withDuration: 0.4, animations: {
                self.view.layoutIfNeeded()
            }) { (finished) in
                self.view.bringSubview(toFront: self.imageCollectionView)
            }
        }
    }
}

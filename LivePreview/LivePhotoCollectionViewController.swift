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
import Social

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
    var videoUrl:URL?
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

    
    @IBAction func shareFacebook(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: "subscribed"){
            if self.sampleImageView.isHidden {
                self.shareMore(sender)
            } else if let image = self.sampleImageView.image {
                self.shareOnFB(shareImage: image, withAppName: "fb")
            }
        } else {
            self.performSegue(withIdentifier: "SubscribeSegue", sender: self)
        }
        
    }
    
    @IBAction func shareTwitter(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: "subscribed"){
            
            if self.sampleImageView.isHidden {
                self.shareMore(sender)
            } else if let image = self.sampleImageView.image {
                self.shareOnFB(shareImage: image, withAppName: "twitter")
            }
            
        } else {
            self.performSegue(withIdentifier: "SubscribeSegue", sender: self)
        }
    }
    
    @IBAction func shareMore(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: "subscribed"){
            
            if self.sampleImageView.isHidden {
                
                guard let __image =   self.videoUrl  else {
                    return
                }
                
                let activityController = UIActivityViewController.init(activityItems: [__image], applicationActivities: nil)
                activityController.popoverPresentationController?.sourceView = self.view
                self.present(activityController, animated: true) {
                    
                }
            } else {
                
                guard let __image = self.sampleImageView.image else {
                    return
                }
                
                let activityController = UIActivityViewController.init(activityItems: [__image], applicationActivities: nil)
                activityController.popoverPresentationController?.sourceView = self.view
                self.present(activityController, animated: true) {
                    
                }
            }
        } else {
            self.performSegue(withIdentifier: "SubscribeSegue", sender: self)
        }
        
    }
    @IBAction func saveAsVideo(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: "subscribed"){
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
                    self.videoUrl = video_url as URL
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
        } else {
            self.performSegue(withIdentifier: "SubscribeSegue", sender: self)
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

    
    
    
    
    
    
    var photoAsset:PHAsset?
    var videoAsset:PHAsset?
    var placeholder:PHObjectPlaceholder?
    var albumAsset:PHAssetCollection?
    ///SHARING
    @IBAction func shareinstagram(_ sender: Any) {
        if UserDefaults.standard.bool(forKey: "subscribed"){
            if let _ = self.photoAsset,
                !self.sampleImageView.isHidden {
                self.openInstagramShare()
            } else if let _ = self.videoAsset {
                self.openInstagramShare()
            } else {
                PHPhotoLibrary.requestAuthorization { (authorizationStatus) in
                    switch authorizationStatus {
                    case .authorized :
                        self.create()
                        break
                    case .notDetermined:
                        print("not determined")
                        break
                    case .restricted:
                        print("restricted")
                        break
                    case .denied:
                        print("denied")
                        break
                    }
                }
            }
        } else {
            self.performSegue(withIdentifier: "SubscribeSegue", sender: self)
        }
    }
    
    func create(Album name:String = "_LivePhotos_")  {
        //Get PHFetch Options
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let collection : PHFetchResult = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .any, options: fetchOptions)
        //Check return value - If found, then get the first album out
        if let _: AnyObject = collection.firstObject {
            self.albumAsset = collection.firstObject
            DispatchQueue.main.async {
                self.openInstagram()
            }
        } else {
            //If not found - Then create a new album
            PHPhotoLibrary.shared().performChanges({
                let createAlbumRequest : PHAssetCollectionChangeRequest =
                    PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                self.placeholder = createAlbumRequest.placeholderForCreatedAssetCollection
            }, completionHandler: { success, error in
                if success,
                    let ph = self.placeholder {
                    let collectionFetchResult = PHAssetCollection.fetchAssetCollections(
                        withLocalIdentifiers: [ph.localIdentifier], options: nil)
                    print(collectionFetchResult)
                    self.albumAsset = collectionFetchResult.firstObject
                    DispatchQueue.main.async {
                        self.openInstagram()
                    }
                }
            })
        }
    }
    
    
    
    @IBAction func save(_ sender: Any) {
        
        if !self.sampleImageView.isHidden {
            guard let image = self.sampleImageView.image else {
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(image:didFinishSavingWithError:contextInfo:)), nil)

            
        } else {
            guard let url = self.videoUrl else {
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { saved, error in
                if saved {
                    let alertController = UIAlertController(title: "Your video was successfully saved to camera roll.", message: nil, preferredStyle: .actionSheet)
                    let defaultAction = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
                    alertController.addAction(defaultAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
        
        
        
    }
    
    @objc func image(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo:UnsafePointer<Void>) {
        guard error == nil else {
            //Error saving image
            return
        }
        let alertController = UIAlertController(title: "Your Image was successfully saved", message: nil, preferredStyle: .actionSheet)
        let defaultAction = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
        alertController.addAction(defaultAction)
        self.present(alertController, animated: true, completion: {
            
        })
        //Image saved successfully
    }
    
    fileprivate func openInstagram(){
        
        guard let __album = self.albumAsset else {return}
        if self.sampleImageView.isHidden{
            guard let _vid_url = videoUrl else {
                return
            }
            if let _ = self.videoAsset {
                self.openInstagramShare()
                return
            }
            PHPhotoLibrary.shared().performChanges({
                
                guard let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: _vid_url) else {
                    return
                }
                let assetPlaceholder = assetRequest.placeholderForCreatedAsset
                let photosAsset = PHAsset.fetchAssets(in: __album, options: nil)
                let albumChangeRequest = PHAssetCollectionChangeRequest(
                    for: __album, assets: photosAsset)
                albumChangeRequest!.addAssets([assetPlaceholder] as NSFastEnumeration)
            }) { saved, error in
                if saved {
                    let fetchOptions = PHFetchOptions()
//                    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                    
                    // After uploading we fetch the PHAsset for most recent video and then get its current location url
                    fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
                    let fetchResult = PHAsset.fetchAssets(in: __album, options: fetchOptions)
                    guard let _asset = fetchResult.lastObject else {return}
                    self.videoAsset = _asset
                    self.openInstagramShare()
//                    PHImageManager().requestAVAsset(forVideo: fetchResult!, options: nil, resultHandler: { (avurlAsset, audioMix, dict) in
//                        let newObj = avurlAsset as! AVURLAsset
//                        print(newObj.url)
//                        // This is the URL we need now to access the video from gallery directly.
//                    })
                }
            }
            return
        }
        if let image = self.sampleImageView.image {
            if let _ = self.photoAsset {
                self.openInstagramShare()
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let assetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                let assetPlaceholder = assetRequest.placeholderForCreatedAsset
                let photosAsset = PHAsset.fetchAssets(in: __album, options: nil)
                let albumChangeRequest = PHAssetCollectionChangeRequest(
                    for: __album, assets: photosAsset)
                albumChangeRequest!.addAssets([assetPlaceholder!] as NSFastEnumeration)
                
                
            }, completionHandler: { success, error in
                print("added image to album")
                let fetchOptions = PHFetchOptions()
                let desc = NSSortDescriptor.init(key: "creationDate", ascending: true)
                fetchOptions.sortDescriptors = [desc]
                
                let fetchResult = PHAsset.fetchAssets(in: __album, options: fetchOptions)
                guard let _asset = fetchResult.lastObject else {return}
                self.photoAsset = _asset
                self.openInstagramShare()
            })
        }
    }
    
    fileprivate func openInstagramShare(){
        DispatchQueue.main.async {
            if let __asset = self.sampleImageView.isHidden ? self.videoAsset : self.photoAsset  {
                let url_location = "instagram://library?LocalIdentifier=\(__asset.localIdentifier)"
                guard let url = URL(string: url_location) else {return}
                DispatchQueue.main.async {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.openURL(url)
                    }
                }
            }
        }
    }
    
    
    public func shareOnFB(shareImage image:AnyObject, withAppName app:String) {
        
        
        guard let appUrl = URL.init(string: "\(app)://app") else {return}
        let (appName, serviceType) = app.elementsEqual("fb") ? ("Facebook",SLServiceTypeFacebook) : ("Twitter",SLServiceTypeTwitter)
        if UIApplication.shared.canOpenURL(appUrl){
            guard let socialViewController = SLComposeViewController(forServiceType: serviceType) else {return}
//            socialViewController.setInitialText("#LIVE_VIDEO")
            if image is UIImage {
                socialViewController.add(image as? UIImage)
            }
            
            socialViewController.completionHandler = { (result:SLComposeViewControllerResult) -> Void in
                switch result {
                    
                case .cancelled:
                    
                    let msg = "Your \(appName) sharing aborted! Try again later."
                    print("Cancelled")
                    self.showAlert(Msg: msg, Icon: "app_icon", Loading: false)
                case .done:
                    
                    let msg = "Your image will be appeared on '\(appName)' soon! It may take some time. Thank you!"
                    self.showAlert(Msg: msg, Icon: "app_icon", Loading: false)
                }
            }
            self.present(socialViewController, animated: true) {
                
            }
        } else {
            let msg = "Your '\(appName)' sharing task is aborted! We are unable to locate your '\(appName)' app! please, Install & Login to the app. Thank you!"
            self.showAlert(Msg: msg, Icon: "app_icon", Loading: false)
            
        }
        
    }
    func showAlert(Msg msg:String, Icon icon:String? = nil,
                   Loading isLoading:Bool = true){
        DispatchQueue.main.async {
            
            let alert = UIAlertController(title: "Sharing...", message: msg, preferredStyle: UIAlertControllerStyle.actionSheet)
            if let pref = alert.popoverPresentationController {
                pref.permittedArrowDirections = []
                pref.sourceView?.frame = CGRect(x: self.view.frame.midX, y: self.view.frame.midY, width: 0, height: 0)
                
            }
            alert.addAction(UIAlertAction(title: "DISMISS", style: UIAlertActionStyle.default, handler: { (_action) in
                
            }))
            self.present(alert, animated: true, completion: {
                
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
        self.photoAsset = nil
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

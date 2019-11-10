//
//  PhotoCollectionViewController.swift
//  LivePreview
//
//  Created by David Rothschild on 1/1/17.
//  Copyright © 2017 Dave Rothschild. All rights reserved.
//

import UIKit
import Photos

private let reuseIdentifier = "Cell"

class PhotoCollectionViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    var assetsFetchREsults:PHFetchResult<PHAsset>?
    var accessGranted = false
    var requested = true
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        PHPhotoLibrary.requestAuthorization { (status:PHAuthorizationStatus) in
            switch status {
            case .authorized:
                self.requested = false
                self.accessGranted = true
                self.fetchPhotos()
            default:
                self.requested = false
                DispatchQueue.main.async {
                    self.showNowPhotoAccessAlert()
                    self.collectionView?.reloadData()
                }
            }
        }
    }
    
    func fetchPhotos() {
        
        let sortDescriptor = NSSortDescriptor(key: "creationDate", ascending: true)
        let predicate = NSPredicate(format: "(mediaSubtype & %d) != 0", PHAssetMediaSubtype.photoLive.rawValue)
        
        let options = PHFetchOptions()
        
        options.sortDescriptors = [sortDescriptor]
        options.predicate = predicate
        
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.assetsFetchREsults = PHAsset.fetchAssets(with: options)
            DispatchQueue.main.async {
                if self.assetsFetchREsults?.count == 0  {
                    self.requested = false
                }
                self.collectionView?.reloadData()
            }
        }
    }
    
    func showNowPhotoAccessAlert() {
        let alert = UIAlertController(title: "Photo Access Permission Require",
                                      message: "Please! Give access to your Photos for loading Live Photos preview and saving images and videos to camera roll.",
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Settings", style: .default, handler: { (action:UIAlertAction) in
            let url = URL(string: UIApplicationOpenSettingsURLString)
            UIApplication.shared.open(url!, options:["":""], completionHandler: nil)
            return
        }))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: UICollectionViewDataSource
    
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if self.requested {
            return 0
        }
        if !self.accessGranted
            || assetsFetchREsults?.count == 0 {
            return 1
        }
        if let numberOfItems = assetsFetchREsults?.count {
            return numberOfItems
        } else {
            return 0
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        if !self.accessGranted || assetsFetchREsults?.count == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AccessCell", for: indexPath)
            if let _title = cell.viewWithTag(1111) as? UILabel {
                _title.text = !self.accessGranted ? "Allow access to photos" : "No Live Photos found!"
            }
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as! PhotoCollectionViewCell
        
        if let asset = assetsFetchREsults?[indexPath.item] {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            
            let targetSize = CGSize(width: 100, height: 100)
            
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill,
                                                  options: options, resultHandler: { (image:UIImage?, info:[AnyHashable : Any]?) in
                                                    cell.photoImageView.image = image
            })
            
        }
        
        return cell
    }
    
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if !self.accessGranted{
            let url = URL(string: UIApplicationOpenSettingsURLString)
            UIApplication.shared.open(url!, options:["":""], completionHandler: nil)
        }
    }
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let indexPath = collectionView?.indexPathsForSelectedItems?.first {
            let photoVC = segue.destination as! LivePhotoCollectionViewController
            photoVC.livePhotoAsset = assetsFetchREsults![indexPath.item]
        }
    }
    
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if !self.accessGranted || assetsFetchREsults?.count == 0 {
            return CGSize(width: UIScreen.main.bounds.width - 50, height: self.view.bounds.height - 140)
        }
        
        return CGSize(width: 100, height: 100)
    }
}


//
//  ViewModel.swift
//  Tidy iOS
//
//  Created by Chris Danford on 2/19/19.
//  Copyright © 2019 Chris Danford. All rights reserved.
//

import UIKit

class ViewModel {
    // MARK: Grid
    struct Grid {
        var sections: GridSection
    }
    struct DuplicatesSectionHeader {
        var numColumnPairs: Int
    }
    struct TranscodeSectionHeader {
        var spaceToRecover: String
        //var statusHeading: String
        var status: String
        var showActivityIndicator: Bool

        init(readySpaceToRecover: UInt64, estimatedEventualSavingsBytes: UInt64, scanningStatus: TranscodeManager.ScanningStatus) {
            self.spaceToRecover = "\(readySpaceToRecover.formattedCompactByteString) of ~\(estimatedEventualSavingsBytes.formattedCompactByteString)"
            self.status = scanningStatus.friendlyStatus
            self.showActivityIndicator = scanningStatus.showActivityIndiciator
        }
    }
    enum SectionHeader {
        case transcode(TranscodeSectionHeader)
        case duplicates(DuplicatesSectionHeader)
    }
    struct GridSection {
        var sectionHeader: SectionHeader?
        var cells: [Cell]
    }
    enum Cell : Hashable {
        case instructions(InstructionsCell.Model)
        case asset(AssetGridView.Model)

        public func hash(into hasher: inout Hasher) {
            switch self {
            case .asset(let a):
                hasher.combine(a)
            case .instructions(let a):
                hasher.combine(a)
            }
        }
        static func == (lhs: Cell, rhs: Cell) -> Bool {
            switch (lhs, rhs) {
            case let (.instructions(l), .instructions(r)): return l == r
            case let (.asset(l), .asset(r)): return l == r
            case (.instructions, _),
                 (.asset, _): return false
            }
        }
    }

    // MARK: Table
    struct Table {
        var sections: [TableSection]

        static func empty() -> Table {
            return Table(sections: [])
        }
    }
    struct TableSection {
        var header: Row?
        var rows: [Row]
    }
    enum Row {
        case sizes
        case header
        case exactPhotos
        case exactVideos
        case inexactVideos
        case upgradeCompression
        case largeFiles
        case clearRecentlyDeleted
        case about
        
        func update(cell: UITableViewCell, state: AppState) {
            switch self {
            case .sizes:
                let specialCell = cell as! StatusTableViewCell
                specialCell.set(photosSizes: state.sizes)
            case .header:
                break
            case .exactPhotos:
                let specialCell = cell as! FeatureTableViewCell
                updateFeatureCell(cell: specialCell, briefStatus: state.duplicates.photosExact.briefStatus)
            case .exactVideos:
                let specialCell = cell as! FeatureTableViewCell
                updateFeatureCell(cell: specialCell, briefStatus: state.duplicates.videosExact.briefStatus)
            case .inexactVideos:
                let specialCell = cell as! FeatureTableViewCell
                updateFeatureCell(cell: specialCell, briefStatus: state.duplicates.videosInexact.briefStatus)
            case .upgradeCompression:
                let specialCell = cell as! FeatureTableViewCell
                updateFeatureCell(cell: specialCell, briefStatus: state.transcode.briefStatus)
            case .largeFiles:
                let specialCell = cell as! FeatureTableViewCell
                updateFeatureCell(cell: specialCell, briefStatus: state.largeFiles.briefStatus)
            case .clearRecentlyDeleted:
                let specialCell = cell as! FeatureTableViewCell
                updateFeatureCell(cell: specialCell, briefStatus: state.recentlyDeleted.briefStatus)
            case .about:
                let aboutInfo = About.info(state: state)
                cell.textLabel?.text = aboutInfo.inlineTitle
                cell.detailTextLabel?.text = aboutInfo.message
            }
        }

        func updateFeatureCell(cell: FeatureTableViewCell, briefStatus: BriefStatus) {
            updateCellAccessory(cell: cell, briefStatus: briefStatus)
        }
        
        func updateCellAccessory(cell: UITableViewCell, briefStatus: BriefStatus) {
            let badgeMessage = briefStatus.badgeMessage
            if briefStatus.isScanning || badgeMessage != nil {
                // Re-use the existing ActivityAndBadge, if any.
                let activityAndBadge = (cell.accessoryView as? ActivityAndBadge) ?? ActivityAndBadge()
                
                cell.accessoryView = nil
                
                activityAndBadge.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
                activityAndBadge.set(showActivity: briefStatus.isScanning, badgeMessage: badgeMessage)
                
                // Show label in accessory view and remove disclosure
                cell.accessoryView = activityAndBadge
                cell.accessoryType = .none
            } else {
                cell.accessoryView = nil
                cell.accessoryType = .disclosureIndicator
            }
        }

        func updateAboutCell(cell: UITableViewCell, state: AppState) {
            let aboutInfo = About.info(state: state)
            cell.textLabel?.text = aboutInfo.inlineTitle
            cell.detailTextLabel?.text = aboutInfo.message
        }

        var height: CGFloat {
            switch self {
            case .sizes:
                return 180
            case .header:
                return 25
            case .about:
                return 100
            default:
                return 40
            }
        }
        
        enum ViewControllerAction {
            case none
            case push(UIViewController)
            case present(UIViewController, Bool)
        }
        
        func selectionAction() -> ViewControllerAction {
            switch self {
            case .exactPhotos, .exactVideos, .inexactVideos:
                func duplicateGroupsFor(state: AppState) -> Duplicates.Groups {
                    switch self {
                    case .exactPhotos:
                        return state.duplicates.photosExact
                    case .exactVideos:
                        return state.duplicates.videosExact
                    case .inexactVideos:
                        return state.duplicates.videosInexact
                    default:
                        fatalError()
                    }
                }
                
                let title: String
                switch self {
                case .exactPhotos:
                    title = "Duplicate Photos"
                case .exactVideos:
                    title = "Duplicate Videos"
                case .inexactVideos:
                    title = "Resized Copies"
                default:
                    fatalError()
                }

                var instructions: String
                switch self {
                case .exactPhotos, .exactVideos:
                    instructions = "The following have identical metadata and contents. We'll keep one and delete the rest."
                case .inexactVideos:
                    instructions = "The have have identical creation dates, durations, and near-identical thumbnails. We'll keep the highest quality version."
                default:
                    fatalError()
                }
                let learnMoreText = " If the file to be deleted is favorited or part of an album, those properties will be transferred to the kept file."


                let showModifiedDate: Bool
                switch self {
                case .exactPhotos, .exactVideos:
                    showModifiedDate = false
                case .inexactVideos:
                    showModifiedDate = true
                default:
                    fatalError()
                }

                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "duplicatesViewController") as! DuplicatesViewController
                let gridDataSource = GridDataSource(
                    title: title,
                    forceEvenColumnCount: true,
                    viewModels: { state in
                        func viewModels(duplicateGroups: Duplicates.Groups) -> [ViewModel.Cell] {
                            let gridViewModels = duplicateGroups.groups.flatMap({ (duplicateGroup) -> [AssetGridView.Model] in
                                let toKeepAssetModel = AssetGridView.AssetModel(asset: duplicateGroup.toKeep)
                                let toKeepFormatteSizeBytes = AssetGridView.Model.formattedCompactByteString(assetModel: toKeepAssetModel)
                                return duplicateGroup.toDelete.flatMap({ (asset) -> [AssetGridView.Model] in
                                    let toDeleteAssetModel = AssetGridView.AssetModel(asset: asset)
                                    let toDeleteFormatteSizeBytes = AssetGridView.Model.formattedCompactByteString(assetModel: toDeleteAssetModel)
                                    let showVerboseSizeBytes = toKeepFormatteSizeBytes == toDeleteFormatteSizeBytes
                                    let toKeep = AssetGridView.Model(assetModel: toKeepAssetModel, showDeleteIcon: false, showVerboseSizeBytes: showVerboseSizeBytes, showModifiedDate: showModifiedDate, showSavingsPercentage: false, operationProgress: nil)
                                    let toDelete = AssetGridView.Model(assetModel: toDeleteAssetModel, showDeleteIcon: true, showVerboseSizeBytes: showVerboseSizeBytes, showModifiedDate: showModifiedDate, showSavingsPercentage: false, operationProgress: nil)
                                    return [toKeep, toDelete]
                                })
                            })
                            return gridViewModels.map({ (gridViewModel) -> ViewModel.Cell in
                                ViewModel.Cell.asset(gridViewModel)
                            })
                        }
                        let assetCells = viewModels(duplicateGroups: duplicateGroupsFor(state: state))
                        let cells = assetCells.count > 0 ? assetCells : [ViewModel.Cell.instructions(.init(text: "No Duplicates Found", learnMore: nil, style: .emptyPlaceholder))]
                        
                        let instructionsCell = ViewModel.Cell.instructions(.init(text: instructions, learnMore: learnMoreText, style: .instructions))
                        let sectionHeader = ViewModel.SectionHeader.duplicates(ViewModel.DuplicatesSectionHeader(numColumnPairs: 2))
                        return [
                            ViewModel.GridSection(sectionHeader: nil, cells: [instructionsCell]),
                            ViewModel.GridSection(sectionHeader: sectionHeader, cells: cells),
                        ]
                    },
                    applyActionProgressMessage: "Deleting",
                    primaryButton: { state in
                        let duplicateGroups = duplicateGroupsFor(state: state)
                        let formattedCount = duplicateGroups.numAssetsToDelete.formattedDecimalString
                        let buttonState = GridDataSource.Button(isEnabled: duplicateGroups.groups.count > 0, labelText: "Apply \(formattedCount) Deletes", spaceToRecoverBytes: duplicateGroups.bytesToDelete, applyAction: { state, callback in
                            let duplicateGroups = duplicateGroupsFor(state: state)
                            
                            let modifiedDuplicateGroups = duplicateGroups
                            
                            let diff = DuplicatesDiff.createDiff(duplicateGroups: modifiedDuplicateGroups)
                            DuplicatesDiff.applyDiff(diff: diff) { result in
                                switch result {
                                case .success(let stats):
                                    AppManager.instance.appliedDeletedDuplicates(stats: stats)
                                    callback(.result(.success))
                                case .cancelledOrError(let error):
                                    callback(.result(.cancelledOrError(error)))
                                }
                            }
                        })
                        return buttonState
                    }
                )
                vc.set(gridDataSource: gridDataSource)
                return .push(vc)
            case .upgradeCompression:
                let instructions = "The following videos can be made smaller by converting to 'High Efficiency' compression. This process is slow because the original quality video is downloaded for conversion."
                let learnMoreText = "We'll only convert if the file size is reduced by 5% or more."
                
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "duplicatesViewController") as! DuplicatesViewController
                let gridDataSource = GridDataSource(
                    title: "Upgrade Compression",
                    forceEvenColumnCount: false,
                    viewModels: { state in
                        let viewModels1 = state.transcode.beingTranscoded.map({ (beingTranscoded) -> AssetGridView.Model in
                            return AssetGridView.Model(assetModel: .init(asset: beingTranscoded.asset), showDeleteIcon: false, showVerboseSizeBytes: false, showModifiedDate: false, showSavingsPercentage: true, operationProgress: beingTranscoded.operationProgress)
                        })
                        let viewModels2 = state.transcode.transcodingComplete.filter({$0.transcodeStatsCached?.shouldApplyTranscode ?? false}).map({ (asset) -> AssetGridView.Model in
                            return AssetGridView.Model(assetModel: .init(asset: asset), showDeleteIcon: false, showVerboseSizeBytes: false, showModifiedDate: false, showSavingsPercentage: true, operationProgress: nil)
                        })
                        
                        let modelCells = (viewModels1 + viewModels2).map({ ViewModel.Cell.asset($0) })
                        let cells = modelCells.count > 0 ? modelCells : [ViewModel.Cell.instructions(.init(text: "No Upgrades Available", learnMore: nil, style: .emptyPlaceholder))]

                        let instructionsCell = ViewModel.Cell.instructions(.init(text: instructions, learnMore: learnMoreText, style: .instructions))
                        let sectionHeader = SectionHeader.transcode(.init(readySpaceToRecover: state.transcode.briefStatus.readySavingsBytes,
                                                                          estimatedEventualSavingsBytes: state.transcode.briefStatus.estimatedEventualSavingsBytes ?? 0,
                                                                          scanningStatus: state.transcode.transcodeManagerScanningStatus))
                        return [
                            ViewModel.GridSection(sectionHeader: nil, cells: [instructionsCell]),
                            ViewModel.GridSection(sectionHeader: sectionHeader, cells: cells),
                        ]
                    },
                    applyActionProgressMessage: "Replacing",
                    primaryButton: {state in
                        let assets = state.transcode.transcodingToApply
                        let buttonState = GridDataSource.Button(isEnabled: (assets.count > 0), labelText: "Replace \(assets.count.formattedDecimalString) with Upgrades", spaceToRecoverBytes: state.transcode.briefStatus.readySavingsBytes, applyAction: {state, callback in
                            let assetsToReplace = state.transcode.transcodingToApply
                            
                            PHAssetReplace.replaceWithTranscoded(assets: assetsToReplace, callback: { progressOrResult in
                                switch progressOrResult {
                                case .progress(let progress):
                                    switch progress {
                                    case .appliedSavings(let savingsStats):
                                        AppManager.instance.appliedTranscode(stats: savingsStats)
                                    case .preparingBatchOfSize(let batchSize):
                                        callback(.progress("Replacing \(batchSize.formattedDecimalString)"))
                                    }
                                case .result(let result):
                                    switch result {
                                    case .success:
                                        callback(.result(.success))
                                    case .cancelledOrError(let error):
                                        callback(.result(.cancelledOrError(error)))
                                    }
                                }
                            })
                        })
                        return buttonState
                    }
                )
                vc.set(gridDataSource: gridDataSource)
                return .push(vc)
            case .largeFiles:
                let instructions = "Review large files and delete any that are no longer needed."

                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "duplicatesViewController") as! DuplicatesViewController
                let gridDataSource = GridDataSource(
                    title: "Large Files",
                    forceEvenColumnCount: false,
                    viewModels: { state in
                        let assets = state.largeFiles.sortedAssets.map({ asset in
                            return AssetGridView.Model(assetModel: .init(asset: asset), showDeleteIcon: false, showVerboseSizeBytes: false, showModifiedDate: false, showSavingsPercentage: true, operationProgress: nil)
                        })
                        
                        let modelCells = assets.map({ ViewModel.Cell.asset($0) })
                        let cells = modelCells.count > 0 ? modelCells : [ViewModel.Cell.instructions(.init(text: "No Photos or Videos", learnMore: nil, style: .emptyPlaceholder))]
                        
                        let instructionsCell = ViewModel.Cell.instructions(.init(text: instructions, learnMore: nil, style: .instructions))
                        return [
                            ViewModel.GridSection(sectionHeader: nil, cells: [instructionsCell]),
                            ViewModel.GridSection(sectionHeader: nil, cells: cells),
                        ]
                    },
                    applyActionProgressMessage: "Replacing",
                    primaryButton: { state in nil }
                )
                vc.set(gridDataSource: gridDataSource)
                return .push(vc)
            case .clearRecentlyDeleted:
                let title = "Recently Deleted photos can only be emptied from the Photos app"
                let message = "Navigate to the album named 'Recently Deleted' then delete all items to reclaim this space in your iCloud quota."
                let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                let action1 = UIAlertAction(title: "Continue to Photos", style: .default) { (action:UIAlertAction) in
                    UIApplication.shared.open(URL(string:"photos-redirect://")!)
                }
                let action2 = UIAlertAction(title: "Cancel", style: .default) { (action:UIAlertAction) in
                }
                alertController.addAction(action1)
                alertController.addAction(action2)
                return .present(alertController, false)
            case .about:
                let aboutInfo = About.info(state: mainStore.state)
                let alertController = UIAlertController(title: aboutInfo.alertTitle, message: aboutInfo.message, preferredStyle: .alert)
                let action1 = UIAlertAction(title: "Leave a Rating", style: .default) { (action:UIAlertAction) in
                    let appId = "id1147613120"
                    let url = URL(string: "itms-apps://itunes.apple.com/app/" + appId)!
                    //SKStoreReviewController.requestReview()
                    UIApplication.shared.open(url)
                }
                let action2 = UIAlertAction(title: "PhotoTidy Open-Source", style: .default) { (action:UIAlertAction) in
                    let url = URL(string: "https://github.com/chrisdanford")!
                    UIApplication.shared.open(url)
                }
                let action3 = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction) in }
                alertController.addAction(action1)
                alertController.addAction(action2)
                alertController.addAction(action3)
                return .present(alertController, aboutInfo.showLeaveARating)
            case .header, .sizes:
                return .none
            }
        }
        
        func loadCell(cell: UITableViewCell, state: AppState) {
            switch self {
            case .sizes:
                let statusCell = cell as! StatusTableViewCell
                
                statusCell.set(photosSizes: mainStore.state.sizes)
                //statusCell.textLabel!.text = NSLocalizedString("Status", comment: "")
                //cell.detailTextLabel!.text = NSLocalizedString("Reclaim iCloud space by clearing out Recently Deleted items.", comment: "")
                //cell.animate()
                statusCell.set(photosSizes: state.sizes)
            case .header:
                cell.textLabel!.text = NSLocalizedString("Clear Some Space", comment: "")
            case .exactPhotos, .exactVideos, .inexactVideos, .upgradeCompression, .clearRecentlyDeleted, .largeFiles:
                let title: String
                let image: UIImage
                let briefStatus: BriefStatus
                switch self {
                case .exactPhotos:
                    title = NSLocalizedString("Duplicate Photos", comment: "")
                    image = UIImage(named: "duplicatePhoto")!
                    briefStatus = state.duplicates.photosExact.briefStatus
                case .exactVideos:
                    title = NSLocalizedString("Duplicate Videos", comment: "")
                    image = UIImage(named: "duplicateVideo")!
                    briefStatus = state.duplicates.videosExact.briefStatus
                case .inexactVideos:
                    title = NSLocalizedString("Resized Copies", comment: "")
                    image = UIImage(named: "lowQuality")!
                    briefStatus = state.duplicates.videosInexact.briefStatus
                case .upgradeCompression:
                    title = NSLocalizedString("Upgrade Compression", comment: "")
                    image = UIImage(named: "compress")!
                    briefStatus = state.transcode.briefStatus
                case .largeFiles:
                    title = NSLocalizedString("Large Files", comment: "")
                    image = UIImage(named: "largeFile")!
                    briefStatus = BriefStatus.empty()
                case .clearRecentlyDeleted:
                    title = NSLocalizedString("Clear Recently Deleted", comment: "")
                    image = UIImage(named: "trash")!
                    briefStatus = state.recentlyDeleted.briefStatus
                default:
                    title = ""
                    image = UIImage(named: "trash")!
                    briefStatus = .empty()
                }
                
                let specializedCell = cell as! FeatureTableViewCell
                specializedCell.textLabel!.text = title
                specializedCell.detailTextLabel!.text = ""
                //cell.detailTextLabel!.text = subTitle
                specializedCell.imageView!.image = image
                specializedCell.imageView!.tintColor = UIColor.red
                
                // The selection animation is messing with the background color of the cell accessory.
                // Try to find a robust way of fixing this.
                //specializedCell.selectionStyle = .none
                
                self.updateFeatureCell(cell: specializedCell, briefStatus: briefStatus)
            case .about:
                self.updateAboutCell(cell: cell, state: state)
            }
        }
    }
}

struct GridDataSource {
    var title: String
    var forceEvenColumnCount: Bool
    var viewModels: (AppState) -> [ViewModel.GridSection]
    var applyActionProgressMessage: String

    struct Button {
        var isEnabled: Bool
        var labelText: String
        var spaceToRecoverBytes: UInt64
        var applyAction: (AppState, @escaping (ProgressOrResult) -> ()) -> ()
    }
    
    var primaryButton: (AppState) -> Button?
    
    enum Result {
        case success
        case cancelledOrError(Error)  // PhotosKit doesn't surface the difference between cancellation and error.
    }
    enum ProgressOrResult {
        case progress(String)
        case result(Result)
    }

    static func empty() -> GridDataSource {
        return GridDataSource(title: "",
                              forceEvenColumnCount: false,
                              viewModels: { state in return [] },
                              applyActionProgressMessage: "foo",
                              primaryButton: { state in nil })
    }
}

//
//  ViewController.swift
//  videohelper
//
//  Created by Preet Minhas on 29/06/22.
//

import Cocoa
import UniformTypeIdentifiers
import UserNotifications

class MainViewController: NSViewController {

    @IBOutlet weak var fgTooltipView: NSImageView!
    @IBOutlet weak var bgTooltipView: NSImageView!
    
    @IBOutlet weak var imageView: NSImageView!
    
    @IBOutlet weak var showWatermarkCheckBox: NSButton!
    @IBOutlet weak var audioIndicatorIV: NSImageView!
    @IBOutlet weak var audioPathLabel: NSTextField!
    @IBOutlet weak var selectAudioButton : NSButton!
    
    @IBOutlet weak var fgNoneIW: ClickableImageView!
    @IBOutlet weak var fgCustomIW: ClickableImageView!
    @IBOutlet weak var fgLogoIW: ClickableImageView!
    
    @IBOutlet weak var bgCustomIW: ClickableImageView!
    @IBOutlet weak var bgWhiteIW: ClickableImageView!
    @IBOutlet weak var bgBlackIW: ClickableImageView!
    @IBOutlet weak var bgSelectColorIW: ClickableImageView!
    
    @IBOutlet weak var effectDurationLabel: NSTextField!
    @IBOutlet weak var effectTypePopupBtn: NSPopUpButton!
    @IBOutlet weak var durationSlider: NSSlider!
    
    @IBOutlet weak var generateButton: NSButton!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    
    //info label
    @IBOutlet weak var infoLabel: NSTextField!
    @IBOutlet weak var showMovieButton : NSButton!
    
    //color picker
    @IBOutlet weak var colorWell : NSColorWell!
    
    var filteredImageProvider: FilteredImageProvider?
    var updateTimer : Timer?
    
    var selectedAudioPath: String?
    //out dir is fixed to Movies (Sandbox restrictions)
    let outDirPath = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0].path
    
    var showWatermark = true {
        didSet {
            //save to defaults
            UserDefaults.standard.set(showWatermark, forKey: Key.showWatermark)
        }
    }
    
    var bgType = BgType.black {
        didSet {
            UserDefaults.standard.set(bgType.value, forKey: Key.bgType)
        }
    }
    
    var fgType = FgType.none {
        didSet {
            UserDefaults.standard.set(fgType.value, forKey: Key.fgType)
        }
    }
    
    var selectedEffect = FilteredImageProvider.EffectType.none {
        didSet {
            UserDefaults.standard.set(selectedEffect.value, forKey: Key.effectType)
        }
    }
    
    
    var effectDuration = 5 {
        didSet {
            //save this value to defaults for use next time
            UserDefaults.standard.set(effectDuration, forKey: Key.effectDuration)
        }
    }
    
    
    func loadLastSessionDefaults() {
        effectDuration =  UserDefaults.standard.integer(forKey: Key.effectDuration)
        if effectDuration == 0 {
            effectDuration = 5
        }
        
        let storedEffectType = FilteredImageProvider.EffectType.fromValue(UserDefaults.standard.integer(forKey: Key.effectType))
        //set the duration in the self effect type (ignore the stored associated value as we get the duration from another key)
        switch storedEffectType {
        case .none:
            self.selectedEffect = .none
        case .vintage(_):
            self.selectedEffect = .vintage(effectDuration)
        case .negative(_):
            self.selectedEffect = .negative(effectDuration)
        case .radialBlur(_):
            selectedEffect = .radialBlur(effectDuration)
        case .pixellate(_):
            selectedEffect = .pixellate(effectDuration)
        case .exposure(_):
            selectedEffect = .exposure(effectDuration)
        case .hueAdjust(_):
            selectedEffect = .hueAdjust(effectDuration)
        case .noise(_):
            selectedEffect = .noise(effectDuration)
        }
        
        //load fg type
        let storedFgType = FgType.fromValue(UserDefaults.standard.integer(forKey: Key.fgType))
        switch storedFgType {
        case .none:
            self.fgType = .none
        case .image(_):
            //try loading the last loaded image from temp dir. If it is available, good, else set to .none
            if let dest = lastForegroundUrl(), FileManager.default.fileExists(atPath: dest.path) {
                self.fgType = .image(dest.path)
            } else {
                self.fgType = .none
            }
            
        case .logo:
            self.fgType = .logo
        }
        
        //load bg type
        let storedBgType = BgType.fromValue(UserDefaults.standard.integer(forKey: Key.bgType))
        switch storedBgType {
        case .black:
            self.bgType = .black
        case .white:
            self.bgType = .white
        case .image(_):
            //try loading the last loaded image from temp dir. If it is available, good, else set to .black
            if let dest = lastBackgroundUrl(), FileManager.default.fileExists(atPath: dest.path) {
                self.bgType = .image(dest.path)
            } else {
                self.bgType = .black
            }
        case .customColor:
            self.bgType = .customColor
        }
        
        if Store.shared.isWatermarkIAPUnlocked() {
            showWatermark = UserDefaults.standard.bool(forKey: Key.showWatermark)
        } else {
            showWatermark = true
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fgTooltipView.toolTip = "For best results, please select a 1080x1080 square image"
        bgTooltipView.toolTip = "For best results, please select a 1920x1080 background image"
        //the color well remains hidden and its properties are accessed via method calls
        colorWell.isHidden = true
        
        loadLastSessionDefaults()
        
        progressIndicator.isHidden = true
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        
        hideVideoGeneratedInfo(true)
        
        setExclamation(to: audioIndicatorIV)
        audioPathLabel.stringValue = "Please select a WAV/MP3 file"
        
        //set bg values
        bgBlackIW.initLayer()
        bgWhiteIW.initLayer()
        bgCustomIW.initLayer()
        if let colorImage = NSImage(contentsOf: customColorImageUrl()) {
            bgSelectColorIW.image = colorImage
        }
        bgSelectColorIW.initLayer()
        bgBlackIW.clickHandler = self.bgBlackAction
        bgWhiteIW.clickHandler = self.bgWhiteAction
        bgCustomIW.clickHandler = self.bgCustomAction
        bgSelectColorIW.clickHandler = self.bgSampleAction
        updateBgUI()
        
        //set fg values
        fgNoneIW.initLayer()
        fgCustomIW.initLayer()
        fgLogoIW.initLayer()
        fgNoneIW.clickHandler = self.fgNoneAction
        fgCustomIW.clickHandler = self.fgCustomAction
        fgLogoIW.clickHandler = self.fgSampleAction
        updateFgUI()
        
        configureEffectPopup()
        
        showWatermarkCheckBox.state = showWatermark ? .on : .off
        
        //update image provider
        updateImageProvider()
        
        startPreview(true)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        //hide the color panel
        NSColorPanel.shared.close()
        colorWell.deactivate()
        
        //observe color changes to the well
        colorWell.addObserver(self, forKeyPath: "color",options: .new, context: nil)
        
        //become the window delegate to capture close event
        self.view.window?.delegate = self
    }
    
    override func viewDidDisappear() {
        super.viewDidDisappear()
        colorWell.removeObserver(self, forKeyPath: "color")
    }
    
    
    func customColorImageUrl() -> URL {
        let directory = NSTemporaryDirectory()
        let fileName = "color.jpg"
        let url = NSURL.fileURL(withPathComponents: [directory, fileName])!
        return url
    }
    
    var lastCustomColorImageWrite : TimeInterval = 0
    let colorImageWriteDebounce = 0.1 //seconds
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "color" {
            //debounce
            let currentTime = Date.timeIntervalSinceReferenceDate
            let elapsed = currentTime - lastCustomColorImageWrite
            print(elapsed)
            if elapsed < colorImageWriteDebounce {
                return
            }
            
            //get the color well's new color
            let newColor = colorWell.color
            //write the color image to disk
            let ciImage = CIImage(color: CIColor(color: newColor)!)
            let cropped = ciImage.cropped(to: CGRect(origin: .zero, size: CGSize(width: 1920, height: 1080)))
            let url = customColorImageUrl()
            if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) {
                let context = CIContext()
                try? context.writeJPEGRepresentation(of: cropped, to: url, colorSpace: colorSpace)
                lastCustomColorImageWrite = currentTime
            }
            
            bgType = .customColor
            updateBgUI()
            bgSelectColorIW.image = NSImage(contentsOf: url)
            updateImageProvider()
        }
    }
    
    //fire the timer 30 times per second to match video framerate and update the preview window
    func startPreview(_ start: Bool) {
        updateTimer?.invalidate()
        updateTimer = nil
        if start {
            updateTimer = Timer.scheduledTimer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
        }
    }
    
    
    func hideVideoGeneratedInfo(_ hide: Bool) {
        infoLabel.isHidden = hide
        showMovieButton.isHidden = hide
    }
    
    func configureEffectPopup() {
        effectTypePopupBtn.removeAllItems()

        effectTypePopupBtn.addItems(withTitles: ["None", "Vintage", "Pixellate", "Negative", "Exposure", "Hue Adjust", "Blur", "Noise"])
        
        durationSlider.intValue = Int32(effectDuration)
        
        //select item based on selected effect
        var selectedItemIndex = 0
        switch selectedEffect {
        case .none:
            selectedItemIndex = 0
        case .vintage(_):
            selectedItemIndex = 1
        case .negative( _):
            selectedItemIndex = 3
        case .radialBlur(_):
            selectedItemIndex = 6
        case .pixellate(_):
            selectedItemIndex = 2
        case .exposure(_):
            selectedItemIndex = 4
        case .hueAdjust(_):
            selectedItemIndex = 5
        case .noise(_):
            selectedItemIndex = 7
        }
        effectTypePopupBtn.selectItem(at: selectedItemIndex)

        effectDurationLabel.stringValue = "Effect Duration: \(effectDuration)s"
        
        durationSlider.isHidden = (selectedEffect == .none)
        effectDurationLabel.isHidden = durationSlider.isHidden
    }
    
    
    @IBAction func showMovieInFinder(_ sender: Any) {
        //open Finder
        if let videoPath = finalVideoPath {
            NSWorkspace.shared.activateFileViewerSelecting([videoPath])
        } else {
            showAlert("Unable to locate processed video file!")
        }
    }
    
    func updateBgUI() {
        switch bgType {
        case .black:
            bgBlackIW.highlight(true)
            bgWhiteIW.highlight(false)
            bgCustomIW.highlight(false)
            bgSelectColorIW.highlight(false)
        case .white:
            bgBlackIW.highlight(false)
            bgWhiteIW.highlight(true)
            bgCustomIW.highlight(false)
            bgSelectColorIW.highlight(false)
        case .image(_):
            bgBlackIW.highlight(false)
            bgWhiteIW.highlight(false)
            bgCustomIW.highlight(true)
            bgSelectColorIW.highlight(false)
        case .customColor:
            bgBlackIW.highlight(false)
            bgWhiteIW.highlight(false)
            bgCustomIW.highlight(false)
            bgSelectColorIW.highlight(true)
        }
    }
    
    func updateFgUI() {
        switch fgType {
        case .none:
            fgNoneIW.highlight(true)
            fgCustomIW.highlight(false)
            fgLogoIW.highlight(false)
        case .image(_):
            fgNoneIW.highlight(false)
            fgCustomIW.highlight(true)
            fgLogoIW.highlight(false)
        case .logo:
            fgNoneIW.highlight(false)
            fgCustomIW.highlight(false)
            fgLogoIW.highlight(true)
        }
    
    }
    
    func setExclamation(to:NSImageView) {
        to.image = NSImage(systemSymbolName: "exclamationmark.circle", accessibilityDescription: nil)
        to.contentTintColor = NSColor.systemRed
        to.symbolConfiguration = .init(scale: .medium)
    }
    
    func setTick(to: NSImageView) {
        to.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        to.contentTintColor = NSColor.systemGreen
        to.symbolConfiguration = .init(scale: .medium)
    }
    
    var frameCount = 0
    @objc func fireTimer() {
        guard let filteredImageProvider = filteredImageProvider else {
            imageView.image = nil
            return
        }
        //update the imageview
        if let ciImage = filteredImageProvider.generateCIImage(forFrame: frameCount) {
            let rep = NSCIImageRep(ciImage: ciImage)
            let nsImage = NSImage(size: rep.size)
            nsImage.addRepresentation(rep)
            imageView.image = nsImage
            frameCount += 1
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    func openDialog(title : String, allowedContentTypes:[UTType], onSelected: (String) -> Void) {
        let dialog = NSOpenPanel();

        dialog.title                   = title;
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = false;
        dialog.allowedContentTypes = allowedContentTypes;

        if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
            let result = dialog.url // Pathname of the file

            if (result != nil) {
                let path: String = result!.path
                onSelected(path)
            }
            
        }
    }

    @IBAction func selectAudioAction(_ sender: Any) {
        hideVideoGeneratedInfo(true)
        openDialog(title: "Select audio file", allowedContentTypes: [.audio]) { selectedPath in
            selectedAudioPath = selectedPath
            //show the last path only
            audioPathLabel.stringValue = selectedPath.components(separatedBy: "/").last!
            setTick(to: audioIndicatorIV)
        }
    }
    
    func getAppName() -> String {
        if let name = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String {
            return name
        }
        return "App"
    }
    
    func showAlert(_ msg: String) {
        let alert = NSAlert()
        alert.messageText = getAppName()
        alert.informativeText = msg
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    @IBAction func effectTypeChanged(_ sender: NSPopUpButton) {
        hideVideoGeneratedInfo(true)
        switch sender.titleOfSelectedItem {
        case "None":
            selectedEffect = .none
        case "Vintage":
            selectedEffect = .vintage(effectDuration)
        case "Pixellate":
            selectedEffect = .pixellate(effectDuration)
        case "Negative":
            selectedEffect = .negative(effectDuration)
        case "Exposure":
            selectedEffect = .exposure(effectDuration)
        case "Hue Adjust":
            selectedEffect = .hueAdjust(effectDuration)
        case "Blur":
            selectedEffect = .radialBlur(effectDuration)
        case "Noise":
            selectedEffect = .noise(effectDuration)
        default:
            selectedEffect = .none
        }
        durationSlider.isHidden = (selectedEffect == .none)
        effectDurationLabel.isHidden = durationSlider.isHidden
        
        updateImageProvider()
    }
    
    @IBAction func durationSliderChanged(_ sender: NSSlider) {
        hideVideoGeneratedInfo(true)
        effectDuration = sender.integerValue
        effectDurationLabel.stringValue = "Effect Duration: \(effectDuration)s"
        effectTypeChanged(effectTypePopupBtn)
    }
    
    @discardableResult
    func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    @IBAction func bgBlackAction(_ sender: Any) {
        bgType = .black
        updateBgUI()
        //generate(re-generate) image
        updateImageProvider()
    }
    
    @IBAction func bgWhiteAction(_ sender: Any) {
        bgType = .white
        updateBgUI()
        //generate(re-generate) image
        updateImageProvider()
    }
    
    func bgSampleAction(_ sender: Any) {
        colorWell.activate(true)
        bgType = .customColor
        updateBgUI()
        //generate(re-generate) image
        updateImageProvider()
    }
    
    @IBAction func bgCustomAction(_ sender: Any) {
        bgType = .image("")
        updateBgUI()
        openDialog(title: "Select Background Image", allowedContentTypes: [.image]) { selectedPath in
            if let image = NSImage(contentsOfFile: selectedPath) {
                let rep = image.representations[0]
                var finalPath = selectedPath
                if rep.pixelsWide != 1920 || rep.pixelsHigh != 1080 {
                    showAlert("For best results, please select an image with resolution 1920x1080")

                    //create resized image (preserve aspect ratio, fill width)
                    let resizedImage = image.resized(to: NSSize(width: 1920, height: 1080), preserveAspect: true)
                    //save to a temp location
                    let directory = NSTemporaryDirectory()
                    let fileName = NSUUID().uuidString + ".png"
                    let url = NSURL.fileURL(withPathComponents: [directory, fileName])!
                    if let cgImage = resizedImage?.asCGImage() {
                        writeCGImage(cgImage, to: url)
                        bgType = .image(url.path)
                        finalPath = url.path
                    } else {
                        bgType = .black
                    }
                } else {
                    bgType = .image(selectedPath)
                }
                
                //cpy to internal temp dir (so that we don't have to worry abt sandbox next time app opens)
                if let dest = lastBackgroundUrl() {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try? FileManager.default.removeItem(atPath: dest.path)
                    }
                    try? FileManager.default.copyItem(at: NSURL.fileURL(withPath:finalPath), to: dest)
                }
                
                updateBgUI()
                updateImageProvider()
            } else {
                showAlert("Invalid file!")
            }
        }
    }
    
    
    
    func lastForegroundUrl() -> URL? {
        return NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), "last-foreground.photo"])
    }
    
    func lastBackgroundUrl() -> URL? {
        return NSURL.fileURL(withPathComponents: [NSTemporaryDirectory(), "last-background.photo"])
    }
    
    func fgNoneAction(_ sender: Any) {
        fgType = .none
        updateFgUI()
        //generate(re-generate) image
        updateImageProvider()
    }
    
    func fgCustomAction(_ sender: Any) {
        fgType = .image("")
        updateFgUI()
        openDialog(title: "Select Foreground Image", allowedContentTypes: [.image]) { selectedPath in
            if let image = NSImage(contentsOfFile: selectedPath) {
                let rep = image.representations[0]
                if rep.pixelsWide != rep.pixelsHigh {
                    showAlert("For best results, please select an image with resolution 1080x1080")
                }
                
                //cpy to internal temp dir (so that we don't have to worry abt sandbox next time app opens)
                if let dest = lastForegroundUrl() {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try? FileManager.default.removeItem(atPath: dest.path)
                    }
                    try? FileManager.default.copyItem(at: NSURL.fileURL(withPath:selectedPath), to: dest)
                }
                
                //set foreground nonetheless
                fgType = .image(selectedPath)
                updateFgUI()
                updateImageProvider()
            } else {
                showAlert("Invalid file!")
            }
        }
    }
    
    func fgSampleAction(_ sender: Any) {
        fgType = .logo
        updateFgUI()
        updateImageProvider()
    }
    
    func updateImageProvider() {
        //create bg
        var bg : NSImage?
        switch bgType {
        case .black:
            bg = NSImage(named: "black-1920")
        case .white:
            bg = NSImage(named: "white-1920")
        case .image(let string):
            if !string.isEmpty {
                bg = NSImage(contentsOfFile: string)
            } else {
                bg = NSImage(named: "black-1920")
            }
        case .customColor:
            bg = NSImage(contentsOf: customColorImageUrl()) ?? NSImage(named: "black-1920")
        }
        
        
        var fg: NSImage?
        
        switch fgType {
        case .none:
            print("No fg")
        case .image(let string):
            if !string.isEmpty {
                fg = NSImage(contentsOfFile: string)
            }
        case .logo:
            fg = NSImage(named: "sample-fg")
        }
        guard let bg = bg else {
            return
        }

        
        var mergedImage : CGImage?
        if let fg = fg {
            mergedImage = mergeImages(bg: bg, fg: fg)
        } else {
            var rect = CGRect(origin: .zero, size: bg.size)
            mergedImage = bg.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
        
        //image ready, convert to ciimage
        if let mergedImage = mergedImage {
            var ciImage : CIImage
            //watermark decision
            if Store.shared.isWatermarkIAPUnlocked() && !showWatermark {
                //unlocked and user doesn't want watermark
                ciImage = CIImage(cgImage: mergedImage)
            } else {
                //still not purchased IAP, show watermark
                let watermarkedImage = addWatermark(bgCGImage: mergedImage) ?? mergedImage
                ciImage = CIImage(cgImage: watermarkedImage)
            }
            
            filteredImageProvider = FilteredImageProvider(image: ciImage, effectType: selectedEffect)
            //reset frame counter
            frameCount = 0
        } else {
            showAlert("Unable to create image!")
            filteredImageProvider = nil
        }
        
        
    }
    
    
    @IBAction func generateAction(_ sender: NSButton) {
        hideVideoGeneratedInfo(true)
        if let audioPath = selectedAudioPath, !outDirPath.isEmpty, !audioPath.isEmpty {
            generateVideo(audioPath: audioPath, outDirPath: outDirPath)
        } else {
            showAlert("Please select audio file")
        }
        
    }
    
    func enableUIInteraction(_ enable: Bool) {
        //enable/disable btns and preview
        startPreview(enable)
        generateButton.isEnabled = enable
        effectTypePopupBtn.isEnabled = enable
        durationSlider.isEnabled = enable
        
        selectAudioButton.isEnabled = enable
        
        bgBlackIW.isEnabled = enable
        bgWhiteIW.isEnabled = enable
        bgCustomIW.isEnabled = enable
        bgSelectColorIW.isEnabled = enable
        
        fgNoneIW.isEnabled = enable
        fgLogoIW.isEnabled = enable
        fgCustomIW.isEnabled = enable
        
        showWatermarkCheckBox.isEnabled = enable
    }
    
    var finalVideoPath: URL?
    func generateVideo(audioPath: String, outDirPath: String){
        if let filteredImageProvider = filteredImageProvider {
            let creator = VideoCreator()
            self.infoLabel.isHidden = false
            infoLabel.stringValue = "Processing..."
            do {
                enableUIInteraction(false)
                
                try creator.createVideo(pixelBufferProvider:filteredImageProvider, audioFilePath: audioPath,
                                        outDirPath: outDirPath) { isFinished, progress, videoPath in
                    print(isFinished, progress)
                    self.progressIndicator.isHidden = isFinished
                    self.progressIndicator.doubleValue = Double(progress)
                    self.infoLabel.stringValue = "Progress: \(Int(progress*100))%"
                    
                    
                    if isFinished {
                        if let videoPath = videoPath {
                            self.finalVideoPath = videoPath
                            self.showMovieInFinder(self.showMovieButton!)
                            
                            self.infoLabel.stringValue = "Video ready at ~/Movies/\(videoPath.lastPathComponent)"
                            self.hideVideoGeneratedInfo(false)
                            //show notification
                            self.showVideoReadyNotification(videoPath: "~/Movies/\(videoPath.lastPathComponent)")
                            
                        } else {
                            self.showAlert("Unable to create video!")
                        }
                        
                        self.enableUIInteraction(true)
                    }
                }
            } catch VideoCreatorError.runtimeError(let errMsg) {
                self.showAlert(errMsg)
                enableUIInteraction(true)
            } catch {
                self.showAlert(error.localizedDescription)
                enableUIInteraction(true)
            }
            
        } else {
            showAlert("Unable to access filtered image!")
        }
    }
    
    @IBAction func showWatermarkToggleAction(_ sender: NSButton) {
        if Store.shared.isWatermarkIAPUnlocked() {
            showWatermark = sender.state == .on ? true : false
            updateImageProvider()
        } else {
            //show alert and set the state back to on
            showAlert("Please upgrade to remove watermark")
            sender.state = .on
            //show IAP window
            showIAPWindow()
        }
    }
    
    
    private lazy var iapController: NSWindowController? = {
        return self.storyboard?.instantiateController(withIdentifier: "iapWindow") as? NSWindowController
    }()
    func showIAPWindow() {
        iapController?.showWindow(self)
    }
    
    
    //notification
    func showVideoReadyNotification(videoPath: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .provisional]) { granted, error in
            if let error = error {
                // Do nothing
                print(error)
                return
            }
            if granted {
                let content = UNMutableNotificationContent()
                content.title = "Video Ready!"
                content.body = "Your video is available at \(videoPath)"
                let req = UNNotificationRequest(identifier: UUID().uuidString,
                                                content: content,
                                                trigger: .none)
                center.add(req)
                
            }
        }

    }
}


extension MainViewController : NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        //check whether we are generating a video
        let isGeneratingVideo = !generateButton.isEnabled
        if isGeneratingVideo {
            //ask for confirmation before quitting
            let alert = NSAlert()
            alert.messageText = "Are you sure you want to quit?"
            alert.informativeText = "Video generation will stop and BeatVid will quit"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "No")
            alert.addButton(withTitle: "Yes, quit app")
            if alert.runModal() == .alertSecondButtonReturn {
                //pressed ok, quit app
                NSApp.terminate(self)
            } else {
                //don't close the window
                return false
            }
            return true
        } else {
            //not generting video, quit app without alert
            NSApp.terminate(self)
        }
        return true
    }
}

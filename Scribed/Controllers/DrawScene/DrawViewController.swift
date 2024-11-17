//
//  DrawViewController.swift
//  Jottre
//
//  Created by Anton Lorani on 16.01.21.
//

import UIKit
import PencilKit
import OSLog
import AVFoundation

class DrawViewController: UIViewController {
    
    private let sambaNovaViewModel = SambaNovaViewModel()
    private var currentAudioFileName: String?
    private var audioFileDidChange: Bool {
            return currentAudioFileName != node.codable?.audioFileName
        }
    
    // Add this property to track the current audio player view
    private var currentAudioPlayerView: AudioPlayerView?
    
    private var audioRecorder: AVAudioRecorder?
    private var isRecording = false {
        didSet {
            updateRecordButtonAppearance()
        }
    }
    // MARK: - Properties
    private var searchResultView: SearchResultView?
    private var isSearching = false
    
   
    internal var startTime: Date?
    internal var currentStrokeStartTime: Date?
    
    internal var viewedStrokeIndex: Int?
    internal var timedDrawing = TimedDrawing()
    
    var node: Node!
    
    var isUndoEnabled: Bool = false
    
    var modifiedCount: Int = 0
        
    var hasModifiedDrawing: Bool = false {
        didSet {
            reloadNavigationItems()
        }
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    // MARK: - Subviews
    
    var loadingView: LoadingView = {
        return LoadingView()
    }()
    
    
    
    var canvasView: TrackablePKCanvasView = {
        let canvasView = TrackablePKCanvasView()
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.drawingPolicy = .anyInput // Allow any input (finger, mouse, Pencil)
        return canvasView
    }()
    
    var toolPicker: PKToolPicker = {
        return PKToolPicker()
    }()
    
    var redoButton: UIBarButtonItem!
    
    var undoButton: UIBarButtonItem!
    
    private let buttonStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var recordButton: UIButton = {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: "record.circle"), for: .normal)
            button.tintColor = .red
            button.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
            return button
        }()

    
    // MARK: - Init
    
    init(node: Node) {
        super.init(nibName: nil, bundle: nil)
        self.node = node
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    // MARK: - Override methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupViews()
        setupDelegates()
        setupAudioPlayer()
        updateRecordButtonState()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let canvasScale = canvasView.bounds.width / node.codable!.width
        canvasView.minimumZoomScale = canvasScale
        canvasView.zoomScale = canvasScale
        
        updateContentSizeForDrawing()
        canvasView.contentOffset = CGPoint(x: 0, y: -canvasView.adjustedContentInset.top)
        
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        node.isOpened = true
        
        startTime = Date() // Start the timer

        
        guard let parent = parent, let window = parent.view.window, let windowScene = window.windowScene else { return }
        
        if let screenshotService = windowScene.screenshotService { screenshotService.delegate = self }
        
        windowScene.userActivity = node.openDetailUserActivity
        
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        view.window?.windowScene?.screenshotService?.delegate = nil
        view.window?.windowScene?.userActivity = nil
        
        node.isOpened = false
        
    }
    
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        
        view.backgroundColor = (traitCollection.userInterfaceStyle == UIUserInterfaceStyle.dark) ? .black : .white

    }
    
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        userActivity!.addUserInfoEntries(from: [ Node.NodeOpenDetailIdKey: node.url! ])
    }
    
    private var drawingButton: UIButton?
    private var viewingButton: UIButton?

    
    // MARK: - Methods
    func setupAudioPlayer() {
        // Check if we already have an audio player view set up
        if currentAudioPlayerView != nil {
            // If the audio URL matches the current one, don't recreate the player
            if let audioFileName = node.codable?.audioFileName,
                let currentURL = currentAudioPlayerView?.currentAudioURL,
                currentURL == getDocumentsDirectory().appendingPathComponent(audioFileName) {
                    return
            }
        }
        
        // Store current scroll position
        let currentOffset = canvasView.contentOffset
        
        // Remove existing audio player view if it exists
        currentAudioPlayerView?.removeFromSuperview()
            
        // Create and configure new audio player view
        let audioPlayerView = AudioPlayerView()
        audioPlayerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(audioPlayerView)
                    
        NSLayoutConstraint.activate([
            audioPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            audioPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            audioPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            audioPlayerView.heightAnchor.constraint(equalToConstant: 44)
        ])
                    
        if let audioFileName = node.codable?.audioFileName {
            let audioURL = getDocumentsDirectory().appendingPathComponent(audioFileName)
            audioPlayerView.loadAudio(url: audioURL)
            currentAudioFileName = audioFileName
        }
                
        // Store reference to current audio player view
        currentAudioPlayerView = audioPlayerView
                
        // Restore scroll position
        DispatchQueue.main.async {
            self.canvasView.setContentOffset(currentOffset, animated: false)
        }
    }
    
    
    func setupViews() {

        traitCollectionDidChange(traitCollection)
        
        view.backgroundColor = (traitCollection.userInterfaceStyle == UIUserInterfaceStyle.dark) ? .black : .white
        
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.title = node.name
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportDrawing))
        
        reloadNavigationItems()
        
        // Add canvas view
        view.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.topAnchor),
            canvasView.leftAnchor.constraint(equalTo: view.leftAnchor),
            canvasView.rightAnchor.constraint(equalTo: view.rightAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add loading view
        view.addSubview(loadingView)
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 120),
            loadingView.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        // Add button stack view
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.alignment = .fill
        buttonStackView.distribution = .equalSpacing
        buttonStackView.spacing = 8 // Adjust spacing between buttons
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false

        // Create the "Drawing" button with an image
        let drawingButton = UIButton(type: .system)
        let drawingImage = UIImage(systemName: "pencil.circle") // Use SF Symbols
        drawingButton.setImage(drawingImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        drawingButton.tintColor = .systemBlue // Default color

        // Adjust logo size
        drawingButton.imageView?.contentMode = .scaleAspectFit
        drawingButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5) // Add padding
        drawingButton.imageView?.translatesAutoresizingMaskIntoConstraints = false
        drawingButton.imageView?.heightAnchor.constraint(equalToConstant: 40).isActive = true // Set height
        drawingButton.imageView?.widthAnchor.constraint(equalToConstant: 40).isActive = true // Set width

        drawingButton.addTarget(self, action: #selector(setDrawingMode), for: .touchUpInside)

        // Create the "Viewing" button with an image
        let viewingButton = UIButton(type: .system)
        let viewingImage = UIImage(systemName: "eye.circle") // Use SF Symbols
        viewingButton.setImage(viewingImage?.withRenderingMode(.alwaysTemplate), for: .normal)
        viewingButton.tintColor = .systemBlue // Default color

        // Adjust logo size
        viewingButton.imageView?.contentMode = .scaleAspectFit
        viewingButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5) // Add padding
        viewingButton.imageView?.translatesAutoresizingMaskIntoConstraints = false
        viewingButton.imageView?.heightAnchor.constraint(equalToConstant: 40).isActive = true // Set height
        viewingButton.imageView?.widthAnchor.constraint(equalToConstant: 40).isActive = true // Set width

        viewingButton.addTarget(self, action: #selector(setViewingMode), for: .touchUpInside)
        
        let searchButton = UIButton(type: .system)
       let searchImage = UIImage(systemName: "magnifyingglass.circle")
       searchButton.setImage(searchImage?.withRenderingMode(.alwaysTemplate), for: .normal)
       searchButton.tintColor = .systemBlue
        
        searchButton.imageView?.contentMode = .scaleAspectFit
        searchButton.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)
        searchButton.imageView?.translatesAutoresizingMaskIntoConstraints = false
        searchButton.imageView?.heightAnchor.constraint(equalToConstant: 40).isActive = true
        searchButton.imageView?.widthAnchor.constraint(equalToConstant: 40).isActive = true

        searchButton.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)

        // Add the buttons to the stack view
        buttonStackView.addArrangedSubview(drawingButton)
        buttonStackView.addArrangedSubview(viewingButton)
        buttonStackView.addArrangedSubview(recordButton)
        buttonStackView.addArrangedSubview(searchButton)
        
        // Add the stack view to the main view
        view.addSubview(buttonStackView)

        // Position the stack view below the navigation bar
        NSLayoutConstraint.activate([
            buttonStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])

        // Store buttons as properties for state management
        self.drawingButton = drawingButton
        self.viewingButton = viewingButton
        setupAudioRecorder()
        updateRecordButtonAppearance()
        updateContentSizeForDrawing()
        
        setDrawingMode()
    }
    
    private func setupAudioRecorder() {
            let audioSession = AVAudioSession.sharedInstance()
            
            do {
                try audioSession.setCategory(.playAndRecord, mode: .default)
                try audioSession.setActive(true)
                
                // Request microphone permission
                audioSession.requestRecordPermission { [weak self] allowed in
                    DispatchQueue.main.async {
                        self?.recordButton.isEnabled = allowed
                        if allowed {
                            self?.updateRecordButtonAppearance()  // Update appearance after permission granted
                        }
                    }
                }
            } catch {
                print("Failed to set up audio session: \(error)")
                recordButton.isEnabled = false
            }
        }
    @objc private func searchButtonTapped() {
            let alertController = UIAlertController(
                title: "Search Text",
                message: "Enter a term to search for",
                preferredStyle: .alert
            )
            
            alertController.addTextField { textField in
                textField.placeholder = "Enter search term"
            }
            
            let searchAction = UIAlertAction(title: "Search", style: .default) { [weak self] _ in
                guard let searchTerm = alertController.textFields?.first?.text,
                      !searchTerm.isEmpty else { return }
                self?.performSearch(with: searchTerm)
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            
            alertController.addAction(searchAction)
            alertController.addAction(cancelAction)
            
            present(alertController, animated: true)
        }
        
    private func performSearch(with term: String) {
        // Perform the search
        sambaNovaViewModel.searchText = term
        sambaNovaViewModel.search()

        // Wait for results and display them
        // We will use a delay for demonstration purposes or to wait for async completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { // Assuming results will be ready after 1 second
            if !self.sambaNovaViewModel.results.isEmpty {
                self.displaySearchResults(self.sambaNovaViewModel.results)
            }
        }
    }
    
    private func displaySearchResults(_ results: String) {
        // Create an alert controller to display the results
        let alertController = UIAlertController(
            title: "Search Results",
            message: results,
            preferredStyle: .alert
        )
        
        // Add an action to close the alert
        let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        
        // Present the alert
        present(alertController, animated: true, completion: nil)
    }

        
    private func updateRecordButtonAppearance() {  // Fixed function name
        let imageName = isRecording ? "stop.circle.fill" : "record.circle"
        recordButton.setImage(UIImage(systemName: imageName), for: .normal)
        recordButton.tintColor = isRecording ? .red : .systemRed
    }
    
    @objc private func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func updateRecordButtonState() {
            recordButton.isEnabled = !(node.codable?.hasAudio ?? false)
            if node.codable?.hasAudio ?? false {
                recordButton.tintColor = .systemGray
                recordButton.setImage(UIImage(systemName: "record.circle"), for: .normal)
            }
        }
    
    private func startRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("\(node.name ?? "recording")_\(Date().timeIntervalSince1970).m4a")
        print("Recording started at: \(audioFilename.path)")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
            showRecordingError()
        }
    }
    
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        if let audioRecorder = audioRecorder {
            // Store current scroll position
            let currentOffset = canvasView.contentOffset
            node.codable?.hasAudio = true
            node.codable?.audioFileName = audioRecorder.url.lastPathComponent
            node.codable?.audioDuration = audioRecorder.currentTime
            node.push()
            
            setupAudioPlayer()
            updateRecordButtonState()
            // Restore scroll position
            DispatchQueue.main.async {
                self.canvasView.setContentOffset(currentOffset, animated: false)
            }
        }
        
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func showRecordingError() {
        let alert = UIAlertController(
            title: "Recording Error",
            message: "There was an error starting the audio recording. Please check the app's microphone permissions.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    
    
    private func setupDelegates() {
        guard let nodeCodable = node.codable else { return }
        
        canvasView.trackableDelegate = self
        canvasView.delegate = self // PKCanvasViewDelegate
        timedDrawing = TimedDrawing(timedS: nodeCodable.timedStrokes) // Initialize with existing drawing
        canvasView.drawing = nodeCodable.drawing // Assign wrapped drawing to canvasView

        if !UIDevice.isLimited() {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            toolPicker.addObserver(self)
            updateLayout(for: toolPicker)
            canvasView.becomeFirstResponder()
        }
    }
    

    @objc func setDrawingMode() {
        // Highlight "Drawing" button by changing the icon to green
        drawingButton?.tintColor = .green
        drawingButton?.setImage(
            UIImage(systemName: "pencil.circle")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )

        // Reset "Viewing" button to default
        viewingButton?.tintColor = .systemBlue
        viewingButton?.setImage(
            UIImage(systemName: "eye.circle")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )

        canvasView.isUserInteractionEnabled = true
        canvasView.drawingPolicy = .anyInput // Enable drawing
        print("Switched to drawing mode")
    }

    @objc func setViewingMode() {
        // Highlight "Viewing" button by changing the icon to green
        viewingButton?.tintColor = .green
        viewingButton?.setImage(
            UIImage(systemName: "eye.circle")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )

        // Reset "Drawing" button to default
        drawingButton?.tintColor = .systemBlue
        drawingButton?.setImage(
            UIImage(systemName: "pencil.circle")?.withRenderingMode(.alwaysTemplate),
            for: .normal
        )

        canvasView.isUserInteractionEnabled = false
        print("Switched to viewing mode")
    }


    
    func updateContentSizeForDrawing() {
        
        let drawing = canvasView.drawing
        let contentHeight: CGFloat

        if !drawing.bounds.isNull {
            contentHeight = max(canvasView.bounds.height, (drawing.bounds.maxY + 500) * canvasView.zoomScale)
        } else {
            contentHeight = canvasView.bounds.height
        }
        canvasView.contentSize = CGSize(width: node.codable!.width * canvasView.zoomScale, height: contentHeight)
        
    }
    
    
    @objc func exportDrawing() {
        
        toolPicker.setVisible(false, forFirstResponder: canvasView)
        
        let alertTitle = NSLocalizedString("Export note", comment: "")
        let alertCancelTitle = NSLocalizedString("Cancel", comment: "")
        
        let alertController = UIAlertController(title: alertTitle, message: "", preferredStyle: .actionSheet)

        if let popoverController = alertController.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        alertController.addAction(createExportToPDFAction())
        alertController.addAction(createExportToJPGAction())
        alertController.addAction(createExportToPNGAction())
        alertController.addAction(createShareAction())
        alertController.addAction(UIAlertAction(title: alertCancelTitle, style: .cancel, handler: { (action) in
            self.toolPicker.setVisible(true, forFirstResponder: self.canvasView)
        }))
        
        present(alertController, animated: true, completion: nil)
        
    }
    
    
    @objc func writeDrawingHandler() {
        
        node.inConflict { (conflict) in
            
            if !conflict {
                Logger.main.info("Files not in conflict")
                self.writeDrawing()
                return
            }

            Logger.main.warning("Files in conflict")
            
            DispatchQueue.main.async {

                let alertTitle = NSLocalizedString("File conflict found", comment: "")
                let alertMessage = String(format: NSLocalizedString("The file could not be saved. It seems that the original file (%s.jot) on the disk has changed. (Maybe it was edited on another device at the same time?). Use one of the following options to fix the problem.", comment: "File conflict found (What happened, How to fix)"), self.node.name ?? "?")
                let alertActionOverwriteTitle = NSLocalizedString("Overwrite", comment: "")
                let alertActionCloseTitle = NSLocalizedString("Close without saving", comment: "")
                let alertCancelTitle = NSLocalizedString("Cancel", comment: "")

                let alertController = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: alertActionOverwriteTitle, style: .destructive, handler: { (action) in
                    self.writeDrawing()
                }))
                alertController.addAction(UIAlertAction(title: alertActionCloseTitle, style: .destructive, handler: { (action) in
                    self.navigationController?.popViewController(animated: true)
                }))
                alertController.addAction(UIAlertAction(title: alertCancelTitle, style: .cancel, handler: nil))

                self.present(alertController, animated: true, completion: nil)
                
            }

        }
        
    }
    
    func writeDrawing() {
        DispatchQueue.main.async {
            self.hasModifiedDrawing = false
            self.node.setDrawing(drawing: self.canvasView.drawing, timedStrokes: self.timedDrawing.getTimedStrokes()) // Save the wrapped drawing and timed strokes.
        }
    }
    
    func logTimedStrokes() {
        print("Logging timed strokes!")
        let timedStrokes = timedDrawing.getTimedStrokes()
        for (index, timedStroke) in timedStrokes.enumerated() {
            print("Stroke \(index + 1):")
            print("    Start Time: \(timedStroke.startTime)")
            print("    End Time: \(timedStroke.endTime)")
        }
    }
}

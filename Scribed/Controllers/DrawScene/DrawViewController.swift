//
//  DrawViewController.swift
//  Jottre
//
//  Created by Anton Lorani on 16.01.21.
//

import UIKit
import PencilKit
import OSLog

class DrawViewController: UIViewController {
    
    // MARK: - Properties
    
    internal var startTime: Date?
    internal var currentStrokeStartTime: Date?
    internal var currentStroke: PKStroke?
    internal var lastStrokeCount: Int = 0
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
    
    
    
    // MARK: - Methods
    
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
        buttonStackView.spacing = 8
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let drawingButton = UIButton(type: .system)
        drawingButton.setTitle("Drawing", for: .normal)
        drawingButton.addTarget(self, action: #selector(setDrawingMode), for: .touchUpInside)
        
        let viewingButton = UIButton(type: .system)
        viewingButton.setTitle("Viewing", for: .normal)
        viewingButton.addTarget(self, action: #selector(setViewingMode), for: .touchUpInside)
        
        buttonStackView.addArrangedSubview(drawingButton)
        buttonStackView.addArrangedSubview(viewingButton)
        
        view.addSubview(buttonStackView)
        
        // Position the stack view below the navigation bar
        NSLayoutConstraint.activate([
            buttonStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            buttonStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16)
        ])
        
        updateContentSizeForDrawing()
    }

    
    
    private func setupDelegates() {
        guard let nodeCodable = node.codable else { return }
        
        canvasView.trackableDelegate = self
        canvasView.delegate = self // PKCanvasViewDelegate
        timedDrawing = TimedDrawing(drawing: nodeCodable.drawing) // Initialize with existing drawing
        canvasView.drawing = timedDrawing.drawing // Assign wrapped drawing to canvasView

        if !UIDevice.isLimited() {
            toolPicker.setVisible(true, forFirstResponder: canvasView)
            toolPicker.addObserver(canvasView)
            toolPicker.addObserver(self)
            updateLayout(for: toolPicker)
            canvasView.becomeFirstResponder()
        }
    }

    private func setupModeButtons() {
        // Add mode toggle buttons
        let drawingButton = UIBarButtonItem(title: "Drawing", style: .plain, target: self, action: #selector(setDrawingMode))
        let viewingButton = UIBarButtonItem(title: "Viewing", style: .plain, target: self, action: #selector(setViewingMode))
        navigationItem.rightBarButtonItems = [drawingButton, viewingButton]
    }
    
    @objc func setDrawingMode() {
        canvasView.isUserInteractionEnabled = true
        canvasView.allowsFingerDrawing = true // Enable finger drawing if applicable
        canvasView.drawingPolicy = .anyInput // Enable drawing with Pencil and finger
        print("Switched to drawing mode")
    }

    @objc func setViewingMode() {
        canvasView.isUserInteractionEnabled = false // Disable all interaction
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
            self.node.setDrawing(drawing: self.timedDrawing.drawing) // Save the wrapped drawing
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

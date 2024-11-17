import AVFoundation
import UIKit

class AudioPlayerView: UIView {
    // Add cleanup method for proper memory management
    func cleanup() {
        timer?.invalidate()
        timer = nil
        audioPlayer?.stop()
        audioPlayer = nil
    }
        
    // Override removeFromSuperview to ensure cleanup
    override func removeFromSuperview() {
        cleanup()
        super.removeFromSuperview()
    }
    
    private let playButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "play.circle"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let progressSlider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        return slider
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.text = "00:00 / 00:00"
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var isPlaying = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(playButton)
        addSubview(progressSlider)
        addSubview(timeLabel)
        
        NSLayoutConstraint.activate([
            playButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            playButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 44),
            playButton.heightAnchor.constraint(equalToConstant: 44),
            
            progressSlider.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 8),
            progressSlider.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            timeLabel.leadingAnchor.constraint(equalTo: progressSlider.trailingAnchor, constant: 8),
            timeLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func setupActions() {
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        progressSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }
    
    private(set) var currentAudioURL: URL?

    func loadAudio(url: URL) {
        currentAudioURL = url
        do {
            // Don't recreate player if it's already playing the same file
            if let currentPlayer = audioPlayer,
                currentPlayer.url == url {
                return
            }
                
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            progressSlider.maximumValue = Float(audioPlayer?.duration ?? 0)
            updateTimeLabel()
        } catch {
            print("Error loading audio: \(error)")
        }
    }
    
    private func updateProgress() {
        guard let player = audioPlayer else { return }
            
        // Update UI without triggering layout changes
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        progressSlider.value = Float(player.currentTime)
        updateTimeLabel()
        CATransaction.commit()
        
        if !player.isPlaying {
            pauseAudio()
        }
    }
    
    @objc private func playButtonTapped() {
        if isPlaying {
            pauseAudio()
        } else {
            playAudio()
        }
    }
    
    private func playAudio() {
        audioPlayer?.play()
        isPlaying = true
        playButton.setImage(UIImage(systemName: "pause.circle"), for: .normal)
        startTimer()
    }
    
    private func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        playButton.setImage(UIImage(systemName: "play.circle"), for: .normal)
        timer?.invalidate()
    }
    
    @objc private func sliderValueChanged() {
        audioPlayer?.currentTime = TimeInterval(progressSlider.value)
        updateTimeLabel()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }
    
    private func updateTimeLabel() {
        let current = formatTime(TimeInterval(progressSlider.value))
        let total = formatTime(audioPlayer?.duration ?? 0)
        timeLabel.text = "\(current) / \(total)"
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

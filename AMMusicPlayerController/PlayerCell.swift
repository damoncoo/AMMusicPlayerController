//
//  PlayerCell.swift
//  AMMusicPlayerController
//
//  Created by YOSHIMUTA YOHEI on 2019/09/26.
//  Copyright © 2019 YOSHIMUTA YOHEI. All rights reserved.
//

import MediaPlayer
import RxCocoa
import RxMusicPlayer
import RxSwift
import UIKit

class PlayerCell: UITableViewCell {
    @IBOutlet private var playButton: UIButton!
    @IBOutlet private var nextButton: UIButton!
    @IBOutlet private var prevButton: UIButton!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var artImageView: UIImageView!
    @IBOutlet private var seekBar: ProgressSlider!
    @IBOutlet private var seekDurationLabel: UILabel!
    @IBOutlet private var durationLabel: UILabel!
    @IBOutlet private var shuffleButton: UIButton!
    @IBOutlet private var repeatButton: UIButton!
    @IBOutlet private var volumeView: MPVolumeView!

    private var disposeBag = DisposeBag()
    private var playerConfig: AMMusicPlayerConfig.ControlConfig?
    private var canPlay: Bool = true

    override func prepareForReuse() {
        super.prepareForReuse()
        disposeBag = DisposeBag()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        volumeView.showsRouteButton = false
    }

    // swiftlint:disable cyclomatic_complexity
    func run(_ player: RxMusicPlayer,
             playerFailureRelay: PublishRelay<Error>,
             config: AMMusicPlayerConfig.ControlConfig) {

        playerConfig = config

        // 1) Set images
        for v in volumeView.subviews {
            if let volumeSlider = v as? UISlider {
                volumeSlider.minimumValueImage = config.volumeMinImage
                volumeSlider.maximumValueImage = config.volumeMaxImage
            }
        }
//        if let image = config.nextButtonImage {
//            nextButton.setImage(image, for: .normal)
//        }
//        if let image = config.prevButtonImage {
//            prevButton.setImage(image, for: .normal)
//        }

        playButton.setImage(config.getPlayImage(play: false), for: .normal)

        setupStyle()

        // 2) Control views
        player.rx.canSendCommand(cmd: .play).map { [unowned self] canPlay in
            self.canPlay = canPlay
            return config.getPlayImage(play: canPlay)
        }
        .drive(playButton.rx.image(for: .normal))
        .disposed(by: disposeBag)

        player.rx.canSendCommand(cmd: .next)
            .drive(nextButton.rx.isEnabled)
            .disposed(by: disposeBag)

        player.rx.canSendCommand(cmd: .previous)
            .drive(prevButton.rx.isEnabled)
            .disposed(by: disposeBag)

        player.rx.canSendCommand(cmd: .seek(seconds: 0, shouldPlay: false))
            .drive(seekBar.rx.isUserInteractionEnabled)
            .disposed(by: disposeBag)

        player.rx.currentItemTitle()
            .drive(titleLabel.rx.text)
            .disposed(by: disposeBag)

        player.rx.currentItemArtwork()
            .drive(artImageView.rx.image)
            .disposed(by: disposeBag)

        player.rx.currentItemRestDurationDisplay()
            .map {
                guard let rest = $0 else { return "00:00" }
                return "-\(rest)"
            }
            .drive(durationLabel.rx.text)
            .disposed(by: disposeBag)

        player.rx.currentItemTimeDisplay()
            .drive(seekDurationLabel.rx.text)
            .disposed(by: disposeBag)

        player.rx.currentItemDuration()
            .map { Float($0?.seconds ?? 0) }
            .do(onNext: { [weak self] in
                self?.seekBar.maximumValue = $0
            })
            .drive()
            .disposed(by: disposeBag)

        let seekValuePass = BehaviorRelay<Bool>(value: true)
        player.rx.currentItemTime()
            .withLatestFrom(seekValuePass.asDriver()) { ($0, $1) }
            .filter { $0.1 }
            .map { Float($0.0?.seconds ?? 0) }
            .drive(seekBar.rx.value)
            .disposed(by: disposeBag)
        seekBar.rx.controlEvent(.touchDown)
            .do(onNext: {
                seekValuePass.accept(false)
            })
            .subscribe()
            .disposed(by: disposeBag)
        seekBar.rx.controlEvent(.touchUpInside)
            .do(onNext: {
                seekValuePass.accept(true)
            })
            .subscribe()
            .disposed(by: disposeBag)

        player.rx.currentItemLoadedProgressRate()
            .drive(seekBar.rx.playableProgress)
            .disposed(by: disposeBag)

        player.rx.shuffleMode()
            .map { $0 == .off ? config.shuffleOffImage : config.shuffleOnImage }
            .drive(shuffleButton.rx.image(for: .normal))
            .disposed(by: disposeBag)

        player.rx.repeatMode()
            .map { mode -> UIImage? in
                switch mode {
                case .none: return config.repeatNoneImage
                case .one: return config.repeatOneImage
                case .all: return config.repeatAllImage
                }
            }
            .drive(repeatButton.rx.image(for: .normal))
            .disposed(by: disposeBag)

        player.rx.playerIndex()
            .do(onNext: { index in
                if index == player.queuedItems.count - 1 {
                    // You can remove the comment-out below to confirm the append().
                    // player.append(items: items)
                }
            })
            .drive()
            .disposed(by: disposeBag)

        // 3) Process the user's input
        let cmd = Driver.merge(
            playButton.rx.tap.asDriver()
                .withLatestFrom(player.rx.canSendCommand(cmd: .play))
                .map {
                    $0 ? RxMusicPlayer.Command.play : RxMusicPlayer.Command.pause
                },
            nextButton.rx.tap.asDriver().map { RxMusicPlayer.Command.next },
            prevButton.rx.tap.asDriver().map { RxMusicPlayer.Command.previous },
            seekBar.rx.controlEvent(.valueChanged).asDriver()
                .map { [weak self] _ in
                    RxMusicPlayer.Command.seek(seconds: Int(self?.seekBar.value ?? 0),
                                               shouldPlay: false)
                }
                .distinctUntilChanged()
        )
        .startWith(.prefetch)

        player.run(cmd: cmd)
            .do(onNext: { status in
                UIApplication.shared.isNetworkActivityIndicatorVisible = status == .loading
            })
            .flatMap { status -> Driver<()> in
                switch status {
                case let RxMusicPlayer.Status.failed(err: err):
                    playerFailureRelay.accept(err)
                case let RxMusicPlayer.Status.critical(err: err):
                    playerFailureRelay.accept(err)
                default: ()
                }
                return .just(())
            }
            .drive()
            .disposed(by: disposeBag)

        shuffleButton.rx.tap.asDriver()
            .drive(onNext: {
                switch player.shuffleMode {
                case .off: player.shuffleMode = .songs
                case .songs: player.shuffleMode = .off
                }
            })
            .disposed(by: disposeBag)

        repeatButton.rx.tap.asDriver()
            .drive(onNext: {
                switch player.repeatMode {
                case .none: player.repeatMode = .all
                case .all: player.repeatMode = .one
                case .one: player.repeatMode = .none
                }
            })
            .disposed(by: disposeBag)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setupStyle()
    }

    func setupStyle() {

        if #available(iOS 13.0, *) {
            let dark = UITraitCollection.current.userInterfaceStyle == .dark
            if dark {
                if let image = self.playerConfig?.nextButtonImage2 {
                    nextButton.setImage(image, for: .normal)
                }
                if let image = self.playerConfig?.prevButtonImage2 {
                    prevButton.setImage(image, for: .normal)
                }
            } else {
                if let image = self.playerConfig?.nextButtonImage {
                    nextButton.setImage(image, for: .normal)
                }
                if let image = self.playerConfig?.prevButtonImage {
                    prevButton.setImage(image, for: .normal)
                }
            }
            self.playButton.setImage(self.playerConfig?.getPlayImage(play: self.canPlay), for: .normal)

        } else {
            if let image = self.playerConfig?.nextButtonImage {
                nextButton.setImage(image, for: .normal)
            }
            if let image = self.playerConfig?.prevButtonImage {
                prevButton.setImage(image, for: .normal)
            }
            playButton.setImage(playerConfig?.getPlayImage(play: false), for: .normal)
        }
    }
}

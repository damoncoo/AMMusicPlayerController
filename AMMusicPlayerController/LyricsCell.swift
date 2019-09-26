//
//  LyricsCell.swift
//  AMMusicPlayerController
//
//  Created by YOSHIMUTA YOHEI on 2019/09/26.
//  Copyright © 2019 YOSHIMUTA YOHEI. All rights reserved.
//

import RxMusicPlayer
import RxSwift
import UIKit

class LyricsCell: UITableViewCell {
    @IBOutlet private var lyricsLabel: UILabel!

    private let disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    func run(_ player: RxMusicPlayer) {
        player.rx.currentItemLyrics()
            .distinctUntilChanged()
            .drive(lyricsLabel.rx.text)
            .disposed(by: disposeBag)
    }
}

//
//  WebSearchTableCell.swift
//  Amperfy
//
//  Created for Web Search feature.
//  Copyright (c) 2024 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

// MARK: - WebSearchTableCell

class WebSearchTableCell: UITableViewCell {
  static let reuseIdentifier = "WebSearchTableCell"
  static let rowHeight: CGFloat = 72.0

  // MARK: - Subviews

  private let coverImageView: UIImageView = {
    let iv = UIImageView()
    iv.translatesAutoresizingMaskIntoConstraints = false
    iv.contentMode = .scaleAspectFill
    iv.clipsToBounds = true
    iv.layer.cornerRadius = 6
    iv.backgroundColor = .systemGray5
    iv.image = UIImage(systemName: "music.note")
    iv.tintColor = .systemGray2
    return iv
  }()

  private let titleLabel: UILabel = {
    let lbl = UILabel()
    lbl.translatesAutoresizingMaskIntoConstraints = false
    lbl.font = .systemFont(ofSize: 15, weight: .semibold)
    lbl.textColor = .label
    lbl.lineBreakMode = .byTruncatingTail
    return lbl
  }()

  private let artistLabel: UILabel = {
    let lbl = UILabel()
    lbl.translatesAutoresizingMaskIntoConstraints = false
    lbl.font = .systemFont(ofSize: 13)
    lbl.textColor = .secondaryLabel
    lbl.lineBreakMode = .byTruncatingTail
    return lbl
  }()

  private let durationLabel: UILabel = {
    let lbl = UILabel()
    lbl.translatesAutoresizingMaskIntoConstraints = false
    lbl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    lbl.textColor = .tertiaryLabel
    lbl.setContentHuggingPriority(.required, for: .horizontal)
    return lbl
  }()

  private let libraryBadge: UIImageView = {
    let iv = UIImageView()
    iv.translatesAutoresizingMaskIntoConstraints = false
    iv.image = UIImage(systemName: "checkmark.circle.fill")
    iv.tintColor = .systemGreen
    iv.isHidden = true
    return iv
  }()

  private let downloadButton: UIButton = {
    var config = UIButton.Configuration.plain()
    config.image = UIImage(systemName: "arrow.down.circle")
    config.baseForegroundColor = .systemBlue
    config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
    let btn = UIButton(configuration: config)
    btn.translatesAutoresizingMaskIntoConstraints = false
    return btn
  }()

  private let progressView: UIProgressView = {
    let pv = UIProgressView(progressViewStyle: .default)
    pv.translatesAutoresizingMaskIntoConstraints = false
    pv.isHidden = true
    pv.layer.cornerRadius = 2
    pv.clipsToBounds = true
    return pv
  }()

  private let statusLabel: UILabel = {
    let lbl = UILabel()
    lbl.translatesAutoresizingMaskIntoConstraints = false
    lbl.font = .systemFont(ofSize: 10)
    lbl.textColor = .secondaryLabel
    lbl.isHidden = true
    return lbl
  }()

  // MARK: - State

  var onDownloadTapped: (() -> Void)?

  // MARK: - Init

  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    setupLayout()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Layout

  private func setupLayout() {
    selectionStyle = .none
    backgroundColor = .systemBackground

    contentView.addSubview(coverImageView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(artistLabel)
    contentView.addSubview(durationLabel)
    contentView.addSubview(libraryBadge)
    contentView.addSubview(downloadButton)
    contentView.addSubview(progressView)
    contentView.addSubview(statusLabel)

    downloadButton.addTarget(self, action: #selector(downloadTapped), for: .touchUpInside)

    NSLayoutConstraint.activate([
      // Cover image: 52×52, left margin 12
      coverImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
      coverImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      coverImageView.widthAnchor.constraint(equalToConstant: 52),
      coverImageView.heightAnchor.constraint(equalToConstant: 52),

      // Download button: right
      downloadButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
      downloadButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      downloadButton.widthAnchor.constraint(equalToConstant: 44),
      downloadButton.heightAnchor.constraint(equalToConstant: 44),

      // Library badge: left of download button
      libraryBadge.trailingAnchor.constraint(equalTo: downloadButton.leadingAnchor, constant: -4),
      libraryBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
      libraryBadge.widthAnchor.constraint(equalToConstant: 18),
      libraryBadge.heightAnchor.constraint(equalToConstant: 18),

      // Title label
      titleLabel.leadingAnchor.constraint(equalTo: coverImageView.trailingAnchor, constant: 10),
      titleLabel.trailingAnchor.constraint(equalTo: libraryBadge.leadingAnchor, constant: -8),
      titleLabel.topAnchor.constraint(equalTo: coverImageView.topAnchor, constant: 4),

      // Artist label below title
      artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
      artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

      // Duration label below artist
      durationLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      durationLabel.topAnchor.constraint(equalTo: artistLabel.bottomAnchor, constant: 2),

      // Progress bar below duration
      progressView.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      progressView.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
      progressView.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 2),
      progressView.heightAnchor.constraint(equalToConstant: 3),

      // Status label below progress
      statusLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
      statusLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 1),
    ])
  }

  // MARK: - Configuration

  func configure(with result: NASSearchResult) {
    titleLabel.text = result.title
    artistLabel.text = result.artist ?? result.albumTitle ?? ""
    durationLabel.text = formatDuration(result.duration)
    libraryBadge.isHidden = !result.isInLibrary
    resetDownloadState()
    loadCoverImage(urlString: result.coverUrl)
  }

  func setInLibrary(_ inLibrary: Bool) {
    libraryBadge.isHidden = !inLibrary
  }

  func updateDownloadState(_ state: DownloadCellState) {
    switch state {
    case .idle:
      resetDownloadState()
    case .downloading(let progress, let statusText):
      downloadButton.isHidden = true
      progressView.isHidden = false
      progressView.progress = progress
      statusLabel.isHidden = false
      statusLabel.text = statusText
    case .done:
      downloadButton.isHidden = false
      var config = downloadButton.configuration
      config?.image = UIImage(systemName: "checkmark.circle.fill")
      config?.baseForegroundColor = .systemGreen
      downloadButton.configuration = config
      downloadButton.isEnabled = false
      progressView.isHidden = true
      statusLabel.isHidden = true
    case .error(let msg):
      downloadButton.isHidden = false
      var config = downloadButton.configuration
      config?.image = UIImage(systemName: "exclamationmark.circle")
      config?.baseForegroundColor = .systemRed
      downloadButton.configuration = config
      downloadButton.isEnabled = true
      progressView.isHidden = true
      statusLabel.isHidden = false
      statusLabel.text = msg
    }
  }

  private func resetDownloadState() {
    downloadButton.isHidden = false
    downloadButton.isEnabled = true
    var config = downloadButton.configuration
    config?.image = UIImage(systemName: "arrow.down.circle")
    config?.baseForegroundColor = .systemBlue
    downloadButton.configuration = config
    progressView.isHidden = true
    progressView.progress = 0
    statusLabel.isHidden = true
    statusLabel.text = nil
  }

  // MARK: - Helpers

  private func formatDuration(_ seconds: Int?) -> String {
    guard let seconds else { return "" }
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%d:%02d", m, s)
  }

  private func loadCoverImage(urlString: String?) {
    coverImageView.image = UIImage(systemName: "music.note")
    coverImageView.tintColor = .systemGray2
    guard let urlString, let url = URL(string: urlString) else { return }
    let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard let data, let image = UIImage(data: data) else { return }
      DispatchQueue.main.async { self?.coverImageView.image = image }
    }
    task.resume()
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    coverImageView.image = UIImage(systemName: "music.note")
    titleLabel.text = nil
    artistLabel.text = nil
    durationLabel.text = nil
    libraryBadge.isHidden = true
    onDownloadTapped = nil
    resetDownloadState()
  }

  @objc
  private func downloadTapped() {
    onDownloadTapped?()
  }
}

// MARK: - DownloadCellState

enum DownloadCellState {
  case idle
  case downloading(progress: Float, statusText: String)
  case done
  case error(String)
}

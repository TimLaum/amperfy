//
//  WebSearchVC.swift
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

import AmperfyKit
import UIKit

// MARK: - NASSearchResult

struct NASSearchResult: Decodable {
  let title: String
  let artist: String?
  let album: String?
  let coverUrl: String?
  let duration: Int?
  let source: String?
  let deezerId: Int?
  var isInLibrary: Bool = false

  /// Alias for WebSearchTableCell compatibility
  var albumTitle: String? { album }

  enum CodingKeys: String, CodingKey {
    case title, artist, album, duration, source
    case coverUrl = "cover_url"
    case deezerId = "deezer_id"
  }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    title = try c.decode(String.self, forKey: .title)
    artist = try c.decodeIfPresent(String.self, forKey: .artist)
    album = try c.decodeIfPresent(String.self, forKey: .album)
    coverUrl = try c.decodeIfPresent(String.self, forKey: .coverUrl)
    duration = try c.decodeIfPresent(Int.self, forKey: .duration)
    source = try c.decodeIfPresent(String.self, forKey: .source)
    deezerId = try c.decodeIfPresent(Int.self, forKey: .deezerId)
    isInLibrary = false
  }
}

// MARK: - Private API models

private struct NASDownloadResponse: Decodable {
  let downloadId: String
  let status: String

  enum CodingKeys: String, CodingKey {
    case downloadId = "download_id"
    case status
  }
}

private struct NASStatusResponse: Decodable {
  let status: String
  let progress: Float?
  let error: String?
  let file: String?
  let title: String?
  let artist: String?
}

private struct NASCheckResponse: Decodable {
  let exists: Bool
}

// MARK: - WebSearchVC

class WebSearchVC: UIViewController {
  private static let nasApiBase = "http://192.168.1.20:8787"
  private let account: Account

  // MARK: - UI

  private lazy var tableView: UITableView = {
    let tv = UITableView(frame: .zero, style: .plain)
    tv.translatesAutoresizingMaskIntoConstraints = false
    tv.register(
      WebSearchTableCell.self,
      forCellReuseIdentifier: WebSearchTableCell.reuseIdentifier
    )
    tv.rowHeight = WebSearchTableCell.rowHeight
    tv.dataSource = self
    tv.delegate = self
    tv.keyboardDismissMode = .onDrag
    tv.separatorInset = UIEdgeInsets(top: 0, left: 74, bottom: 0, right: 0)
    return tv
  }()

  private let emptyLabel: UILabel = {
    let lbl = UILabel()
    lbl.translatesAutoresizingMaskIntoConstraints = false
    lbl.text = "Search for music on the web"
    lbl.textColor = .secondaryLabel
    lbl.textAlignment = .center
    lbl.font = .systemFont(ofSize: 16)
    return lbl
  }()

  // MARK: - State

  private var results: [NASSearchResult] = []
  private var downloadStates: [String: DownloadCellState] = [:]
  private var downloadTimers: [String: Timer] = [:]
  private var searchTask: URLSessionDataTask?
  private var searchWorkItem: DispatchWorkItem?

  // MARK: - Init

  init(account: Account) {
    self.account = account
    super.init(nibName: nil, bundle: nil)
    title = "Web Search"
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    setupSearchController()
    setupLayout()
  }

  private func setupSearchController() {
    let sc = UISearchController(searchResultsController: nil)
    sc.searchResultsUpdater = self
    sc.obscuresBackgroundDuringPresentation = false
    sc.searchBar.placeholder = "Title, artist..."
    navigationItem.searchController = sc
    navigationItem.hidesSearchBarWhenScrolling = false
    definesPresentationContext = true
  }

  private func setupLayout() {
    view.addSubview(tableView)
    view.addSubview(emptyLabel)

    NSLayoutConstraint.activate([
      tableView.topAnchor.constraint(equalTo: view.topAnchor),
      tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
    updateEmptyState()
  }

  private func updateEmptyState() {
    emptyLabel.isHidden = !results.isEmpty
  }

  // MARK: - Search

  private func performSearch(query: String) {
    searchTask?.cancel()
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      results = []
      downloadStates = [:]
      tableView.reloadData()
      updateEmptyState()
      return
    }
    guard
      let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
      let url = URL(string: "\(Self.nasApiBase)/search?q=\(encoded)")
    else { return }

    searchTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
      guard let self, let data, error == nil else { return }
      guard let decoded = try? JSONDecoder().decode([NASSearchResult].self, from: data) else { return }
      DispatchQueue.main.async {
        self.results = decoded
        self.downloadStates = [:]
        self.tableView.reloadData()
        self.updateEmptyState()
        self.checkLibraryStatus()
      }
    }
    searchTask?.resume()
  }

  private func checkLibraryStatus() {
    for (index, result) in results.enumerated() {
      guard
        let artist = result.artist,
        let titleEnc = result.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
        let artistEnc = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
        let url = URL(string: "\(Self.nasApiBase)/check?title=\(titleEnc)&artist=\(artistEnc)")
      else { continue }

      URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
        guard
          let self,
          let data,
          let resp = try? JSONDecoder().decode(NASCheckResponse.self, from: data)
        else { return }
        DispatchQueue.main.async {
          guard index < self.results.count else { return }
          self.results[index].isInLibrary = resp.exists
          let indexPath = IndexPath(row: index, section: 0)
          if let cell = self.tableView.cellForRow(at: indexPath) as? WebSearchTableCell {
            cell.setInLibrary(resp.exists)
          }
        }
      }.resume()
    }
  }

  // MARK: - Download

  private func downloadKey(for result: NASSearchResult) -> String {
    "\(result.title)|\(result.artist ?? "")"
  }

  private func startDownload(for result: NASSearchResult, at indexPath: IndexPath) {
    let key = downloadKey(for: result)
    guard downloadTimers[key] == nil else { return }
    guard let url = URL(string: "\(Self.nasApiBase)/download") else { return }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    var body: [String: Any] = [
      "title": result.title,
      "artist": result.artist ?? "",
      "album": result.album ?? "",
      "cover_url": result.coverUrl ?? "",
      "duration": result.duration ?? 0,
      "source": result.source ?? "deezer",
    ]
    if let deezerId = result.deezerId {
      body["deezer_id"] = deezerId
    }
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let initialState = DownloadCellState.downloading(progress: 0, statusText: "Starting…")
    downloadStates[key] = initialState
    updateCellState(at: indexPath, state: initialState)

    URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
      guard let self else { return }
      guard
        let data, error == nil,
        let resp = try? JSONDecoder().decode(NASDownloadResponse.self, from: data)
      else {
        DispatchQueue.main.async {
          let errState = DownloadCellState.error("Request failed")
          self.downloadStates[key] = errState
          self.updateCellState(at: indexPath, state: errState)
        }
        return
      }
      DispatchQueue.main.async {
        self.startPolling(downloadId: resp.downloadId, key: key, indexPath: indexPath)
      }
    }.resume()
  }

  private func startPolling(downloadId: String, key: String, indexPath: IndexPath) {
    let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
      guard let self else { timer.invalidate(); return }
      self.pollStatus(downloadId: downloadId, key: key, indexPath: indexPath, timer: timer)
    }
    downloadTimers[key] = timer
  }

  private func pollStatus(
    downloadId: String,
    key: String,
    indexPath: IndexPath,
    timer: Timer
  ) {
    guard let url = URL(string: "\(Self.nasApiBase)/status/\(downloadId)") else { return }
    URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
      guard
        let self,
        let data,
        let resp = try? JSONDecoder().decode(NASStatusResponse.self, from: data)
      else { return }
      DispatchQueue.main.async {
        let state: DownloadCellState
        switch resp.status {
        case "done", "already_exists":
          state = .done
          timer.invalidate()
          self.downloadTimers.removeValue(forKey: key)
          if indexPath.row < self.results.count {
            self.results[indexPath.row].isInLibrary = true
            if let cell = self.tableView.cellForRow(at: indexPath) as? WebSearchTableCell {
              cell.setInLibrary(true)
            }
          }
        case "error":
          state = .error(resp.error ?? "Error")
          timer.invalidate()
          self.downloadTimers.removeValue(forKey: key)
        default:
          let progress = resp.progress ?? 0
          let statusText = self.localizedStatus(resp.status)
          state = .downloading(progress: progress, statusText: statusText)
        }
        self.downloadStates[key] = state
        self.updateCellState(at: indexPath, state: state)
      }
    }.resume()
  }

  private func updateCellState(at indexPath: IndexPath, state: DownloadCellState) {
    guard let cell = tableView.cellForRow(at: indexPath) as? WebSearchTableCell else { return }
    cell.updateDownloadState(state)
  }

  private func localizedStatus(_ status: String) -> String {
    switch status {
    case "searching": return "Searching…"
    case "searching_youtube": return "Finding on YouTube…"
    case "downloading": return "Downloading…"
    case "tagging": return "Tagging…"
    case "normalizing": return "Normalizing…"
    case "scanning": return "Scanning library…"
    default: return status
    }
  }
}

// MARK: - UISearchResultsUpdating

extension WebSearchVC: UISearchResultsUpdating {
  func updateSearchResults(for searchController: UISearchController) {
    searchWorkItem?.cancel()
    let query = searchController.searchBar.text ?? ""
    let workItem = DispatchWorkItem { [weak self] in
      self?.performSearch(query: query)
    }
    searchWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
  }
}

// MARK: - UITableViewDataSource

extension WebSearchVC: UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    results.count
  }

  func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath
  ) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(
      withIdentifier: WebSearchTableCell.reuseIdentifier,
      for: indexPath
    ) as! WebSearchTableCell
    let result = results[indexPath.row]
    cell.configure(with: result)

    let key = downloadKey(for: result)
    if let state = downloadStates[key] {
      cell.updateDownloadState(state)
    }
    cell.onDownloadTapped = { [weak self] in
      guard let self else { return }
      self.startDownload(for: result, at: indexPath)
    }
    return cell
  }
}

// MARK: - UITableViewDelegate

extension WebSearchVC: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    WebSearchTableCell.rowHeight
  }
}

// Made by Lumaa

import Foundation
import SwiftUI
import UIKit
import MediaPlayer

// MARK: As of right now, any of this works UNLESS Apple allows developers to set NowPlaying info without playing audio...

enum NowPlayableCommand: CaseIterable {
    case play, pause, togglePlayPause,
         nextTrack, previousTrack,
         changePlaybackRate, changePlaybackPosition,
         skipForward, skipBackward,
         seekForward, seekBackward
}

// MARK: - MPRemoteCommand

extension NowPlayableCommand {
    var remoteCommand: MPRemoteCommand {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        switch self {
            case .play:
                return commandCenter.playCommand
            case .pause:
                return commandCenter.pauseCommand
            case .togglePlayPause:
                return commandCenter.togglePlayPauseCommand
            case .nextTrack:
                return commandCenter.nextTrackCommand
            case .previousTrack:
                return commandCenter.previousTrackCommand
            case .changePlaybackRate:
                return commandCenter.changePlaybackRateCommand
            case .changePlaybackPosition:
                return commandCenter.changePlaybackPositionCommand
            case .skipForward:
                return commandCenter.skipForwardCommand
            case .skipBackward:
                return commandCenter.skipBackwardCommand
                
            case .seekForward:
                return commandCenter.seekForwardCommand
            case .seekBackward:
                return commandCenter.seekBackwardCommand
        }
    }
    // Adding Handler and accepting an escaping closure for event handling for a praticular remote command
    func addHandler(remoteCommandHandler: @escaping  (NowPlayableCommand, MPRemoteCommandEvent)->(MPRemoteCommandHandlerStatus)) {
        switch self {
            case .skipBackward:
                MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [10.0]
                
            case .skipForward:
                MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [10.0]
                
            default:
                break
        }
        self.remoteCommand.addTarget { event in
            remoteCommandHandler(self,event)
        }
    }
    
    func removeHandler() {
        self.remoteCommand.removeTarget(self)
    }
}

protocol NowPlayable {
    var supportedNowPlayableCommands: [NowPlayableCommand] { get }
    
    func configureRemoteCommands(remoteCommandHandler: @escaping  (NowPlayableCommand, MPRemoteCommandEvent)->(MPRemoteCommandHandlerStatus))
    func handleRemoteCommand(for type: NowPlayableCommand, with event: MPRemoteCommandEvent) async-> MPRemoteCommandHandlerStatus
    
//    func handleNowPlayingItemChange()
//    func handleNowPlayingItemPlaybackChange()
    
//    func addNowPlayingObservers()
    
    func setNowPlayingInfo() async
    func setNowPlayingPlaybackInfo() async

//    func resetNowPlaying()
}

struct NowPlaying: NowPlayable {
    var viewModel: MusicPlayerViewModel

    init(viewModel: MusicPlayerViewModel) {
        self.viewModel = viewModel
    }

    var supportedNowPlayableCommands: [NowPlayableCommand] {
        return [
            .togglePlayPause,
            .pause,
            .play,
            .nextTrack,
            .previousTrack,
            .changePlaybackPosition
        ]
    }
    
    func configureRemoteCommands(remoteCommandHandler: @escaping (NowPlayableCommand, MPRemoteCommandEvent) -> (MPRemoteCommandHandlerStatus)) {
        guard supportedNowPlayableCommands.count > 1 else {
            assertionFailure("Fatal error, atleast one remote command needs to be registered")
            return
        }
        
        supportedNowPlayableCommands.forEach { nowPlayableCommand in
            nowPlayableCommand.removeHandler()
            nowPlayableCommand.addHandler(remoteCommandHandler: remoteCommandHandler)
        }
    }
    
    @MainActor func handleRemoteCommand(for type: NowPlayableCommand, with event: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        switch (type) {
            case .togglePlayPause:
                Task { await viewModel.togglePlayPause() }
                return .success
            case .play:
                Task { await viewModel.togglePlayPause() }
                return .success
            case .pause:
                Task { await viewModel.togglePlayPause() }
                return .success
            case .nextTrack:
                Task { await viewModel.nextTrack() }
                return .success
            case .previousTrack:
                Task { await viewModel.previousTrack() }
                return .success
            case .changePlaybackPosition:
                guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                viewModel.currentTime = event.positionTime
                Task { await viewModel.seekToTime() }
                return .success
            default:
                return .commandFailed
        }
    }
    
    /// Static
    @MainActor func setNowPlayingInfo() {
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyPlaybackDuration: self.viewModel.currentTime,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: self.viewModel.duration,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
            MPMediaItemPropertyArtist: self.viewModel.currentTrack?.artist ?? "",
            MPMediaItemPropertyTitle: self.viewModel.currentTrack?.title ?? "",
            MPNowPlayingInfoPropertyIsLiveStream: false
        ]

        Task {
            if let image: UIImage = await self.viewModel.loadArtwork() {
                let artwork = MPMediaItemArtwork.init(boundsSize: image.size, requestHandler: { (size) -> UIImage in
                    return image
                })
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
            }
        }

        print("** NEW Now Playing ** \(self.viewModel.currentTrack?.title ?? "UNKNOWN TITLE")")

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Dynamic
    @MainActor func setNowPlayingPlaybackInfo() {
        let d = MPNowPlayingInfoCenter.default()
        var nowPlayingInfo: [String: Any] = d.nowPlayingInfo ?? [:]
        
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = self.viewModel.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.viewModel.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        d.nowPlayingInfo = nowPlayingInfo
    }
}

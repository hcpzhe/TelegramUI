import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChatTitleView: UIView {
    private let titleNode: ASTextNode
    private let infoNode: ASTextNode
    private let button: HighlightTrackingButton
    
    private var presenceManager: PeerPresenceStatusManager?
    
    var pressed: (() -> Void)?
    
    var peerView: PeerView? {
        didSet {
            if let peerView = self.peerView, let peer = peerView.peers[peerView.peerId] {
                let string = NSAttributedString(string: peer.displayTitle, font: Font.medium(17.0), textColor: UIColor.black)
                
                if self.titleNode.attributedText == nil || !self.titleNode.attributedText!.isEqual(to: string) {
                    self.titleNode.attributedText = string
                    self.setNeedsLayout()
                }
                
                self.updateStatus()
            }
        }
    }
    
    private func updateStatus() {
        var shouldUpdateLayout = false
        if let peerView = self.peerView, let peer = peerView.peers[peerView.peerId] {
            if let user = peer as? TelegramUser {
                if let _ = user.botInfo {
                    let string = NSAttributedString(string: "bot", font: Font.regular(13.0), textColor: UIColor(0x787878))
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                } else if let presence = peerView.peerPresences[peerView.peerId] as? TelegramUserPresence {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    let (string, activity) = stringAndActivityForUserPresence(presence, relativeTo: Int32(timestamp))
                    let attributedString = NSAttributedString(string: string, font: Font.regular(13.0), textColor: activity ? UIColor(0x007ee5) : UIColor(0x787878))
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: attributedString) {
                        self.infoNode.attributedText = attributedString
                        shouldUpdateLayout = true
                    }
                    
                    self.presenceManager?.reset(presence: presence)
                } else {
                    let string = NSAttributedString(string: "offline", font: Font.regular(13.0), textColor: UIColor(0x787878))
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                }
            } else if let group = peer as? TelegramGroup {
                var onlineCount = 0
                if let cachedGroupData = peerView.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
                    let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
                    for participant in participants.participants {
                        if let presence = peerView.peerPresences[participant.peerId] as? TelegramUserPresence {
                            let relativeStatus = relativeUserPresenceStatus(presence, relativeTo: Int32(timestamp))
                            switch relativeStatus {
                                case .online:
                                    onlineCount += 1
                                default:
                                    break
                            }
                        }
                    }
                }
                if onlineCount > 1 {
                    let string = NSMutableAttributedString()
                    string.append(NSAttributedString(string: "\(group.participantCount) members, ", font: Font.regular(13.0), textColor: UIColor(0x787878)))
                    string.append(NSAttributedString(string: "\(onlineCount) online", font: Font.regular(13.0), textColor: UIColor(0x007ee5)))
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                } else {
                    let string = NSAttributedString(string: "\(group.participantCount) members", font: Font.regular(13.0), textColor: UIColor(0x787878))
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                }
            } else if let channel = peer as? TelegramChannel {
                if let cachedChannelData = peerView.cachedData as? CachedChannelData, let memberCount = cachedChannelData.participantsSummary.memberCount {
                    let string = NSAttributedString(string: "\(memberCount) members", font: Font.regular(13.0), textColor: UIColor(0x787878))
                    if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                        self.infoNode.attributedText = string
                        shouldUpdateLayout = true
                    }
                } else {
                    switch channel.info {
                        case .group:
                            let string = NSAttributedString(string: "group", font: Font.regular(13.0), textColor: UIColor(0x787878))
                            if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                                self.infoNode.attributedText = string
                                shouldUpdateLayout = true
                            }
                        case .broadcast:
                            let string = NSAttributedString(string: "channel", font: Font.regular(13.0), textColor: UIColor(0x787878))
                            if self.infoNode.attributedText == nil || !self.infoNode.attributedText!.isEqual(to: string) {
                                self.infoNode.attributedText = string
                                shouldUpdateLayout = true
                            }
                    }
                }
            }
            
            if shouldUpdateLayout {
                self.setNeedsLayout()
            }
        }
    }
    
    override init(frame: CGRect) {
        self.titleNode = ASTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        self.infoNode = ASTextNode()
        self.infoNode.displaysAsynchronously = false
        self.infoNode.maximumNumberOfLines = 1
        self.infoNode.truncationMode = .byTruncatingTail
        self.infoNode.isOpaque = false
        
        self.button = HighlightTrackingButton()
        
        super.init(frame: frame)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.infoNode)
        self.addSubview(self.button)
        
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            self?.updateStatus()
        })
        
        self.button.addTarget(self, action: #selector(buttonPressed), for: [.touchUpInside])
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.titleNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.infoNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.titleNode.alpha = 0.4
                    strongSelf.infoNode.alpha = 0.4
                } else {
                    strongSelf.titleNode.alpha = 1.0
                    strongSelf.infoNode.alpha = 1.0
                    strongSelf.titleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.infoNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let size = self.bounds.size
        
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        if size.height > 40.0 {
            let titleSize = self.titleNode.measure(size)
            let infoSize = self.infoNode.measure(size)
            let titleInfoSpacing: CGFloat = 0.0
            
            let combinedHeight = titleSize.height + infoSize.height + titleInfoSpacing
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0)), size: titleSize)
            self.infoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - infoSize.width) / 2.0), y: floor((size.height - combinedHeight) / 2.0) + titleSize.height + titleInfoSpacing), size: infoSize)
        } else {
            let titleSize = self.titleNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            let infoSize = self.infoNode.measure(CGSize(width: floor(size.width / 2.0), height: size.height))
            
            let titleInfoSpacing: CGFloat = 8.0
            let combinedWidth = titleSize.width + infoSize.width + titleInfoSpacing
            
            self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
            self.infoNode.frame = CGRect(origin: CGPoint(x: floor((size.width - combinedWidth) / 2.0 + titleSize.width + titleInfoSpacing), y: floor((size.height - infoSize.height) / 2.0)), size: infoSize)
        }
    }
    
    @objc func buttonPressed() {
        if let pressed = self.pressed {
            pressed()
        }
    }
}
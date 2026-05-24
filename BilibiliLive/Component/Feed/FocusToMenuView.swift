//
//  FouceToMenuView.swift
//  BilibiliLive
//
//  Created by mantieus on 2025/10/13.
//

import UIKit

class FocusToMenuView: UIButton {
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        
        if isFocused {
            NotificationCenter.default.post(name: EVENT_COLLECTION_TO_SHOW_MENU, object: nil)
        }
    }

}

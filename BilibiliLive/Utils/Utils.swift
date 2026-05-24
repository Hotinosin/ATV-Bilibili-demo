//
//  Utils.swift
//  BilibiliLive
//
//  Created by iManTie on 10/13/25.
//

import UIKit

public func BLAnimate(withDuration: CGFloat, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
    UIView.animate(withDuration: withDuration, delay: 0, options: .curveEaseIn, animations: animations, completion: completion)
}

public func BLAfter(afterTime: CGFloat, complete: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + afterTime, execute: {
        complete()
    })
}

public func getblurEffectView(style: UIBlurEffect.Style? = .light) -> UIVisualEffectView {
    // 首先创建一个模糊效果
    let blurEffect = UIBlurEffect(style: style!)
    // 接着创建一个承载模糊效果的视图
    let headView = UIVisualEffectView(effect: blurEffect)

    return headView
}

/// 同心圆算法计算圆角
/// - Parameters:
///   - parentRadius: 父view的圆角
///   - inset: 内缩像素
/// - Returns: 内缩后的圆角
func concentricCornerRadius(parentRadius: CGFloat, inset: CGFloat) -> CGFloat {
    return sqrt(parentRadius * parentRadius - 2 * parentRadius * inset + inset * inset)
}


/// 序列动画
/// - Parameters:
///   - animations: codes
///   - delay: 时间
func animateSequentially(_ steps: [() -> Void], delay: TimeInterval = 0.15) {
    for (i, step) in steps.enumerated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay * Double(i)) {
            UIView.animate(withDuration: 0.6,
                           delay: 0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0.6,
                           options: [.curveEaseOut],
                           animations: {
                               step()
                           })
        }
    }
}

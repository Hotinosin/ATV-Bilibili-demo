//
//  BannerView.swift
//  BilibiliLive
//
//  Created by iManTie on 10/11/25.
//

import Kingfisher
import SwiftUI

enum FocusItem {
    case leftButton
    case rightButton
    case focusGuide
    case leftGuide
}

struct BannerView: View {
    @ObservedObject var viewModel: BannerViewModel
    @State private var lastChangeTime = Date()
    @FocusState var focusedItem: FocusItem? // 当前焦点对象
    @State private var currentFocusedItem: FocusItem? // 当前焦点对象
    @State private var selectIndex = 0

    var showLoalData = 0

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    // 例如显示加载数据
                    LazyHStack(spacing: 0) {
                        ForEach(viewModel.favdatas, id: \.id) { item in

//                            Image("cover")

                            ItemPhoto(Photo(item.cover))
                                .id(item.id)
                        }
                    }
                }
                .frame(width: 1920)
                .scrollTargetBehavior(.paging)
                .onChange(of: viewModel.currentIndex) { _, newValue in
                    withAnimation(.easeInOut(duration: 0.8)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    } completion: {
                        BLAfter(afterTime: 1) {
                            viewModel.isAnimate = true
                        }
                    }
                }
            }

//            // 底部渐变遮罩
//            LinearGradient(
//                colors: [.black.opacity(0.9), .clear],
//                startPoint: .bottom,
//                endPoint: .top
//            )
//            .ignoresSafeArea()

            Image("showBg")

            // 用于转移焦点的button
            Button {
                print("用来做左侧菜单来的焦点转移")
            } label: {
                Image(systemName: "info.circle")
                    .frame(maxHeight: .infinity)
            }
            .focused($focusedItem, equals: .leftGuide) // 与 @FocusState 绑定
            .opacity(0)
            .padding(.leading, 500)
            .padding(.bottom, 450)

            // infoView 显示视频信息
            infoView(viewModel: viewModel, focusedItem: _focusedItem)

            Button {
                print("用来做下方上来的焦点转移")
            } label: {
                Image(systemName: "info.circle")
                    .frame(maxWidth: .infinity)
            }
            .focused($focusedItem, equals: .focusGuide) // 与 @FocusState 绑定
            .opacity(0)
            .padding(.leading, 400)
            .onChange(of: focusedItem) { _, _ in
                viewModel.focusedBannerButton?()
                if focusedItem == .focusGuide
                    || focusedItem == .leftGuide {
                    focusedItem = .leftButton
                }
            }
        }
        .onAppear {
            if showLoalData == 1 {
                viewModel.createDatas()
            } else {
                Task {
                    try await viewModel.loadFavList(isReset: false)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedItem = .leftButton
            }
        }
        .onMoveCommand { direction in
            // 控制封面的左右移动
            switch direction {
            case .left:
                print("向左")
                if currentFocusedItem == .leftButton {
                    // 在这里写你的动画逻辑，比如滚动或改变状态
                    selectIndex = selectIndex - 1
                    if selectIndex < 0 {
                        selectIndex = 0
                        viewModel.overMoveLeft?()
                    } else {
                        viewModel.isAnimate = false
                    }
                    print("向左切换\(selectIndex)")
                    viewModel.setIndex(index: selectIndex)
                }
            case .right:

                print("向右")

                if currentFocusedItem == .rightButton {
                    // 在这里写你的动画逻辑，比如滚动或改变状态
                    selectIndex = selectIndex + 1
                    if selectIndex >= viewModel.favdatas.count {
                        selectIndex = 0
                    }
                    viewModel.isAnimate = false
                    print("向右\(selectIndex)")

                    viewModel.setIndex(index: selectIndex)
                }

            default: break
            }

            currentFocusedItem = focusedItem
        }
        .onChange(of: viewModel.resetFouce) { _, _ in
            selectIndex = 0
            focusedItem = .leftButton
            currentFocusedItem = .leftGuide
        }
    }
}

struct infoView: View {
    @ObservedObject var viewModel: BannerViewModel
    @FocusState var focusedItem: FocusItem? // 当前焦点对象

    var body: some View {
        // 信息页面
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            if viewModel.isAnimate {
                let visualEffects = Text(viewModel.selectData?.title ?? "")
                    .customAttribute(EmphasisAttribute())
                    .foregroundStyle(.white)
                    .bold()

                Text("\(visualEffects)")
                    .font(.system(size: 55, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 6, x: 3, y: 3)
                    .overlay(
                        Text(viewModel.selectData?.title ?? "")
                            .font(.system(size: 55, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .blur(radius: 4)
                            .offset(x: 2, y: 2)
                            .mask(
                                LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                            )
                    )
                    .frame(maxWidth: 650, maxHeight: 140, alignment: .leading)
                    .transition(TextTransition())
                    .id(viewModel.selectData?.title)
            }

            // 作者 和 介绍
            VStack(alignment: .leading) {
                HStack(spacing: 12) {
                    KFImage(URL(string: viewModel.selectData?.upper.face ?? ""))
                        .resizable()
                        .fade(duration: 0.2)
                        .frame(width: 34, height: 34)
                        .cornerRadius(17)
                        .scaledToFill()
                        .clipped()

                    Text(viewModel.selectData?.upper.name ?? "")
                        .foregroundStyle(.white)
                }
                if let intro = viewModel.selectData?.intro {
                    Text(intro)
                        .font(.caption2)
                        .frame(maxWidth: 550, maxHeight: 200, alignment: .leading)
                        .foregroundStyle(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(viewModel.isAnimate ? 1 : 0) // 显示或隐藏
            .animation(.easeInOut(duration: 0.3), value: viewModel.isAnimate)

            HStack(spacing: 22) {
                if #available(tvOS 26.0, *) {
                    Button(action: {
                        if let data = viewModel.selectData {
                            viewModel.playAction?(data)
                        }
                    }) {
                        Label("播放", systemImage: "play.fill")
                            .padding(.horizontal, 33)
                            .foregroundColor(focusedItem == .leftButton ? .black : .white)
                    }
                    .glassEffect(.clear)
                    .focused($focusedItem, equals: .leftButton) // 与 @FocusState 绑定

                    Button {
                        if let data = viewModel.selectData {
                            viewModel.detailAction?(data)
                        }

                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(focusedItem == .rightButton ? .black : .white)
                    }
                    .glassEffect(.clear)
                    .focused($focusedItem, equals: .rightButton) // 与 @FocusState 绑定

                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                        .symbolEffect(.breathe)
                } else {
                    Button(action: {
                        if let data = viewModel.selectData {
                            viewModel.playAction?(data)
                        }
                    }) {
                        Label("播放", systemImage: "play.fill")
                            .padding(.horizontal, 33)
                    }
                    .focused($focusedItem, equals: .leftButton) // 与 @FocusState 绑定

                    Button {
                        if let data = viewModel.selectData {
                            viewModel.detailAction?(data)
                        }

                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .focused($focusedItem, equals: .rightButton) // 与 @FocusState 绑定

                    Image(systemName: "chevron.right")
                        .symbolEffect(.breathe)
                } // 默认焦点
            }
        }
        .padding(.leading, 98)
        .padding(.bottom, 220)
        .offset(y: viewModel.offsetY)
        .animation(.spring(response: 0.7, dampingFraction: 0.9), value: viewModel.offsetY)
    }
}

struct Photo: Identifiable {
    var title: String

    var id: Int = .random(in: 0 ... 100)

    init(_ title: String) {
        self.title = title
    }
}

struct ItemPhoto: View {
    var photo: Photo

    init(_ photo: Photo) {
        self.photo = photo
    }

    var body: some View {
        KFImage(URL(string: photo.title))
            .resizable()
            .fade(duration: 0.2)
            .scaledToFill()
            .frame(width: 1920, height: 1080)
            .clipped()
    }
}

struct EmphasisAttribute: TextAttribute {}

/// A text renderer that animates its content.
struct AppearanceEffectRenderer: TextRenderer, Animatable {
    /// The amount of time that passes from the start of the animation.
    /// Animatable.
    var elapsedTime: TimeInterval

    /// The amount of time the app spends animating an individual element.
    var elementDuration: TimeInterval

    /// The amount of time the entire animation takes.
    var totalDuration: TimeInterval

    var spring: Spring {
        .snappy(duration: elementDuration - 0.05, extraBounce: 0.4)
    }

    var animatableData: Double {
        get { elapsedTime }
        set { elapsedTime = newValue }
    }

    init(elapsedTime: TimeInterval, elementDuration: Double = 0.4, totalDuration: TimeInterval) {
        self.elapsedTime = min(elapsedTime, totalDuration)
        self.elementDuration = min(elementDuration, totalDuration)
        self.totalDuration = totalDuration
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for run in layout.flattenedRuns {
            if run[EmphasisAttribute.self] != nil {
                let delay = elementDelay(count: run.count)

                for (index, slice) in run.enumerated() {
                    // The time that the current element starts animating,
                    // relative to the start of the animation.
                    let timeOffset = TimeInterval(index) * delay

                    // The amount of time that passes for the current element.
                    let elementTime = max(0, min(elapsedTime - timeOffset, elementDuration))

                    // Make a copy of the context so that individual slices
                    // don't affect each other.
                    var copy = context
                    draw(slice, at: elementTime, in: &copy)
                }
            } else {
                // Make a copy of the context so that individual slices
                // don't affect each other.
                var copy = context
                // Runs that don't have a tag of `EmphasisAttribute` quickly
                // fade in.
                copy.opacity = UnitCurve.easeIn.value(at: elapsedTime / 0.2)
                copy.draw(run)
            }
        }
    }

    func draw(_ slice: Text.Layout.RunSlice, at time: TimeInterval, in context: inout GraphicsContext) {
        // Calculate a progress value in unit space for blur and
        // opacity, which derive from `UnitCurve`.
        let progress = time / elementDuration

        let opacity = UnitCurve.easeIn.value(at: 1.4 * progress)

        let blurRadius =
            slice.typographicBounds.rect.height / 16 *
            UnitCurve.easeIn.value(at: 1 - progress)

        // The y-translation derives from a spring, which requires a
        // time in seconds.
        let translationY = spring.value(
            fromValue: -slice.typographicBounds.descent,
            toValue: 0,
            initialVelocity: 0,
            time: time)

        context.translateBy(x: 0, y: translationY)
        context.addFilter(.blur(radius: blurRadius))
        context.opacity = opacity
        context.draw(slice, options: .disablesSubpixelQuantization)
    }

    /// Calculates how much time passes between the start of two consecutive
    /// element animations.
    ///
    /// For example, if there's a total duration of 1 s and an element
    /// duration of 0.5 s, the delay for two elements is 0.5 s.
    /// The first element starts at 0 s, and the second element starts at 0.5 s
    /// and finishes at 1 s.
    ///
    /// However, to animate three elements in the same duration,
    /// the delay is 0.25 s, with the elements starting at 0.0 s, 0.25 s,
    /// and 0.5 s, respectively.
    func elementDelay(count: Int) -> TimeInterval {
        let count = TimeInterval(count)
        let remainingTime = totalDuration - count * elementDuration

        return max(remainingTime / (count + 1), (totalDuration - elementDuration) / count)
    }
}

extension Text.Layout {
    /// A helper function for easier access to all runs in a layout.
    var flattenedRuns: some RandomAccessCollection<Text.Layout.Run> {
        self.flatMap { line in
            line
        }
    }

    /// A helper function for easier access to all run slices in a layout.
    var flattenedRunSlices: some RandomAccessCollection<Text.Layout.RunSlice> {
        flattenedRuns.flatMap(\.self)
    }
}

struct TextTransition: Transition {
    static var properties: TransitionProperties {
        TransitionProperties(hasMotion: true)
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        let duration = 0.9
        let elapsedTime = phase.isIdentity ? duration : 0
        let renderer = AppearanceEffectRenderer(
            elapsedTime: elapsedTime,
            totalDuration: duration
        )

        content.transaction { transaction in
            // Force the animation of `elapsedTime` to pace linearly and
            // drive per-glyph springs based on its value.
            if !transaction.disablesAnimations {
                transaction.animation = .linear(duration: duration)
            }
        } body: { view in
            view.textRenderer(renderer)
        }
    }
}

#Preview {
    @Previewable @StateObject var viewModel = BannerViewModel()
    BannerView(viewModel: viewModel, showLoalData: 1)
}

//
// Created by Yam on 2024/6/9.
//

import Alamofire
import Kingfisher
import UIKit

class ReplyDetailViewController: UIViewController {
    private var scrollView: UIScrollView!
    private var contentView: UIView!
    private var titleLabel: UILabel!
    private var rootReplyCell: CompactReplyCell!
    private var replyCollectionView: UICollectionView!
    private var imageStackView: UIStackView!
    private var buttonStackView: UIStackView!

    private let reply: Replys.Reply
    private let aid: Int
    private var childReplies: [Replys.Reply]
    private var nextPage = 1
    private var isLoadingReplies = false
    private var hasMoreReplies = true

    private var replyWidth: CGFloat { max(view.bounds.width, UIScreen.main.bounds.width) - 270 }

    private func replyHeight(_ reply: Replys.Reply, width: CGFloat) -> CGFloat {
        let textWidth = max(200, width - 790)
        let textHeight = (reply.content.message as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 24)], context: nil
        ).height
        return max(132, ceil(textHeight) + 40)
    }

    private var repliesHeight: CGFloat {
        childReplies.reduce(0) { $0 + replyHeight($1, width: replyWidth) } +
            CGFloat(max(0, childReplies.count - 1)) * 8
    }

    init(reply: Replys.Reply, aid: Int) {
        self.reply = reply
        self.aid = aid
        self.childReplies = reply.replies ?? []
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = UIColor(named: "mainBgColor") ?? .black
        view.isOpaque = true

        setUpViews()
        rootReplyCell.config(replay: reply)
        loadMoreReplies()

        reply.content.pictures?.compactMap { URL(string: $0.img_src) }.forEach { url in
            let imageView = UIImageView()
            imageView.kf.setImage(with: url)
            imageView.contentMode = .scaleAspectFit
            imageView.snp.makeConstraints { make in
                make.height.lessThanOrEqualTo(500)
            }
            imageStackView.addArrangedSubview(imageView)
        }

        reply.content.jump_url?.forEach { url, jump in
            Task { [weak self] in
                guard let bvId = await ReplyUrlBVParser.parser(url: url) else { return }
                guard let self else { return }
                let button = BLCustomTextButton()
                button.title = jump.title
                button.onPrimaryAction = { [weak self] _ in
                    self?.jumpLink(bvid: bvId)
                }
                buttonStackView.addArrangedSubview(button)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.layoutIfNeeded()
    }

    // MARK: - Private

    private func jumpLink(bvid: String) {
        let aid = BvidConvertor.bv2av(bvid: bvid)
        let detailVC = VideoDetailViewController.create(aid: Int(aid), cid: nil)
        detailVC.present(from: self)
    }

    private func loadMoreReplies() {
        guard let root = reply.rpid, hasMoreReplies, !isLoadingReplies else { return }
        isLoadingReplies = true
        WebRequest.requestChildReplies(aid: aid, root: root, page: nextPage) { [weak self] result in
            guard let self else { return }
            self.isLoadingReplies = false
            guard case let .success(data) = result else { return }
            let pageReplies = data.replies ?? []
            if self.nextPage == 1 { self.childReplies.removeAll() }
            self.childReplies.append(contentsOf: pageReplies)
            self.hasMoreReplies = pageReplies.count == 20
            self.nextPage += 1
            self.replyCollectionView.snp.updateConstraints { make in
                make.height.equalTo(self.repliesHeight)
            }
            self.replyCollectionView.reloadData()
        }
    }

    private func setUpViews() {
        scrollView = {
            let scroll = UIScrollView()
            view.addSubview(scroll)
            scroll.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            scroll.delegate = self
            return scroll
        }()

        contentView = {
            let view = UIView()
            scrollView.addSubview(view)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
                make.width.equalToSuperview()
            }
            return view
        }()

        titleLabel = {
            let label = UILabel()
            contentView.addSubview(label)
            label.font = .boldSystemFont(ofSize: 60)
            label.text = "评论详情"

            label.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.top.equalToSuperview().offset(20)
            }

            return label
        }()

        rootReplyCell = {
            let cell = CompactReplyCell(frame: .zero)
            cell.showsFullText = true
            contentView.addSubview(cell)
            cell.snp.makeConstraints { make in
                make.top.equalTo(self.titleLabel.snp.bottom).offset(60)
                make.leading.trailing.equalToSuperview().inset(100)
                make.height.equalTo(self.replyHeight(self.reply, width: max(self.view.bounds.width, UIScreen.main.bounds.width) - 200))
            }
            return cell
        }()

        imageStackView = {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.distribution = .fillEqually
            stackView.spacing = 10
            contentView.addSubview(stackView)

            stackView.snp.makeConstraints { make in
                make.top.equalTo(self.rootReplyCell.snp.bottom).offset(32)
                make.leading.trailing.equalToSuperview().inset(100)
            }
            return stackView
        }()

        buttonStackView = {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.alignment = .leading
            stackView.spacing = 10
            stackView.distribution = .equalSpacing
            contentView.addSubview(stackView)
            stackView.snp.makeConstraints { make in
                make.top.equalTo(self.imageStackView.snp.bottom).offset(60)
                make.leading.equalTo(contentView.snp.leadingMargin)
                make.trailing.lessThanOrEqualTo(contentView.snp.trailingMargin)
            }
            return stackView
        }()

        replyCollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.minimumLineSpacing = 8
            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            contentView.addSubview(collectionView)
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.backgroundColor = .clear
            collectionView.clipsToBounds = false
            collectionView.isScrollEnabled = false
            collectionView.register(CompactReplyCell.self, forCellWithReuseIdentifier: CompactReplyCell.identifier)

            collectionView.snp.makeConstraints { make in
                make.leading.equalToSuperview().inset(170)
                make.trailing.equalToSuperview().inset(100)
                make.top.equalTo(self.buttonStackView.snp.bottom).offset(32)
                make.height.equalTo(self.repliesHeight)
                make.bottom.equalToSuperview().inset(60)
            }

            return collectionView
        }()
    }
}

extension ReplyDetailViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return childReplies.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CompactReplyCell.identifier, for: indexPath) as? CompactReplyCell else {
            fatalError("cell not found")
        }

        let child = childReplies[indexPath.row]
        cell.showsFullText = true
        let target = ([reply] + childReplies).first { $0.rpid == child.parent }?.member.uname
        cell.config(replay: child, replyTarget: child.content.message.hasPrefix("回复 @") ? nil : target)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: replyWidth, height: replyHeight(childReplies[indexPath.item], width: replyWidth))
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.scrollView,
              scrollView.contentOffset.y + scrollView.bounds.height > scrollView.contentSize.height - 400 else { return }
        loadMoreReplies()
    }
}

enum ReplyUrlBVParser {
    static func parser(url: String) async -> String? {
        if url.hasPrefix("BV"), url.count == 12 {
            return url
        }

        if url.hasPrefix("https://www.bilibili.com/video/") {
            guard let urlComponents = URLComponents(string: url)
            else { return nil }
            let path = urlComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let bvid = path.split(separator: "/").filter({ !$0.isEmpty }).last {
                return await parser(url: String(bvid))
            }
            return nil
        }

        // need to get 302 for real url
        if url.hasPrefix("https://b23.tv/") {
            if let realUrl = await AF.request(url, method: .head).serializingData().response.response?.url {
                return await parser(url: realUrl.absoluteString)
            }
        }

        return nil
    }
}

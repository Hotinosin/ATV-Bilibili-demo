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

    init(reply: Replys.Reply) {
        self.reply = reply
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpViews()
        rootReplyCell.config(replay: reply)

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
            Task {
                guard let bvId = await ReplyUrlBVParser.parser(url: url) else { return }
                let button = BLCustomTextButton()
                button.title = jump.title
                button.onPrimaryAction = { [weak self] _ in
                    self?.jumpLink(bvid: bvId)
                }
                buttonStackView.addArrangedSubview(button)
            }
        }
    }

    // MARK: - Private

    private func jumpLink(bvid: String) {
        let aid = BvidConvertor.bv2av(bvid: bvid)
        let detailVC = VideoDetailViewController.create(aid: Int(aid), cid: nil)
        detailVC.present(from: self)
    }

    private func setUpViews() {
        scrollView = {
            let scroll = UIScrollView()
            view.addSubview(scroll)
            scroll.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
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
            contentView.addSubview(cell)
            cell.snp.makeConstraints { make in
                make.top.equalTo(self.titleLabel.snp.bottom).offset(60)
                make.leading.trailing.equalToSuperview().inset(100)
                make.height.equalTo(108)
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
            let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                                heightDimension: .fractionalHeight(1)))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(1),
                                                                           heightDimension: .absolute(108)),
                                                           subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 8

            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
            contentView.addSubview(collectionView)
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.backgroundColor = .clear
            collectionView.clipsToBounds = false
            collectionView.isScrollEnabled = false
            collectionView.register(CompactReplyCell.self, forCellWithReuseIdentifier: CompactReplyCell.identifier)

            collectionView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(100)
                make.top.equalTo(self.buttonStackView.snp.bottom).offset(32)
                make.height.equalTo((self.reply.replies?.count ?? 0) * 116)
                make.bottom.equalToSuperview().inset(60)
            }

            return collectionView
        }()
    }
}

extension ReplyDetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return reply.replies?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CompactReplyCell.identifier, for: indexPath) as? CompactReplyCell else {
            fatalError("cell not found")
        }

        guard let reply = reply.replies?[indexPath.row] else {
            fatalError("reply not found")
        }

        cell.config(replay: reply)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let reply = reply.replies?[indexPath.item] else { return }
        let detail = ReplyDetailViewController(reply: reply)
        present(detail, animated: true)
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

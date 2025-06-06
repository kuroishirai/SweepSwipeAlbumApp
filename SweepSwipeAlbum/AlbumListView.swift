import SwiftUI
import Photos

extension PHAssetCollection {
    var japaneseLocalizedTitle: String {
        if self.assetCollectionType == .album {
            return self.localizedTitle ?? "名称未設定"
        }
        
        switch self.assetCollectionSubtype.rawValue {
        case 209: return "最近の項目"
        case 206: return "お気に入り"
        case 201: return "スクリーンショット"
        case 202: return "ビデオ"
        case 205: return "セルフィー"
        case 204: return "パノラマ"
        case 207: return "タイムラプス"
        case 208: return "スローモーション"
        case 203: return "バースト"
        case 210: return "Live Photos"
        case 212: return "アニメーション"
        case 213: return "長時間露光"
        case 214: return "被写界深度エフェクト"
        case 215: return "ポートレート"
        case 211: return "最近追加した項目"
        case 216: return "読み込み"
        case 1000000201: return "非表示"
        default:
            return self.localizedTitle ?? "名称未設定のアルバム"
        }
    }
}

struct AlbumListView: View {
    @EnvironmentObject var viewModel: PhotoViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var isMonthSectionExpanded = false
    @State private var isSmartAlbumSectionExpanded = false
    @State private var isMyAlbumSectionExpanded = false

    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Text("すべての写真")
                        Spacer()
                        Text("\(viewModel.totalPhotoCount)")
                            .foregroundColor(.gray)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selection = .allPhotos
                        presentationMode.wrappedValue.dismiss()
                    }
                }

                CollapsibleSection(title: "月別で整理", isExpanded: $isMonthSectionExpanded) {
                    ForEach(viewModel.sortedMonths, id: \.self) { month in
                        HStack {
                            Text(monthFormatter.string(from: month))
                            Spacer()
                            if let count = viewModel.monthlyGroupedAssets[month]?.count {
                                Text("\(count)")
                                    .foregroundColor(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selection = .month(month)
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }

                CollapsibleSection(title: "スマートアルバム", isExpanded: $isSmartAlbumSectionExpanded) {
                    ForEach(viewModel.albums.filter { $0.collection.assetCollectionType == .smartAlbum }, id: \.collection.localIdentifier) { albumInfo in
                        albumRow(for: albumInfo)
                    }
                }
                
                CollapsibleSection(title: "マイアルバム", isExpanded: $isMyAlbumSectionExpanded) {
                    ForEach(viewModel.albums.filter { $0.collection.assetCollectionType == .album }, id: \.collection.localIdentifier) { albumInfo in
                        albumRow(for: albumInfo)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("アルバムを選択")
            .navigationBarItems(trailing: Button("閉じる") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func albumRow(for albumInfo: AlbumInfo) -> some View {
        HStack {
            Text(albumInfo.collection.japaneseLocalizedTitle)
            Spacer()
            Text("\(albumInfo.count)")
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selection = .album(albumInfo.collection)
            presentationMode.wrappedValue.dismiss()
        }
    }
}

struct CollapsibleSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section {
            if isExpanded {
                content()
            }
        } header: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring()) {
                    isExpanded.toggle()
                }
            }
        }
    }
}

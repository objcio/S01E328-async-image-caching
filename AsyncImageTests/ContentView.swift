import SwiftUI

@MainActor
final class ImageLoader: ObservableObject {
    @Published private var _image: Image?

    func image(url: URL) -> Image? {
        if let i = _image { return i }

        if let resp = URLSession.shared.configuration.urlCache?.cachedResponse(for: .init(url: url)) {
            guard let nsImage = NSImage(data: resp.data) else { return nil }
            return Image(nsImage: nsImage)
        }

        return nil
    }

    func load(url: URL) async {
        do {
//            try await Task.sleep(nanoseconds: NSEC_PER_SEC*3)
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let nsImage = NSImage(data: data) else { return }
            _image = Image(nsImage: nsImage)
        } catch {
            print(error)
        }
    }

}

struct MyAsyncImage<Placeholder: View>: View {
    var url: URL
    @ViewBuilder var placeholder: Placeholder
    private var _resizable = false
    @StateObject private var loader = ImageLoader()

    init(url: URL, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
    }

    var body: some View {
        MyUnmanagedAsyncImage(url: url, loader: loader, resizable: _resizable, placeholder: { placeholder })
    }

    func resizable() -> Self {
        var copy = self
        copy._resizable = true
        return copy
    }
}

struct MyUnmanagedAsyncImage<Placeholder: View>: View {
    init(url: URL, loader: ImageLoader, resizable: Bool = false, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.placeholder = placeholder()
        self.loader = loader
        self._resizable = resizable
    }

    var url: URL
    @ViewBuilder var placeholder: Placeholder
    private var _resizable = false
    @ObservedObject private var loader: ImageLoader

    var body: some View {
        ZStack {
            if let image = loader.image(url: url) {
                if _resizable {
                    image.resizable()
                } else {
                    image
                }
            } else {
                let _ = print("Showing placeholder")
                placeholder

            }
        }.task(id: url) {
            await loader.load(url: url)
        }
    }

    func resizable() -> Self {
        var copy = self
        copy._resizable = true
        return copy
    }
}

var loaders: [URL: ImageLoader] = [:]

@MainActor
func loader(for url: URL) -> ImageLoader {
    if let l = loaders[url] {
        return l
    }
    let l = ImageLoader()
    loaders[url] = l
    return l
}


@MainActor
struct ContentView: View {
    @State var selectedPhoto: URL?

    func image(for url: URL) -> some View {
        MyAsyncImage(url: url, placeholder: {
            Color.gray
        })
        .resizable()
        .aspectRatio(contentMode: .fit)
    }

    var body: some View {
        if let url = selectedPhoto {
            image(for: url)
            .onTapGesture {
                selectedPhoto = nil
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [.init(.adaptive(minimum: 100))]) {
                    ForEach(Photo.sample) { photo in
                        let url = photo.urls.thumb
                        image(for: url)
                        .onTapGesture {
                            selectedPhoto = url
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

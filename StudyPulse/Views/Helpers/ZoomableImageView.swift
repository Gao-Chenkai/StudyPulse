//
//  ZoomableImageView.swift
//  StudyPulse
//
//  Created by Chenkai Gao on 2026/6/5.
//

import SwiftUI
import UIKit

struct ZoomableImageView: View {
    let image: UIImage
    @State private var showFullscreen = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .onTapGesture {
                showFullscreen = true
            }
            .sheet(isPresented: $showFullscreen) {
                FullscreenZoomableView(image: image)
            }
    }
}

private struct FullscreenZoomableView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            ZoomableScrollView(image: image)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(8)
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 8)
                }
                Spacer()
            }
        }
    }
}

private struct ZoomableScrollView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 5.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        // Double-tap gesture
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        if let imageView = scrollView.subviews.first as? UIImageView {
            imageView.image = image
            updateZoomScale(for: scrollView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func updateZoomScale(for scrollView: UIScrollView) {
        guard let imageView = scrollView.subviews.first as? UIImageView else { return }

        let imageViewSize = imageView.bounds.size
        let scrollViewSize = scrollView.bounds.size

        let widthScale = scrollViewSize.width / imageViewSize.width
        let heightScale = scrollViewSize.height / imageViewSize.height

        let minScale = min(widthScale, heightScale)

        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = 5.0
        scrollView.setZoomScale(minScale, animated: false)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.subviews.first
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let imageView = scrollView.subviews.first as? UIImageView else { return }

            let offsetX = (scrollView.bounds.width > scrollView.contentSize.width)
                ? (scrollView.bounds.width - scrollView.contentSize.width) * 0.5
                : 0.0

            let offsetY = (scrollView.bounds.height > scrollView.contentSize.height)
                ? (scrollView.bounds.height - scrollView.contentSize.height) * 0.5
                : 0.0

            imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                       y: scrollView.contentSize.height * 0.5 + offsetY)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let touchPoint = gesture.location(in: scrollView)
                let zoomRect = CGRect(
                    x: touchPoint.x - scrollView.bounds.width / 4,
                    y: touchPoint.y - scrollView.bounds.height / 4,
                    width: scrollView.bounds.width / 2,
                    height: scrollView.bounds.height / 2
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}

#if DEBUG
#Preview {
    ZoomableImageView(image: UIImage(systemName: "photo.fill")!)
}
#endif

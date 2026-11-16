import Vision

/// Decodes the first QR code in `image`, fully on-device. nil if none found.
func decodeQR(_ image: CGImage) -> String? {
    let request = VNDetectBarcodesRequest()
    request.symbologies = [.qr]
    do { try VNImageRequestHandler(cgImage: image, options: [:]).perform([request]) } catch { return nil }
    return request.results?.first?.payloadStringValue
}

/// Only http(s) links are opened automatically; anything else (file:, custom schemes, plain text) is shown only.
func openableURL(_ text: String) -> URL? {
    guard let url = URL(string: text), url.host != nil,
          ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
    return url
}

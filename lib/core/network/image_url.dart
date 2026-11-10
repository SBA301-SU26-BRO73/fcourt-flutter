/// Hosts that only exist on a developer machine (local MinIO / LocalStack).
/// `10.0.2.2` is the host machine seen from the Android emulator.
const _loopbackHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

/// Whether [uri] is an image URL the app may load without credentials.
///
/// Images are stored in S3 and served through CloudFront or presigned S3 URLs, so the host is
/// whatever the server issued; legacy rows may still point at `res.cloudinary.com`. Accepted:
/// HTTPS on the default port, or plain HTTP on a loopback host (local MinIO, mirroring the
/// backend's own review-image policy). Userinfo and fragments are always rejected. The query
/// string is kept because presigned URLs carry their signature there.
bool isAllowedImageUrl(Uri? uri) {
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return false;
  if (uri.fragment.isNotEmpty) return false;
  if (uri.scheme == 'https') return !uri.hasPort || uri.port == 443;
  return uri.scheme == 'http' &&
      _loopbackHosts.contains(uri.host.toLowerCase());
}

/// Parses [value] and returns it only when [isAllowedImageUrl] accepts it.
Uri? parseAllowedImageUrl(String? value) {
  if (value == null || value.isEmpty || value.length > 4096) return null;
  final uri = Uri.tryParse(value);
  return isAllowedImageUrl(uri) ? uri : null;
}

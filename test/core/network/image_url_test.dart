import 'package:fcourt/core/network/image_url.dart';
import 'package:fcourt/features/reviews/domain/review.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts S3, CloudFront, legacy Cloudinary and local MinIO URLs', () {
    for (final url in [
      'https://fcourt-prod.s3.ap-southeast-1.amazonaws.com/receipts/a.jpg?X-Amz-Signature=abc',
      'https://d111111abcdef8.cloudfront.net/branches/26/a.png',
      'https://res.cloudinary.com/demo/image/upload/a.jpg',
      'http://127.0.0.1:9000/fcourt-local/reviews/23/a.jpg',
      'http://localhost:9000/fcourt-local/avatars/a.jpg',
      'http://10.0.2.2:9000/fcourt-local/branches/26/a.jpg',
    ]) {
      expect(parseAllowedImageUrl(url), isNotNull, reason: url);
    }
  });

  test(
    'rejects credentials, plain remote HTTP, custom ports and fragments',
    () {
      for (final url in [
        'http://bucket.example/a.jpg',
        'https://user:pw@bucket.example/a.jpg',
        'https://res.cloudinary.com@evil.example/a.jpg',
        'https://bucket.example:8443/a.jpg',
        'https://bucket.example/a.jpg#x',
        'ftp://bucket.example/a.jpg',
        'javascript:alert(1)',
        '',
      ]) {
        expect(parseAllowedImageUrl(url), isNull, reason: url);
      }
      expect(isAllowedImageUrl(null), isFalse);
    },
  );

  test('review images follow the same rule as discovery-service', () {
    expect(
      validReviewImageUrl('http://127.0.0.1:9000/fcourt-local/reviews/1/a.jpg'),
      isTrue,
    );
    expect(validReviewImageUrl('http://evil.example/reviews/1/a.jpg'), isFalse);
  });
}

import 'package:url_launcher/url_launcher.dart';
import '../domain/subscription.dart';

class DeviceSubscriptionCheckoutLauncher implements SubscriptionCheckoutLauncher {
  const DeviceSubscriptionCheckoutLauncher();
  @override
  Future<bool> open(Uri url) async {
    if (!validPayosCheckout(url)) return false;
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

import 'dart:js_interop';

@JS('altrobyteCashfreeCheckout')
external void _altrobyteCashfreeCheckout(JSString sessionId, JSString mode);

/// Cashfree's Orders API payment_session_id only works via their JS
/// Checkout SDK (see web/index.html) — a raw redirect URL to their hosted
/// page is rejected as "client session is invalid" regardless of how fresh
/// the order is. This is the only reliable way to open the payment page.
class CashfreeCheckout {
  static void open({required String paymentSessionId, required String mode}) {
    _altrobyteCashfreeCheckout(paymentSessionId.toJS, mode.toJS);
  }
}

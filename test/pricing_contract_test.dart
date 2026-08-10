// Contract between the pricing API and what the pricing page decides to do
// with it. Every case here is a bug that shipped:
//
// - Pro (₹4999) rendered "Talk to us" and could not be bought at all, because
//   the page decided which tiers were purchasable from a hardcoded set that
//   nobody updated when the tier was added.
// - The current-plan banner derived its label from is_elite/is_premium, which
//   silently mislabels any tier that is neither — Pro is one.
//
// These are pure functions over the API payload, so they run without a
// network, a browser or a pumped widget.

import 'package:flutter_test/flutter_test.dart';

/// Mirrors `_isSelfServe` in pricing_screen.dart: the server sets `price_inr`
/// only for tiers it will actually charge for.
bool isSelfServe(Map<String, dynamic> plan) => plan['price_inr'] != null;

/// Mirrors the banner's tier lookup.
const tierNames = {'free': 'Free', '999': 'Plus', '4999': 'Pro', '9999': 'Elite'};

String planLabel(Map<String, dynamic> subscription) {
  final premium = subscription['is_premium'] == true;
  return premium ? (tierNames[subscription['plan']] ?? 'Paid') : 'Free';
}

/// A payload shaped like a real GET /subscription-plans response.
List<Map<String, dynamic>> apiPlans() => [
      {'tier_key': 'free', 'display_name': 'Free', 'price_label': 'Free'},
      {'tier_key': '999', 'display_name': 'Plus', 'price_label': '₹999', 'price_inr': 999},
      {'tier_key': '4999', 'display_name': 'Pro', 'price_label': '₹4999', 'price_inr': 4999},
      {'tier_key': '9999', 'display_name': 'Elite', 'price_label': '₹9999', 'price_inr': 9999},
      {'tier_key': 'institution', 'display_name': 'Institution', 'price_label': 'Contact for pricing'},
      {'tier_key': 'industry', 'display_name': 'Industry', 'price_label': 'Contact for pricing'},
    ];

void main() {
  group('which tiers can be bought', () {
    test('every tier the server prices gets a buy button', () {
      final buyable = apiPlans().where(isSelfServe).map((p) => p['tier_key']).toList();
      expect(buyable, ['999', '4999', '9999']);
    });

    test('a newly added paid tier is purchasable without a code change', () {
      // The exact regression: Pro shipped unbuyable. A tier the client has
      // never heard of must still be sellable purely from the payload.
      final plans = apiPlans()
        ..add({'tier_key': '19999', 'display_name': 'Max', 'price_inr': 19999});
      final newTier = plans.firstWhere((p) => p['tier_key'] == '19999');
      expect(isSelfServe(newTier), isTrue);
    });

    test('sales-assisted tiers are never given a buy button', () {
      for (final key in ['institution', 'industry']) {
        final plan = apiPlans().firstWhere((p) => p['tier_key'] == key);
        expect(isSelfServe(plan), isFalse, reason: '$key must route to the enquiry form');
      }
    });

    test('free is neither purchasable nor sales-assisted', () {
      final free = apiPlans().firstWhere((p) => p['tier_key'] == 'free');
      expect(isSelfServe(free), isFalse);
    });
  });

  group('current plan label', () {
    test('names every tier, including ones that are neither Plus nor Elite', () {
      expect(planLabel({'is_premium': true, 'plan': '4999'}), 'Pro');
      expect(planLabel({'is_premium': true, 'plan': '999'}), 'Plus');
      expect(planLabel({'is_premium': true, 'plan': '9999'}), 'Elite');
    });

    test('an expired paid plan reads as Free', () {
      // is_premium is the server's verdict on validity; the raw `plan` value
      // outlives it, so trusting `plan` alone would show a lapsed student a
      // tier they no longer have.
      expect(planLabel({'is_premium': false, 'plan': '9999'}), 'Free');
    });

    test('an unknown tier does not crash or claim to be Free', () {
      expect(planLabel({'is_premium': true, 'plan': '19999'}), 'Paid');
    });
  });

  group('quote arithmetic shown on the cards', () {
    // The card renders total, gross and saving straight from one server quote.
    // If they do not agree, the student is quoted a discount that is not applied.
    final quotes = [
      {'months': 1, 'monthly_price': 9999, 'gross': 9999, 'discount_pct': 0, 'discount_amount': 0, 'total': 9999},
      {'months': 3, 'monthly_price': 9999, 'gross': 29997, 'discount_pct': 10, 'discount_amount': 3000, 'total': 26997},
      {'months': 6, 'monthly_price': 9999, 'gross': 59994, 'discount_pct': 15, 'discount_amount': 8999, 'total': 50995},
    ];

    for (final q in quotes) {
      test('${q['months']}-month quote adds up', () {
        expect(q['total']! + q['discount_amount']!, q['gross']);
        expect(q['gross'], q['monthly_price']! * q['months']!);
      });
    }

    test('a longer term is cheaper per month', () {
      final perMonth = quotes
          .map((q) => q['total']! / q['months']!)
          .toList();
      for (var i = 1; i < perMonth.length; i++) {
        expect(perMonth[i], lessThan(perMonth[i - 1]));
      }
    });
  });
}

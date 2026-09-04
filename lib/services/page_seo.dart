import 'dart:html' as html;

/// One title and one description per page.
///
/// This is a single-page app: every route is served the same index.html, so
/// until now `/roadmap/product-engineering`, `/founder`, `/pricing` and
/// twenty-two other URLs in the sitemap all carried the same title and the
/// same meta description. Google renders the JavaScript, so it saw twenty-five
/// pages that looked like copies of each other and ranked them accordingly —
/// which is the likeliest reason the site does not rank for anything it
/// should.
///
/// Setting these at runtime fixes it for search. It does not fix link
/// previews: WhatsApp and LinkedIn read the HTML without running any script,
/// which is what the /s/ share pages on the backend exist for.
class PageSeo {
  static const _site = 'Altrobyte Lab';
  static const _origin = 'https://altrobytelab.com';

  /// Title and description for each route. Written to be read in a search
  /// result rather than in the tab: the first few words carry the thing
  /// somebody typed, and the rest earns the click.
  static const _pages = <String, (String, String)>{
    '/': (
      'Embedded Systems, IoT & PCB Training in Indore',
      'Learn embedded systems and IoT by building real industrial products — '
          'firmware, your own PCB, cloud and edge AI. Classroom and online, Indore.'
    ),
    '/program': (
      'Product Engineering Program — 4 Months, 3-4 Real Products',
      'A four-month embedded and IoT programme: design your own PCB, write the '
          'firmware, put it online and run a model on the device. 165 milestones.'
    ),
    '/roadmap': (
      'Embedded & IoT Roadmap — Every Stage, In Order',
      'The full path from Embedded C to Edge AI: what to learn, in what order, '
          'and what you build at each stage. 165 milestones, free to read.'
    ),
    '/pricing': (
      'Fees & Plans — Embedded and IoT Training',
      'Weekday, weekend and intensive tracks. Pay once or monthly, with a lab '
          'setup kit included when you pay in full.'
    ),
    '/founder': (
      'About Pawan Meena — Founder',
      'Embedded and IoT engineer: CAN telematics for Eicher Motors, faculty '
          'development for NIT Warangal, training at Banasthali Vidyapeeth.'
    ),
    '/about': (
      'About Altrobyte Lab',
      'We teach embedded systems, IoT and PCB design by building real '
          'industrial products, in Indore and online.'
    ),
    '/live-sessions': (
      'Live Workshops on Embedded Systems, IoT and Edge AI',
      'Hands-on workshops and free demo sessions on ESP32, STM32, PCB design, '
          'MQTT and edge AI. See what is coming up and register.'
    ),
    '/placements': (
      'Placements — Where Our Students Work',
      'Students who learned embedded systems and IoT here, and the companies '
          'they now build for.'
    ),
    '/clients': (
      'Clients — Industrial Automation and IoT Projects',
      'Companies we have built embedded and IoT products for, and the systems '
          'we delivered.'
    ),
    '/services': (
      'Embedded & IoT Product Development Services',
      'Firmware, PCB design, industrial automation and IoT product development '
          'for industry.'
    ),
    '/products': (
      'Our IoT and Embedded Products',
      'Products built at Altrobyte — telematics, industrial automation, '
          'connected devices and edge AI systems.'
    ),
    '/what-if': (
      'What If? — Explore Your Engineering Futures',
      'A live map of where you are in engineering and what changes if you '
          'choose differently. Embedded, VLSI, robotics, edge AI and more.'
    ),
    '/student/test-series': (
      'Free Embedded Systems & IoT Practice Tests',
      'Practice tests on embedded C, microcontrollers, Bluetooth, ADC and '
          'circuit design. Free, with instant scoring.'
    ),
    '/jobs': (
      'Embedded and IoT Job Updates',
      'Openings and internships in embedded systems, firmware, IoT and '
          'hardware, updated as we hear of them.'
    ),
    '/events': (
      'Events & Workshops',
      'Upcoming events, workshops and sessions on embedded systems, IoT and '
          'industrial automation.'
    ),
    '/contact': (
      'Contact Altrobyte Lab, Indore',
      'Talk to us about the programme, a workshop, or building an embedded or '
          'IoT product for your company.'
    ),
    '/institutes': (
      'For Colleges — Workshops and Faculty Development',
      'Workshops, training programmes and faculty development on IoT, embedded '
          'systems and industrial automation for colleges.'
    ),
    '/partner': (
      'Partner With Altrobyte Lab',
      'Work with us on training, product development or industrial automation.'
    ),
    '/blog': (
      'Embedded Systems and IoT, Written Down',
      'Notes on firmware, PCB design, protocols and edge AI from the work we do.'
    ),
    '/book': (
      'Book a Call — Embedded & IoT Programme',
      'Pick a time and talk to us about which track fits you.'
    ),
    '/terms': ('Terms of Use', 'Terms of use for Altrobyte Lab.'),
    '/privacy': ('Privacy Policy', 'How Altrobyte Lab handles your data.'),
    '/refunds': ('Refund Policy', 'Refund policy for Altrobyte Lab programmes.'),
  };

  /// Apply the title, description and canonical for a route.
  ///
  /// Unknown routes fall back to the site title rather than keeping whatever
  /// the previous page set — a stale title is worse than a generic one,
  /// because it is wrong rather than merely vague.
  static void apply(String location) {
    final path = location.split('?').first;
    final entry = _pages[path] ?? _matchPrefix(path);

    final title = entry == null ? _site : '${entry.$1} | $_site';
    html.document.title = title;
    _meta('description',
        entry?.$2 ?? 'Learn embedded systems, IoT and PCB design by building '
            'real products. Altrobyte Lab, Indore.');
    _canonical('$_origin$path');

    // og:title and og:url too. A crawler that does run scripts should not see
    // a page whose social tags describe a different page.
    _meta('og:title', title, property: true);
    _meta('og:url', '$_origin$path', property: true);
    if (entry != null) _meta('og:description', entry.$2, property: true);
  }

  /// `/roadmap/product-engineering` should read as the roadmap, not as an
  /// unknown page.
  static (String, String)? _matchPrefix(String path) {
    for (final e in _pages.entries) {
      if (e.key.length > 1 && path.startsWith('${e.key}/')) return e.value;
    }
    return null;
  }

  static void _meta(String name, String content, {bool property = false}) {
    final attr = property ? 'property' : 'name';
    var tag = html.document.querySelector('meta[$attr="$name"]');
    if (tag == null) {
      tag = html.MetaElement()..setAttribute(attr, name);
      html.document.head?.append(tag);
    }
    tag.setAttribute('content', content);
  }

  static void _canonical(String href) {
    var tag = html.document.querySelector('link[rel="canonical"]');
    if (tag == null) {
      tag = html.LinkElement()..rel = 'canonical';
      html.document.head?.append(tag);
    }
    tag.setAttribute('href', href);
  }
}

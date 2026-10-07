double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

class InvoiceItem {
  String description;
  String sac;
  double qty;
  double rate;
  double gstRate;
  InvoiceItem({this.description = '', this.sac = '', this.qty = 1, this.rate = 0, this.gstRate = 18});

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        description: j['description'] ?? '',
        sac: j['sac'] ?? '',
        qty: _d(j['qty']),
        rate: _d(j['rate']),
        gstRate: _d(j['gst_rate']),
      );

  Map<String, dynamic> toJson() =>
      {'description': description.trim(), 'sac': sac.trim(), 'qty': qty, 'rate': rate, 'gst_rate': gstRate};
}

class InvoicePayment {
  final int id;
  final double amount;
  final String paidOn;
  final String mode;
  final String reference;
  InvoicePayment({required this.id, required this.amount, required this.paidOn, this.mode = '', this.reference = ''});

  factory InvoicePayment.fromJson(Map<String, dynamic> j) => InvoicePayment(
        id: j['id'] ?? 0,
        amount: _d(j['amount']),
        paidOn: '${j['paid_on'] ?? ''}',
        mode: j['mode'] ?? '',
        reference: j['reference'] ?? '',
      );
}

class Invoice {
  final int id;
  final String invoiceNo;
  final int? studentId;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerAddress;
  final String customerGstin;
  final String customerState;
  final String issueDate;
  final String? dueDate;
  final List<InvoiceItem> items;
  final bool pricesIncludeTax;
  final bool interState;
  final double discount;
  final double subtotal;
  final double taxableTotal;
  final double cgstTotal;
  final double sgstTotal;
  final double igstTotal;
  final double roundOff;
  final double grandTotal;
  final double amountPaid;
  final double balance;
  final String status; // unpaid | partial | paid | cancelled
  final bool isOverdue;
  final String notes;
  final String shareUrl;
  final List<InvoicePayment> payments;

  Invoice({
    required this.id,
    required this.invoiceNo,
    this.studentId,
    required this.customerName,
    this.customerPhone = '',
    this.customerEmail = '',
    this.customerAddress = '',
    this.customerGstin = '',
    this.customerState = '',
    required this.issueDate,
    this.dueDate,
    this.items = const [],
    this.pricesIncludeTax = false,
    this.interState = false,
    this.discount = 0,
    this.subtotal = 0,
    this.taxableTotal = 0,
    this.cgstTotal = 0,
    this.sgstTotal = 0,
    this.igstTotal = 0,
    this.roundOff = 0,
    this.grandTotal = 0,
    this.amountPaid = 0,
    this.balance = 0,
    this.status = 'unpaid',
    this.isOverdue = false,
    this.notes = '',
    this.shareUrl = '',
    this.payments = const [],
  });

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
        id: j['id'] ?? 0,
        invoiceNo: j['invoice_no'] ?? '',
        studentId: j['student_id'],
        customerName: j['customer_name'] ?? '',
        customerPhone: j['customer_phone'] ?? '',
        customerEmail: j['customer_email'] ?? '',
        customerAddress: j['customer_address'] ?? '',
        customerGstin: j['customer_gstin'] ?? '',
        customerState: j['customer_state'] ?? '',
        issueDate: '${j['issue_date'] ?? ''}',
        dueDate: j['due_date']?.toString(),
        items: [for (final i in (j['items'] as List? ?? [])) InvoiceItem.fromJson(Map<String, dynamic>.from(i))],
        pricesIncludeTax: j['prices_include_tax'] == true,
        interState: j['inter_state'] == true,
        discount: _d(j['discount']),
        subtotal: _d(j['subtotal']),
        taxableTotal: _d(j['taxable_total']),
        cgstTotal: _d(j['cgst_total']),
        sgstTotal: _d(j['sgst_total']),
        igstTotal: _d(j['igst_total']),
        roundOff: _d(j['round_off']),
        grandTotal: _d(j['grand_total']),
        amountPaid: _d(j['amount_paid']),
        balance: _d(j['balance']),
        status: j['status'] ?? 'unpaid',
        isOverdue: j['is_overdue'] == true,
        notes: j['notes'] ?? '',
        shareUrl: j['share_url'] ?? '',
        payments: [
          for (final p in (j['payments'] as List? ?? [])) InvoicePayment.fromJson(Map<String, dynamic>.from(p))
        ],
      );

  bool get isCancelled => status == 'cancelled';
  bool get isPaid => status == 'paid';
  bool get canEdit => !isCancelled && amountPaid <= 0;
}

class InvoiceSummary {
  final double billed;
  final double collected;
  final double outstanding;
  final double overdue;
  const InvoiceSummary({this.billed = 0, this.collected = 0, this.outstanding = 0, this.overdue = 0});

  factory InvoiceSummary.fromJson(Map<String, dynamic> j) => InvoiceSummary(
        billed: _d(j['billed']),
        collected: _d(j['collected']),
        outstanding: _d(j['outstanding']),
        overdue: _d(j['overdue']),
      );
}

/// Seller details printed on every invoice (one set per institute).
class InvoiceSettings {
  Map<String, String> text;
  double defaultGstRate;
  InvoiceSettings({Map<String, String>? text, this.defaultGstRate = 18}) : text = text ?? {};

  static const textFields = [
    'business_name', 'address', 'city', 'state', 'pincode', 'gstin', 'pan', 'phone', 'email',
    'upi_id', 'upi_name', 'bank_account_name', 'bank_name', 'bank_account_no', 'bank_ifsc',
    'bank_branch', 'invoice_prefix', 'default_sac', 'terms', 'signatory',
  ];

  factory InvoiceSettings.fromJson(Map<String, dynamic> j) => InvoiceSettings(
        text: {for (final f in textFields) f: '${j[f] ?? ''}'},
        defaultGstRate: _d(j['default_gst_rate']) == 0 && j['default_gst_rate'] == null ? 18 : _d(j['default_gst_rate']),
      );

  String operator [](String key) => text[key] ?? '';

  Map<String, dynamic> toJson() => {...text, 'default_gst_rate': defaultGstRate};

  bool get hasGstin => (this['gstin']).trim().isNotEmpty;
  bool get hasUpi => (this['upi_id']).trim().isNotEmpty;
}

const indianStates = [
  'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa', 'Gujarat', 'Haryana',
  'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur',
  'Meghalaya', 'Mizoram', 'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana',
  'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Andaman and Nicobar Islands', 'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu', 'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Lakshadweep', 'Puducherry',
];

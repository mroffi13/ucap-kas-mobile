import '../../core/network/api_client.dart';
import '../models/cash_transaction.dart';

class AiQuotaStatus {
  final int used;
  final int limit;
  final int weeklyUsed;
  final int weeklyLimit;
  final int monthlyUsed;
  final int monthlyLimit;
  final bool isUnlimited;
  final String subscriptionTier;
  final String ownerId;

  const AiQuotaStatus({
    this.used = 0,
    this.limit = 15,
    this.weeklyUsed = 0,
    this.weeklyLimit = 4,
    this.monthlyUsed = 0,
    this.monthlyLimit = 15,
    this.isUnlimited = false,
    this.subscriptionTier = 'starter',
    this.ownerId = '',
  });

  int get weeklyRemaining =>
      (weeklyLimit - weeklyUsed).clamp(0, weeklyLimit);

  int get monthlyRemaining =>
      (monthlyLimit - monthlyUsed).clamp(0, monthlyLimit);

  String get summaryLabel {
    if (isUnlimited) return 'Tanpa Batas';
    return 'Minggu ini $weeklyUsed/$weeklyLimit · Bulan ini $monthlyUsed/$monthlyLimit';
  }

  factory AiQuotaStatus.fromJson(Map<String, dynamic> json) {
    final used = (json['used'] as num?)?.toInt() ?? 0;
    final limit = (json['limit'] as num?)?.toInt() ?? 15;
    return AiQuotaStatus(
      used: used,
      limit: limit,
      weeklyUsed: (json['weekly_used'] as num?)?.toInt() ?? used.clamp(0, 4),
      weeklyLimit: (json['weekly_limit'] as num?)?.toInt() ?? 4,
      monthlyUsed: (json['monthly_used'] as num?)?.toInt() ?? used,
      monthlyLimit: (json['monthly_limit'] as num?)?.toInt() ?? limit,
      isUnlimited: json['is_unlimited'] as bool? ?? false,
      subscriptionTier: json['subscription_tier'] as String? ?? 'starter',
      ownerId: json['owner_id'] as String? ?? '',
    );
  }
}

class VoiceAiResult {
  final String intent; // 'buku_kas' | 'kirim_invoice'
  final bool isInflow;
  final String title;
  final String category;
  final String paymentMethod;
  final String customerName;
  final String customerContact;
  final String dueDate;
  final String notes;
  final String transcript;
  final List<TransactionLineItem> items;
  final int totalAmount;
  final String provider;
  final AiQuotaStatus quota;

  const VoiceAiResult({
    required this.intent,
    required this.isInflow,
    required this.title,
    required this.category,
    required this.paymentMethod,
    required this.customerName,
    required this.customerContact,
    required this.dueDate,
    required this.notes,
    required this.transcript,
    required this.items,
    required this.totalAmount,
    required this.provider,
    required this.quota,
  });

  factory VoiceAiResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(TransactionLineItem.fromJson)
        .toList();
    final quotaMap = json['quota'];
    return VoiceAiResult(
      intent: json['intent'] as String? ?? 'buku_kas',
      isInflow: (json['type'] as String? ?? 'inflow') != 'outflow',
      title: json['title'] as String? ?? 'Catatan Suara AI',
      category: json['category'] as String? ?? 'Penjualan',
      paymentMethod: json['payment_method'] as String? ?? 'Tunai',
      customerName: json['customer_name'] as String? ?? '',
      customerContact: json['customer_contact'] as String? ?? '',
      dueDate: json['due_date'] as String? ?? 'Jatuh Tempo 7 Hari',
      notes: json['notes'] as String? ?? '',
      transcript: json['transcript'] as String? ?? '',
      items: items,
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? 'slang_engine',
      quota: quotaMap is Map<String, dynamic>
          ? AiQuotaStatus.fromJson(quotaMap)
          : const AiQuotaStatus(),
    );
  }
}

class ReceiptAiResult {
  final String storeName;
  final String category;
  final String paymentMethod;
  final List<TransactionLineItem> items;
  final int totalAmount;
  final String provider;
  final AiQuotaStatus quota;

  const ReceiptAiResult({
    required this.storeName,
    required this.category,
    required this.paymentMethod,
    required this.items,
    required this.totalAmount,
    this.provider = 'slang_engine',
    this.quota = const AiQuotaStatus(),
  });

  factory ReceiptAiResult.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final items = rawItems
        .whereType<Map<String, dynamic>>()
        .map(TransactionLineItem.fromJson)
        .toList();
    final quotaMap = json['quota'];
    return ReceiptAiResult(
      storeName: json['store_name'] as String? ?? 'Toko Belanja Struk',
      category: json['category'] as String? ?? 'Bahan Baku',
      paymentMethod: json['payment_method'] as String? ?? 'Tunai',
      items: items,
      totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? 'slang_engine',
      quota: quotaMap is Map<String, dynamic>
          ? AiQuotaStatus.fromJson(quotaMap)
          : const AiQuotaStatus(),
    );
  }

  ReceiptAiResult copyWith({
    String? storeName,
    String? category,
    String? paymentMethod,
    List<TransactionLineItem>? items,
    int? totalAmount,
    String? provider,
    AiQuotaStatus? quota,
  }) {
    return ReceiptAiResult(
      storeName: storeName ?? this.storeName,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      provider: provider ?? this.provider,
      quota: quota ?? this.quota,
    );
  }
}

abstract class AiRepository {
  Future<AiQuotaStatus> getQuota(String workspaceId);

  Future<VoiceAiResult> parseVoice({
    required String workspaceId,
    required String transcript,
    String audioBase64 = '',
    String mimeType = '',
  });

  Future<ReceiptAiResult> parseReceipt({
    required String workspaceId,
    String imageBase64 = '',
    String mimeType = 'image/jpeg',
    String hintText = '',
    String presetId = '',
  });
}

class RemoteAiRepository implements AiRepository {
  final ApiClient _apiClient;

  RemoteAiRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<AiQuotaStatus> getQuota(String workspaceId) async {
    final data = await _apiClient.getAuthenticated(
      '/api/v1/workspaces/$workspaceId/ai/quota',
    );
    return AiQuotaStatus.fromJson(data);
  }

  @override
  Future<VoiceAiResult> parseVoice({
    required String workspaceId,
    required String transcript,
    String audioBase64 = '',
    String mimeType = '',
  }) async {
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces/$workspaceId/ai/parse-voice',
      body: {
        'transcript': transcript,
        'audio_base64': audioBase64,
        'mime_type': mimeType,
      },
    );
    return VoiceAiResult.fromJson(data);
  }

  @override
  Future<ReceiptAiResult> parseReceipt({
    required String workspaceId,
    String imageBase64 = '',
    String mimeType = 'image/jpeg',
    String hintText = '',
    String presetId = '',
  }) async {
    final data = await _apiClient.postAuthenticated(
      '/api/v1/workspaces/$workspaceId/ai/parse-receipt',
      body: {
        'image_base64': imageBase64,
        'mime_type': mimeType,
        'hint_text': hintText,
        'preset_id': presetId,
      },
    );
    return ReceiptAiResult.fromJson(data);
  }
}

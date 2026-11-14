import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/rupiah_formatter.dart';

class Screen5UbahRincian extends StatefulWidget {
  const Screen5UbahRincian({super.key});

  @override
  State<Screen5UbahRincian> createState() => _Screen5UbahRincianState();
}

class _EditableDetailItem {
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController priceController;
  int quantity;
  int unitPrice;

  _EditableDetailItem({
    required String name,
    required this.quantity,
    required this.unitPrice,
  })  : nameController = TextEditingController(text: name),
        qtyController = TextEditingController(text: quantity.toString()),
        priceController = TextEditingController(
          text: _formatDots(unitPrice),
        );

  int get subtotal => quantity * unitPrice;

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }

  static String _formatDots(int value) {
    if (value <= 0) return '';
    final str = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}

class _Screen5UbahRincianState extends State<Screen5UbahRincian> {
  late final TextEditingController _storeController;
  late final TextEditingController _categoryController;
  late final List<_EditableDetailItem> _items;

  static const List<String> _presetCategories = [
    'Bahan Baku',
    'Servis',
    'Suku Cadang',
    'Operasional',
    'Lainnya',
  ];

  @override
  void initState() {
    super.initState();
    _storeController =
        TextEditingController(text: 'Toko Bahan Kue Berkah Jaya');
    _categoryController = TextEditingController(text: 'Bahan Baku');
    _items = [
      _EditableDetailItem(
        name: 'Tepung Terigu Cakra 25kg',
        quantity: 1,
        unitPrice: 245000,
      ),
      _EditableDetailItem(
        name: 'Gula Pasir Gulaku 10kg',
        quantity: 1,
        unitPrice: 165000,
      ),
      _EditableDetailItem(
        name: 'Ragi Instan Fermipan & Plastik',
        quantity: 2,
        unitPrice: 20000,
      ),
    ];
  }

  @override
  void dispose() {
    _storeController.dispose();
    _categoryController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int get _grandTotal => _items.fold(0, (sum, item) => sum + item.subtotal);

  void _updateQty(int index, int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      final current = _items[index];
      final nextQty = (current.quantity + delta).clamp(1, 999);
      current.quantity = nextQty;
      final text = nextQty.toString();
      current.qtyController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _onQtyTextChanged(int index, String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean) ?? 0;
    setState(() {
      _items[index].quantity = parsed.clamp(0, 999);
    });
  }

  void _onPriceTextChanged(int index, String raw) {
    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(clean) ?? 0;
    setState(() {
      _items[index].unitPrice = parsed.clamp(0, 999999999);
    });
  }

  void _addDummyItem() {
    HapticFeedback.selectionClick();
    setState(() {
      _items.add(
        _EditableDetailItem(
          name: 'Mentega Blueband 2kg',
          quantity: 1,
          unitPrice: 65000,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentCategory = _categoryController.text.trim();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Text(
          'Ubah Rincian Barang',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton.icon(
              onPressed: _addDummyItem,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(
                'Barang',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
        children: [
          // Store & Editable Category Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nama Toko / Keperluan',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _storeController,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Kategori',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _categoryController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.label_outline_rounded,
                      size: 16,
                      color: AppColors.primaryTeal,
                    ),
                    hintText: 'Ketik atau pilih kategori',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _presetCategories.map((cat) {
                    final selected =
                        currentCategory.toLowerCase() == cat.toLowerCase();
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _categoryController.value = TextEditingValue(
                            text: cat,
                            selection: TextSelection.collapsed(
                              offset: cat.length,
                            ),
                          );
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.heroDark
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? AppColors.heroDark
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w500,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Items
          for (int i = 0; i < _items.length; i++) ...[
            _buildItemCard(i, _items[i]),
            const SizedBox(height: 10),
          ],

          // Add Row CTA
          GestureDetector(
            onTap: _addDummyItem,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              alignment: Alignment.center,
              child: Text(
                '+ Tambah Baris Barang Lainnya',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTeal,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Grand Total Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.heroDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Belanja Terhitung',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.darkTextMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_items.length} Barang · ${_categoryController.text.trim().isEmpty ? "Lainnya" : _categoryController.text.trim()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  RupiahFormatter.format(_grandTotal),
                  style: AppTheme.numStyle(
                    fontSize: 18,
                    color: AppColors.incomeEmeraldBright,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => context.go('/dashboard'),
              child: Text(
                'Simpan Perubahan & Catat Kas',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, _EditableDetailItem item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Barang ${index + 1}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              if (_items.length > 1)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      final removed = _items.removeAt(index);
                      removed.dispose();
                    });
                  },
                  child: Text(
                    'Hapus',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.expenseRose,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: item.nameController,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Qty Stepper + Editable TextField
              Container(
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _updateQty(index, -1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Icon(Icons.remove_rounded, size: 14),
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: TextField(
                        controller: item.qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        onChanged: (v) => _onQtyTextChanged(index, v),
                        style: AppTheme.numStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _updateQty(index, 1),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Icon(Icons.add_rounded, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Editable Unit Price
              Expanded(
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Rp',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: TextField(
                          controller: item.priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            _DetailDotSeparatorFormatter(),
                          ],
                          onChanged: (v) => _onPriceTextChanged(index, v),
                          style: AppTheme.numStyle(
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            hintText: '0',
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                RupiahFormatter.format(item.subtotal),
                style: AppTheme.numStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailDotSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final limited =
        digitsOnly.length > 9 ? digitsOnly.substring(0, 9) : digitsOnly;
    final parsed = int.tryParse(limited) ?? 0;
    if (parsed == 0) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final str = parsed.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

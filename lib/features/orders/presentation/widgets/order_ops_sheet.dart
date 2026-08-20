import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/orders/models/order.dart';
import 'package:merchant_app/features/orders/providers/order_provider.dart';
import 'package:merchant_app/core/errors/app_failure.dart';

/// Kitchen controls for a live order: buy more prep time and flag items that
/// cannot be made. Both go to `PUT /restaurant/orders/{id}/ops` together.
class OrderOpsSheet extends ConsumerStatefulWidget {
  const OrderOpsSheet({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<OrderOpsSheet> createState() => _OrderOpsSheetState();
}

class _OrderOpsSheetState extends ConsumerState<OrderOpsSheet> {
  static const _step = 5;
  static const _minAdjustment = -15;
  static const _maxAdjustment = 60;

  late int _adjustment = widget.order.prepTimeAdjustmentMin;
  late final Set<String> _oos = widget.order.oosItemIds.toSet();
  bool _isLoading = false;

  int get _eta => widget.order.originalEtaMin + _adjustment;

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(orderProvider.notifier).updateOps(
            id: widget.order.id,
            prepTimeAdjustmentMin: _adjustment,
            oosItemIds: _oos.toList(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('อัปเดตออเดอร์แล้ว'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        // viewInsets = keyboard, viewPadding = system nav — clear both.
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).viewPadding.bottom +
            24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ปรับออเดอร์ #${widget.order.shortId}',
            style: AppTypography.heading6
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
          ),
          const SizedBox(height: 24),

          // ─── Prep time ──────────────────────────────────────
          Text(
            'เวลาเตรียมเพิ่มเติม',
            style: AppTypography.label2
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _stepButton(
                label: '−$_step',
                onPressed: _adjustment <= _minAdjustment
                    ? null
                    : () => setState(() => _adjustment -= _step),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _adjustment == 0
                          ? 'ไม่ปรับ'
                          : '${_adjustment > 0 ? '+' : ''}$_adjustment นาที',
                      style: AppTypography.heading5.copyWith(
                        color: _adjustment == 0
                            ? AppColors.semanticGrayNeutralFgMidOnWhite
                            : AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ลูกค้าจะเห็นเวลา $_eta นาที',
                      style: AppTypography.caption5.copyWith(
                        color: AppColors.semanticGrayNeutralFgMidOnWhite,
                      ),
                    ),
                  ],
                ),
              ),
              _stepButton(
                label: '+$_step',
                onPressed: _adjustment >= _maxAdjustment
                    ? null
                    : () => setState(() => _adjustment += _step),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Out of stock ───────────────────────────────────
          Text(
            'รายการที่ของหมด',
            style: AppTypography.label2
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกรายการที่ทำไม่ได้ ระบบจะแจ้งลูกค้าให้',
            style: AppTypography.caption5
                .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final item in widget.order.items)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _oos.contains(item.id),
                      activeColor: AppColors.primary,
                      title: Text(
                        '${item.quantity}× ${item.name}',
                        style: AppTypography.body2.copyWith(
                          color: AppColors.semanticGrayNeutralFgHigh,
                        ),
                      ),
                      onChanged: _isLoading
                          ? null
                          : (checked) => setState(() {
                                if (checked ?? false) {
                                  _oos.add(item.id);
                                } else {
                                  _oos.remove(item.id);
                                }
                              }),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'บันทึก',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepButton({required String label, VoidCallback? onPressed}) {
    return SizedBox(
      width: 56,
      child: OutlinedButton(
        onPressed: _isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.label2.copyWith(
            color: onPressed == null
                ? const Color(0xFFCBD5E1)
                : AppColors.semanticGrayNeutralFgHigh,
          ),
        ),
      ),
    );
  }
}

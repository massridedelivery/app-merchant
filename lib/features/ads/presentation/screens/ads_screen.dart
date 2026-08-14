import 'package:flutter/material.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/ads/providers/ad_provider.dart';
import 'package:merchant_app/core/errors/failure_snack_bar.dart';

class AdsScreen extends ConsumerStatefulWidget {
  const AdsScreen({super.key});

  @override
  ConsumerState<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends ConsumerState<AdsScreen> {
  final _budgetController = TextEditingController();
  final _bidController = TextEditingController();
  bool _isActive = false;

  @override
  Widget build(BuildContext context) {
    final adState = ref.watch(adProvider);

    return Scaffold(
      appBar: AppBar(title: Text('การโฆษณา', style: AppTypography.heading5.copyWith(color: AppColors.semanticGrayNeutralFgWhite))),
      body: adState.when(
        loading: () => const Center(child: MassLoadingM(size: 72)),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e', style: AppTypography.body1.copyWith(color: AppColors.semanticErrorFgHigh))),
        data: (ad) {
          if (ad != null && _budgetController.text.isEmpty) {
            _budgetController.text = ad.dailyBudget.toString();
            _bidController.text = ad.bidPerClick.toString();
            _isActive = ad.isActive;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ad != null) _buildStatsCard(ad),
                const SizedBox(height: 24),
                Text('การตั้งค่าแคมเปญ', style: AppTypography.heading5.copyWith(color: AppColors.semanticGrayNeutralFgWhite)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _budgetController,
                  style: AppTypography.body1.copyWith(color: AppColors.semanticGrayNeutralFgWhite),
                  decoration: const InputDecoration(labelText: 'งบประมาณรายวัน (บาท)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bidController,
                  style: AppTypography.body1.copyWith(color: AppColors.semanticGrayNeutralFgWhite),
                  decoration: const InputDecoration(labelText: 'ราคาประมูลต่อคลิก (บาท)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                if (ad != null)
                  SwitchListTile(
                    title: Text('เปิดใช้งานแคมเปญ', style: AppTypography.body1.copyWith(color: AppColors.semanticGrayNeutralFgWhite)),
                    value: _isActive,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() => _isActive = val);
                    },
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    final budget = double.tryParse(_budgetController.text) ?? 0;
                    final bid = double.tryParse(_bidController.text) ?? 0;

                    if (ad == null) {
                      runGuarded(context,
                          () => ref.read(adProvider.notifier)
                              .createAd(budget, bid),
                          successMessage: 'สร้างแคมเปญแล้ว');
                    } else {
                      runGuarded(context,
                          () => ref.read(adProvider.notifier)
                              .updateAd(budget, bid, _isActive),
                          successMessage: 'บันทึกแคมเปญแล้ว');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.semanticSuccessBgHigh,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(ad == null ? 'สร้างแคมเปญ' : 'บันทึกการเปลี่ยนแปลง', style: AppTypography.label2.copyWith(color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsCard(ad) {
    return Card(
      color: AppColors.foundationGrayscale1300,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.foundationGrayscale1100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('ค่าโฆษณาวันนี้', style: AppTypography.body3.copyWith(color: AppColors.semanticGrayNeutralFgLowOnWhite)),
            Text('฿${ad.currentSpend}', style: AppTypography.heading4.copyWith(color: AppColors.primary)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ad.dailyBudget > 0 ? (ad.currentSpend / ad.dailyBudget).clamp(0.0, 1.0) : 0,
              backgroundColor: AppColors.foundationGrayscale1200,
              color: AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text('฿${ad.currentSpend} / ฿${ad.dailyBudget} (งบประมาณ)', style: AppTypography.body3.copyWith(color: AppColors.semanticGrayNeutralFgLowOnWhite)),
          ],
        ),
      ),
    );
  }
}

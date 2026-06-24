import 'package:flutter/material.dart';
import 'package:frontend/core/theme/app_colors.dart';

class HowToOrderPage extends StatelessWidget {
  const HowToOrderPage({super.key});

  static const _steps = <_Step>[
    _Step(
      icon: Icons.grid_view_rounded,
      title: 'Категорияны тандаңыз',
      text: 'Башкы беттен керектүү категорияны тандаңыз — '
          'Тамак-аш, Азык-түлүк, Дарыкана жана башка.',
    ),
    _Step(
      icon: Icons.storefront_outlined,
      title: 'Ишкананы тандаңыз',
      text: 'Тизмеден ишкананы (дүкөн, ресторан) тандап басыңыз. '
          'Ишкананын ачык же жабык экени көрсөтүлөт.',
    ),
    _Step(
      icon: Icons.add_shopping_cart_outlined,
      title: 'Товарларды себетке кошуңуз',
      text: 'Менюдан керектүү товарларды тандап, "+" баскычы менен '
          'себетке кошуңуз. Саны менен суммасы автоматтык эсептелет.',
    ),
    _Step(
      icon: Icons.location_on_outlined,
      title: 'Жеткирүү дарегин белгилеңиз',
      text: '"Улантуу" басып, заказ жеткирилүүчү даректи картадан '
          'белгилеңиз же дарегиңизди жазыңыз.',
    ),
    _Step(
      icon: Icons.check_circle_outline,
      title: 'Заказды ырастаңыз',
      text: 'Керек болсо эскертүү жазыңыз (мис. подъезд, кабат) '
          'жана заказды ырастаңыз.',
    ),
    _Step(
      icon: Icons.receipt_long_outlined,
      title: 'Төлөмдү жүктөңүз',
      text: 'Ишкананын реквизитине төлөп, төлөмдүн скриншотун жүктөңүз. '
          'Ишкана төлөмдү текшерип, заказды кабыл алат.',
    ),
    _Step(
      icon: Icons.delivery_dining_outlined,
      title: 'Курьер жеткирет',
      text: 'Курьер заказды алып, дарегиңизге жеткирет. Заказдын '
          'статусун "Заказдар" бөлүмүнөн көзөмөлдөй аласыз.',
    ),
    _Step(
      icon: Icons.chat_bubble_outline,
      title: 'Курьер менен байланыш',
      text: 'Заказ ичиндеги чат аркылуу курьер менен түз сүйлөшсөңүз болот.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Кантип заказ берем?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Intro
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.accent3, AppColors.accent5],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Text('🚀', style: TextStyle(fontSize: 34)),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Заказ берүү оңой! Төмөнкү кадамдарды ирети менен '
                    'аткарыңыз.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < _steps.length; i++)
            _buildStep(i + 1, _steps[i], isLast: i == _steps.length - 1),
        ],
      ),
    );
  }

  Widget _buildStep(int number, _Step step, {required bool isLast}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number + connecting line
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          // Card
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 9,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(step.icon, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String text;
  const _Step({required this.icon, required this.title, required this.text});
}

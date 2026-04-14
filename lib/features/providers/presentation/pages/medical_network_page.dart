import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'providers_list_page.dart';

/// Home screen displaying medical network categories
class MedicalNetworkPage extends StatelessWidget {
  const MedicalNetworkPage({super.key});

  static const List<Map<String, String>> _categories = [
    {'title': 'المستشفيات', 'image': 'hospital.jpg', 'item': 'مستشفى'},
    {'title': 'مراكز الأشعة', 'image': 'scan.jpg', 'item': 'مراكز الأشعة'},
    {'title': 'معامل التحاليل', 'image': 'medicaltests.jpg', 'item': 'معامل التحاليل'},
    {'title': 'مراكز متخصصة', 'image': 'clinic.jpg', 'item': 'مراكز متخصصة'},
    {'title': 'العيادات', 'image': 'clinic.jpg', 'item': 'عيادة'},
    {'title': 'الصيدليات', 'image': 'pharmacy.jpg', 'item': 'صيدلية'},
    {'title': 'العلاج الطبيعي', 'image': 'physical.jpg', 'item': 'علاج طبيعي'},
    {'title': 'البصريات', 'image': 'optometry.jpg', 'item': 'بصريات'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Padding(
        padding: EdgeInsets.only(bottom: 50.h),
        child: GridView.builder(
          padding: EdgeInsets.all(12.w),
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200.w,
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 0.85,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            return _AnimatedGridItem(
              index: index,
              child: _CategoryCard(category: category),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final Map<String, String> category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProvidersListPage(
                type: category['item']!,
              ),
            ),
          );
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            FadeInImage(
              placeholder: const AssetImage('assets/images/logo.jpg'),
              image: AssetImage('assets/images/${category['image']}'),
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.4, 0.6, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 12.h,
              right: 12.w,
              left: 12.w,
              child: Text(
                category['title']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black54,
                      offset: Offset(1.0, 1.0),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedGridItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedGridItem({
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedGridItem> createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<_AnimatedGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    final delay = Duration(milliseconds: widget.index * 80);
    Timer(delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

import 'package:euro_medical_card/core/localization/app_localizations.dart';
import 'package:euro_medical_card/di/injection_container.dart';
import 'package:euro_medical_card/features/auth/presentation/cubit/auth/auth_cubit.dart';
import 'package:euro_medical_card/features/auth/presentation/cubit/auth/auth_state.dart';
import 'package:euro_medical_card/features/home/presentation/widgets/home_widgets.dart';
import 'package:euro_medical_card/features/providers/presentation/cubit/top_providers/top_providers_cubit.dart';
import 'package:euro_medical_card/features/providers/presentation/pages/providers_list_page.dart';
import 'package:euro_medical_card/features/providers/presentation/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class HomePage extends StatefulWidget {
  final Function(int) onTabChange;

  const HomePage({super.key, required this.onTabChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final AuthCubit _authCubit;
  late final TopProvidersCubit _topProvidersCubit;

  static const List<Map<String, String>> _categories = [
    {'title': 'hospital', 'image': 'hospital.jpg', 'item': 'مستشفى'},
    {'title': 'radiology', 'image': 'scan.jpg', 'item': 'مراكز الأشعة'},
    {
      'title': 'laboratory',
      'image': 'medicaltests.jpg',
      'item': 'معامل التحاليل'
    },
    {
      'title': 'specialized_centers',
      'image': 'clinic.jpg',
      'item': 'مراكز متخصصة'
    },
    {'title': 'clinic', 'image': 'clinic.jpg', 'item': 'عيادة'},
    {'title': 'pharmacy', 'image': 'pharmacy.jpg', 'item': 'صيدلية'},
    {'title': 'physiotherapy', 'image': 'physical.jpg', 'item': 'علاج طبيعي'},
    {'title': 'optometry', 'image': 'optometry.jpg', 'item': 'بصريات'},
  ];

  @override
  void initState() {
    super.initState();
    _authCubit = sl<AuthCubit>();
    _topProvidersCubit = sl<TopProvidersCubit>();
    _topProvidersCubit.loadTopProviders();
  }

  @override
  void dispose() {
    _authCubit.close();
    _topProvidersCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _authCubit,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        body: BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            String userName = context.tr('guest');
            int? templateId;
            if (authState is AuthAuthenticated) {
              userName = authState.member.memberName;
              templateId = authState.member.templateId;
            }

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: HomeHeader(userName: userName, templateId: templateId),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 16.h),
                ),
                SliverToBoxAdapter(
                  child: QuickActionCard(
                    title: context.tr('home_find_on_map'),
                    subtitle: context.tr('home_map_subtitle'),
                    icon: Icons.map_outlined,
                    color: Colors.blue,
                    onTap: () => widget.onTabChange(1), // Index 1 is Map
                  ),
                ),
                SliverToBoxAdapter(
                  child: SectionTitle(
                    title: context.tr('home_medical_network'),
                    onSeeAll: () =>
                        widget.onTabChange(2), // Index 2 is Medical Network
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 120.h,
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        return CategoryItem(
                          category: {
                            ...category,
                            'title': context.tr(category['title']!),
                          },
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProvidersListPage(
                                  type: _categories[index]['item']!,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SectionTitle(
                    title: context.tr('home_partners'),
                    onSeeAll: () =>
                        widget.onTabChange(3), // Index 3 is Partners
                  ),
                ),
                SliverToBoxAdapter(
                  child: BlocProvider.value(
                    value: _topProvidersCubit,
                    child: BlocBuilder<TopProvidersCubit, TopProvidersState>(
                      builder: (context, state) {
                        if (state is TopProvidersLoading) {
                          return const Center(child: LoadingStateWidget());
                        }
                        if (state is TopProvidersLoaded) {
                          return SizedBox(
                            height: 190.h,
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(horizontal: 20.w),
                              scrollDirection: Axis.horizontal,
                              itemCount: state.providers.length,
                              itemBuilder: (context, index) {
                                final provider = state.providers[index];
                                return TopProviderCardHome(
                                  provider: provider,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProvidersListPage(
                                          searchName: provider.nameArabic,
                                          type: provider.typeArabic,
                                          searchOnly: true,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: 100.h),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

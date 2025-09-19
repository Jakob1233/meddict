import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutterquiz/core/core.dart';
import 'package:flutterquiz/features/quiz/cubits/quiz_category_cubit.dart';
import 'package:flutterquiz/features/quiz/cubits/subcategory_cubit.dart';
import 'package:flutterquiz/features/quiz/models/category.dart';
import 'package:flutterquiz/features/quiz/models/quiz_type.dart';
import 'package:flutterquiz/features/system_config/cubits/system_config_cubit.dart';
import 'package:flutterquiz/ui/widgets/already_logged_in_dialog.dart';
import 'package:flutterquiz/ui/widgets/app_dropdown.dart';
import 'package:flutterquiz/ui/widgets/custom_appbar.dart';
import 'package:flutterquiz/ui/widgets/custom_rounded_button.dart';
import 'package:flutterquiz/utils/extensions.dart';
import 'package:flutterquiz/utils/ui_utils.dart';

class SelfChallengeScreen extends StatefulWidget {
  const SelfChallengeScreen({super.key});

  @override
  State<SelfChallengeScreen> createState() => _SelfChallengeScreenState();

  static Route<dynamic> route(RouteSettings routeSettings) {
    return CupertinoPageRoute(builder: (_) => const SelfChallengeScreen());
  }
}

class _SelfChallengeScreenState extends State<SelfChallengeScreen> {
  static const String _defaultSelectedCategoryValue = selectCategoryKey;
  static const String _defaultSelectedSubcategoryValue = selectSubCategoryKey;

  //to display category and suncategory
  String? selectedCategory = _defaultSelectedCategoryValue;
  String? selectedSubcategory = _defaultSelectedSubcategoryValue;

  //id to pass for selfChallengeQuestionsScreen
  String? selectedCategoryId = '';
  String? selectedSubcategoryId = '';

  //minutes for self challenge
  int? selectedMinutes;

  //nunber of questions
  int? selectedNumberOfQuestions;

  late final String _quizType = UiUtils.getCategoryTypeNumberFromQuizType(
    QuizTypes.selfChallenge,
  );
  late final String _subType = UiUtils.subTypeFromQuizType(
    QuizTypes.selfChallenge,
  );

  @override
  void initState() {
    super.initState();

    Future.delayed(Duration.zero, _getCategories);
  }

  void _getCategories() {
    context.read<QuizCategoryCubit>().getQuizCategoryWithUserId(
      languageId: UiUtils.getCurrentQuizLanguageId(context),
      type: _quizType,
      subType: _subType,
    );
  }

  void startSelfChallenge() {
    //
    if (context.read<SubCategoryCubit>().state is SubCategoryFetchFailure) {
      //If there is not any sub category then fetch the all quesitons from given category
      if ((context.read<SubCategoryCubit>().state as SubCategoryFetchFailure)
              .errorMessage ==
          errorCodeDataNotFound) {
        //

        if (selectedCategory != _defaultSelectedCategoryValue &&
            selectedMinutes != null &&
            selectedNumberOfQuestions != null) {
          //to see what keys to pass in arguments see static function route of SelfChallengeQuesitonsScreen

          Navigator.of(context).pushNamed(
            Routes.selfChallengeQuestions,
            arguments: {
              'numberOfQuestions': selectedNumberOfQuestions.toString(),
              'categoryId': selectedCategoryId, //
              'minutes': selectedMinutes,
              'subcategoryId': '',
            },
          );
          return;
        } else {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          UiUtils.showSnackBar(
            context.tr(
              convertErrorCodeToLanguageKey(errorCodeSelectAllValues),
            )!,
            context,
          );
          return;
        }
      }
    }

    if (selectedCategory != _defaultSelectedCategoryValue &&
        selectedSubcategory != _defaultSelectedSubcategoryValue &&
        selectedMinutes != null &&
        selectedNumberOfQuestions != null) {
      //to see what keys to pass in arguments see static function route of SelfChallengeQuesitonsScreen

      Navigator.of(context).pushNamed(
        Routes.selfChallengeQuestions,
        arguments: {
          'numberOfQuestions': selectedNumberOfQuestions.toString(),
          'categoryId': '', //categoryId
          'minutes': selectedMinutes,
          'subcategoryId': selectedSubcategoryId,
        },
      );
    } else {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      UiUtils.showSnackBar(
        context.tr(convertErrorCodeToLanguageKey(errorCodeSelectAllValues))!,
        context,
      );
    }
  }

  //using for category and subcategory
  Widget _buildDropdown({
    required bool forCategory,
    required List<Map<String, String?>> values,
    required String keyValue,
  }) {
    final optionNames = values
        .map((entry) => entry['name'])
        .whereType<String>()
        .toList(growable: false);

    if (optionNames.isEmpty) {
      return const SizedBox.shrink();
    }

    String displayLabel(String name) {
      if (name == selectCategoryKey || name == selectSubCategoryKey) {
        return context.tr(name) ?? name;
      }
      return name;
    }

    return AppDropdown<String>(
      key: ValueKey<String>(keyValue),
      hintText: forCategory
          ? context.tr('selectCategory') ?? 'Kategorie wählen'
          : context.tr('selectSubCategory') ?? 'Unterkategorie wählen',
      items: optionNames,
      itemLabel: displayLabel,
      value: forCategory ? selectedCategory : selectedSubcategory,
      onChanged: (value) {
        final selectedValue =
            value ??
            (forCategory
                ? _defaultSelectedCategoryValue
                : _defaultSelectedSubcategoryValue);

        ScaffoldMessenger.of(context).removeCurrentSnackBar();

        if (!forCategory) {
          if (selectedValue != _defaultSelectedSubcategoryValue) {
            final index = values.indexWhere(
              (element) => element['name'] == selectedValue,
            );
            if (index != -1) {
              setState(() {
                selectedSubcategory = selectedValue;
                selectedSubcategoryId = values[index]['id'];
              });
            }
          }
          return;
        }

        if (selectedValue != _defaultSelectedCategoryValue) {
          final index = values.indexWhere(
            (element) => element['name'] == selectedValue,
          );
          if (index != -1) {
            setState(() {
              selectedCategory = selectedValue;
              selectedCategoryId = values[index]['id'];
              selectedSubcategory = _defaultSelectedSubcategoryValue;
            });

            if (selectedCategoryId != null && selectedCategoryId!.isNotEmpty) {
              context.read<SubCategoryCubit>().fetchSubCategory(
                selectedCategoryId!,
              );
            }
          }
        } else {
          _getCategories();
        }
      },
      searchable: optionNames.length > 6,
      borderRadius: 16,
    );
  }

  //dropdown container with border
  Widget _buildDropdownContainer(Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      alignment: Alignment.center,
      width: context.width,
      child: child,
    );
  }

  //for selecting time and question
  Widget _buildSelectTimeAndQuestionContainer({
    required Color borderColor,
    bool? forSelectQuestion,
    int? value,
    Color? textColor,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (forSelectQuestion!) {
            selectedNumberOfQuestions = value;
          } else {
            selectedMinutes = value;
          }
        });
      },
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 10),
        height: 30,
        width: 45,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          '$value',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildTitleContainer(String title) {
    return Text(
      title,
      textAlign: TextAlign.start,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onTertiary,
      ),
    );
  }

  Widget _buildSubCategoryDropdownContainer(SubCategoryState state) {
    if (state is SubCategoryFetchSuccess) {
      return _buildDropdown(
        forCategory: false,
        values: state.subcategoryList
            .map((e) => {'name': e.subcategoryName, 'id': e.id})
            .toList(),
        keyValue: 'selectSubcategorySuccess${state.categoryId}',
      );
    }

    return Opacity(
      opacity: 0.75,
      child: _buildDropdown(
        forCategory: false,
        values: [
          {'name': _defaultSelectedSubcategoryValue},
        ],
        keyValue: 'selectSubcategory',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = context;

    final config = context.read<SystemConfigCubit>();
    final maxMinutes = config.selfChallengeMaxMinutes < 3
        ? 1
        : config.selfChallengeMaxMinutes ~/ 3;
    final maxQuestions = config.selfChallengeMaxQuestions < 5
        ? 1
        : config.selfChallengeMaxQuestions ~/ 5;

    return PopScope(
      onPopInvokedWithResult: (_, _) =>
          ScaffoldMessenger.of(context).removeCurrentSnackBar(),
      child: Scaffold(
        appBar: QAppBar(title: Text(context.tr('selfChallenge')!)),
        body: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical: size.height * UiUtils.vtMarginPct,
              horizontal: size.width * UiUtils.hzMarginPct,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                //Category Dropdown
                BlocConsumer<QuizCategoryCubit, QuizCategoryState>(
                  bloc: context.read<QuizCategoryCubit>(),
                  listener: (context, state) {
                    if (state is QuizCategorySuccess) {
                      setState(() {
                        selectedCategory = state.categories.first.categoryName;
                        selectedCategoryId = state.categories.first.id;
                      });
                      context.read<SubCategoryCubit>().fetchSubCategory(
                        state.categories.first.id!,
                      );
                    }
                    if (state is QuizCategoryFailure) {
                      if (state.errorMessage == errorCodeUnauthorizedAccess) {
                        showAlreadyLoggedInDialog(context);
                        return;
                      }

                      UiUtils.showSnackBar(
                        context.tr(
                          convertErrorCodeToLanguageKey(state.errorMessage),
                        )!,
                        context,
                        showAction: true,
                        duration: const Duration(days: 365),
                        onPressedAction: _getCategories,
                      );
                    }
                  },
                  builder: (context, state) {
                    var categories = <Category>[];
                    if (state is QuizCategorySuccess) {
                      categories = state.categories
                        ..removeWhere((c) => c.isPremium && !c.hasUnlocked);
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('selectCategory')!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiary,
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildDropdownContainer(
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: state is QuizCategorySuccess
                                ? _buildDropdown(
                                    forCategory: true,
                                    values: categories
                                        .map(
                                          (e) => {
                                            'name': e.categoryName,
                                            'id': e.id,
                                          },
                                        )
                                        .toList(),
                                    keyValue: 'selectCategorySuccess',
                                  )
                                : Opacity(
                                    opacity: 0.75,
                                    child: _buildDropdown(
                                      forCategory: true,
                                      values: [
                                        {
                                          'name': _defaultSelectedCategoryValue,
                                          'id': '0',
                                        },
                                      ],
                                      keyValue: 'selectCategory',
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 25),

                //Sub Category Dropdown
                BlocConsumer<SubCategoryCubit, SubCategoryState>(
                  bloc: context.read<SubCategoryCubit>(),
                  listener: (context, state) {
                    if (state is SubCategoryFetchSuccess) {
                      setState(() {
                        selectedSubcategory =
                            state.subcategoryList.first.subcategoryName;
                        selectedSubcategoryId = state.subcategoryList.first.id;
                      });
                    } else if (state is SubCategoryFetchFailure) {
                      if (state.errorMessage == errorCodeUnauthorizedAccess) {
                        //
                        showAlreadyLoggedInDialog(context);
                        return;
                      }

                      // if no subcategory is available.
                      if (state.errorMessage == errorCodeDataNotFound) {
                        return;
                      }

                      UiUtils.showSnackBar(
                        context.tr(
                          convertErrorCodeToLanguageKey(state.errorMessage),
                        )!,
                        context,
                        duration: const Duration(days: 365),
                        onPressedAction: () {
                          //load subcategory again
                          context.read<SubCategoryCubit>().fetchSubCategory(
                            selectedCategoryId!,
                          );
                        },
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is SubCategoryFetchFailure) {
                      //if there is no subcategory then show empty sized box
                      if (state.errorMessage == errorCodeDataNotFound) {
                        return const SizedBox();
                      }
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('selectSubCategory')!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onTertiary,
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildDropdownContainer(
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            child: _buildSubCategoryDropdownContainer(state),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 25),

                /// Select no. of Questions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleContainer(context.tr('selectNoQusLbl')!),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            List.generate(
                                  maxQuestions,
                                  (index) =>
                                      config.selfChallengeMaxQuestions < 5
                                      ? config.selfChallengeMaxQuestions
                                      : (index + 1) * 5,
                                )
                                .map(
                                  (e) => _buildSelectTimeAndQuestionContainer(
                                    forSelectQuestion: true,
                                    value: e,
                                    borderColor: selectedNumberOfQuestions == e
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade400,
                                    backgroundColor:
                                        selectedNumberOfQuestions == e
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).colorScheme.surface,
                                    textColor: selectedNumberOfQuestions == e
                                        ? Theme.of(context).colorScheme.surface
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onTertiary,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                /// Select challenge duration in minutes
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTitleContainer(context.tr('selectTimeLbl')!),
                    const SizedBox(height: 15),
                    SizedBox(
                      height: 50,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children:
                            List.generate(
                                  maxMinutes,
                                  (index) => config.selfChallengeMaxMinutes < 3
                                      ? config.selfChallengeMaxMinutes
                                      : (index + 1) * 3,
                                )
                                .map(
                                  (e) => _buildSelectTimeAndQuestionContainer(
                                    forSelectQuestion: false,
                                    value: e,
                                    backgroundColor: selectedMinutes == e
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(context).colorScheme.surface,
                                    textColor: selectedMinutes == e
                                        ? Theme.of(context).colorScheme.surface
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onTertiary,
                                    borderColor: selectedMinutes == e
                                        ? Theme.of(context).primaryColor
                                        : Colors.grey.shade400,
                                  ),
                                )
                                .toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                /// Start Challenge
                CustomRoundedButton(
                  elevation: 5,
                  widthPercentage: 1,
                  backgroundColor: Theme.of(context).primaryColor,
                  buttonTitle: context.tr('startLbl')!.toUpperCase(),
                  fontWeight: FontWeight.bold,
                  radius: 8,
                  onTap: startSelfChallenge,
                  showBorder: false,
                  titleColor: Theme.of(context).colorScheme.surface,
                  shadowColor: Theme.of(
                    context,
                  ).primaryColor.withValues(alpha: 0.5),
                  height: 50,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
